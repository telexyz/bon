//! Input: Mảng vocabs: []u16 lưu các key dưới dạng mảng symbols
//!
//! `key` = key_count_u16_0|key_count_u16_1|key_bound_byte-key_len_byte|symbol_u16_0|symbol_u16_1 ...
//! `key_count` là u32 nên cần 2 ô u16 để lưu
//!
//! Vì `key_len` < 256 nên ô chứa  key_len được chia làm đôi, nửa đầu lưu key_bound, nửa sau lưu key_len để
//! Lúc khởi tạo key_bound = key_lend. Lúc rút gọn symbols thì key_len giảm dần, lúc này dùng key_bound
//! để nhảy tới key ngay tiếp theo.
//!
//! Output: selected symbols theo thuật toán BPE Learn:
//!
//! * 1/ Khởi tạo tập symbols là các 255 bytes (coi chars là byte). VD: a, b, c, d, ... 1, 2, 3, 4
//! * 2/ Lặp lại `k` lần:
//!   - 2.1/ Chọn ra cặp symbol liền nhau có count là lớn nhất `ab` chẳng hạn.
//!   - 2.2/ Tạo thêm symbol mới `ab`
//!   - 2.3/ Thay thế toàn bộ sự xuất hiện liền kề của `a` và `b` trong vocabs bằng `ab`
//!
//! BPE-Dropout: ở 2.1/ drop ngẫu nhiên từng pair trong tập candidates với xác suất 0.1% (1000 loại 1)
//! dropout giúp rare-subword ko bị quá lấn át từ đó giúp rare-tokens được hiểu tốt hơn.
//! Chi tiết tại https://github.com/VProv/BPE-Dropout

const std = @import("std");
const builtin = @import("builtin");
const ThreadPool = @import("ThreadPool.zig");
const WaitGroup = @import("WaitGroup.zig");
const shc = @import("str_hash_count.zig");
const phc = @import("pair_hash_count.zig");
const inSet = @import("char_stream.zig").inSet;

const MAX_SELECTED_PAIRS: usize = 8000;
const MAX_TOTAL_CANDIDATES = 5 * MAX_SELECTED_PAIRS / 2;
const TOTAL_CHARS = 256; // coi chars là byte nên có 256 chars
const MAX_TOTAL_SYMBOLS = 1_500_000;
const MAX_SELECTED_SYMBOLS = TOTAL_CHARS + MAX_SELECTED_PAIRS;
const MAX_CANDIDATES = MAX_TOTAL_SYMBOLS / 3;

const PairCount = phc.HashCount(MAX_TOTAL_SYMBOLS);
const Entry = phc.Entry;
const HashType = phc.HashType;
const IndexType = phc.IndexType;
const CountType = phc.CountType;
const PairType = phc.KeyType;
const SymbolType = phc.SymbolType;

const GUARD_BYTE = phc.GUARD_BYTE;
const MAXX_INDEX = phc.MAXX_INDEX;
const MAXX_SYMBOL = phc.MAXX_SYMBOL;
const MAX_KEY_LEN = shc.MAX_KEY_LEN;
const MAX_CHUNKS = phc.MAX_CHUNKS;

// Bộ từ vụng cho keys của char và pair; và hàm pairDecode() để lấy utf8 string tương ứng với pair key
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
inline fn makeCharKey(byte: u8) PairType { // Cách làm đơn giản nhất là coi chars là byte
    return @intCast(PairType, byte);
}
inline fn isChar(pair: PairType) bool {
    return pair < TOTAL_CHARS; // vì chars là byte nên nếu pair là char thì sẽ < 256
}
inline fn makePairKey(prev_sym: SymbolType, curr_sym: SymbolType) PairType {
    // pair key luôn >= MAXX_SYMBOL
    const key = (@intCast(PairType, prev_sym) << 16) + curr_sym;
    std.debug.assert(key >= MAXX_SYMBOL);
    return key;
}
inline fn isSymbol(pair: PairType) bool {
    return (!isChar(pair)) and pair < MAXX_SYMBOL;
}
inline fn getLeftSymbol(pair: PairType) SymbolType {
    std.debug.assert(pair > MAXX_SYMBOL);
    return @intCast(SymbolType, pair >> 16);
}
inline fn getRightSymbol(pair: PairType) SymbolType {
    std.debug.assert(pair > MAXX_SYMBOL);
    return @intCast(SymbolType, pair & 0x0000_ffff);
}
fn printPair(pair: PairType, symbols_to_keys: []const PairType) void {
    var out: [MAX_KEY_LEN]u8 = undefined;
    const len = pairDecode(pair, out[0..], symbols_to_keys);
    const key = out[0..len];
    std.debug.print("`{s}`", .{key});
}
pub fn pairDecode(pair: PairType, out: []u8, symbols_to_keys: []const PairType) u6 {
    const key = if (isSymbol(pair)) symbols_to_keys[pair] else pair;
    if (isChar(key)) {
        out[0] = @intCast(u8, key);
        return 1;
    } else {
        const left = getLeftSymbol(key);
        const right = getRightSymbol(key);
        const left_len = pairDecode(left, out, symbols_to_keys);
        const right_len = pairDecode(right, out[left_len..], symbols_to_keys);
        return left_len + right_len;
    }
}
test "pairDecode" {
    var counts: phc.HashCount(10) = undefined;
    try counts.init(std.heap.c_allocator);
    defer counts.deinit();
    var symbols: [300]PairType = undefined;

    const ab = 261;
    const de = 262;
    const abc = 263;
    const abcde = 264;
    const abcde_abcde = 265;

    symbols[ab] = counts.putCount(makePairKey('a', 'b'), 1, 0).key();
    symbols[de] = counts.putCount(makePairKey('d', 'e'), 1, 0).key();
    symbols[abc] = counts.putCount(makePairKey(ab, 'c'), 1, 0).key();
    symbols[abcde] = counts.putCount(makePairKey(abc, de), 1, 0).key();
    symbols[abcde_abcde] = counts.putCount(makePairKey(abcde, abcde), 1, 0).key();

    var out: [MAX_KEY_LEN]u8 = undefined;
    var len: usize = 0;
    len = pairDecode(ab, out[0..], symbols[0..]);
    try std.testing.expectEqualStrings(out[0..len], "ab");

    len = pairDecode(de, out[0..], symbols[0..]);
    try std.testing.expectEqualStrings(out[0..len], "de");

    len = pairDecode(abc, out[0..], symbols[0..]);
    try std.testing.expectEqualStrings(out[0..len], "abc");

    len = pairDecode(abcde, out[0..], symbols[0..]);
    try std.testing.expectEqualStrings(out[0..len], "abcde");

    len = pairDecode(abcde_abcde, out[0..], symbols[0..]);
    try std.testing.expectEqualStrings(out[0..len], "abcdeabcde");
}
// Dùng bộ từ vựng trên để đảm bảo tính vẹn toàn của mã hoá char, pair, sym
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

pub const BPE = struct {
    const lock_init = if (builtin.single_threaded) {} else false;
    spinlock: @TypeOf(lock_init),

    candidates_count: []CountType,
    candidates: []PairType,
    total_candidates: usize,

    new_candidates: []PairType,
    total_new_candidates: usize,

    selected_symbols: []PairType,
    total_selected: SymbolType,

    allocator: std.mem.Allocator,
    total_types: usize,
    type_entries: []shc.Entry,
    keys_bytes: []const u8,

    vocabs: []SymbolType,
    vocabs_len: usize,
    pairs_count: PairCount,

    chunks: [MAX_CHUNKS + 1]usize,
    shinks: usize = 0,

    random: std.rand.Random,

    const Self = @This();

    // Bộ từ vựng là các hàm nhỏ, dùng lại nhiều lần, inline để ko làm giảm tốc độ
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // Bộ từ vựng cho selected symbols
    inline fn selectSymbol(self: *Self, sym_entry: *Entry) void {
        std.debug.assert(self.total_selected < MAXX_INDEX);
        self.selected_symbols[self.total_selected] = sym_entry.key();
        self.total_selected += 1; // thêm 1 symbol mới được chọn
    }
    inline fn getSelectedSymbols(self: Self) []const PairType {
        return self.selected_symbols[0..self.total_selected];
    }

    // Bộ từ vựng để handle candidates
    inline fn removeCandidateAt(self: *Self, idx: usize) void {
        self.candidates[idx] = self.candidates[self.total_candidates - 1];
        self.total_candidates -= 1;
    }
    inline fn resetNewCandidates(self: *Self) void {
        self.total_new_candidates = 0;
    }
    inline fn addToNewCandidates(self: *Self, pair_key: PairType) void {
        self.new_candidates[self.total_new_candidates] = pair_key;
        self.total_new_candidates += 1;
    }
    inline fn getCandidates(self: Self) []const PairType {
        return self.candidates[0..self.total_candidates];
    }
    inline fn getNewCandidates(self: Self) []const PairType {
        return self.new_candidates[0..self.total_new_candidates];
    }
    fn adjustNearByLastSelected(self: *Self, pair_reduc: PairType, pair_added: PairType, count: CountType, curr_chunk: u8) void {
        // Dùng lock vì có nhiều thread cùng tham gia vào việc này
        while (@atomicRmw(bool, &self.spinlock, .Xchg, true, .SeqCst)) {}
        defer std.debug.assert(@atomicRmw(bool, &self.spinlock, .Xchg, false, .SeqCst));

        // Điều chỉnh count của pair_reduc và pair_added
        self.pairs_count.getEntry(pair_reduc).?.count -= count;

        // Nếu pair_added mới xuất hiện thì cho vào tập candidates
        const entry = self.pairs_count.putCount(pair_added, count, curr_chunk);
        if (entry.count == count) self.addToNewCandidates(pair_added);
    }

    // Vocabs Helpers
    inline fn makeKeyBoundKeyLen(len: SymbolType) SymbolType {
        return (len << 8) + len; // key_bound|key_len
    }
    inline fn getCountFromFirstCharIdx(vocabs: []SymbolType, idx: usize) CountType {
        return (@intCast(CountType, vocabs[idx - 3]) << 16) + vocabs[idx - 2];
    }
    inline fn getLenFromFirstCharIdx(vocabs: []SymbolType, idx: usize) usize {
        return vocabs[idx - 1] & 0x00ff;
    }
    inline fn getEndFromFirstCharIdx(vocabs: []SymbolType, idx: usize) usize {
        return idx + getLenFromFirstCharIdx(vocabs, idx);
    }
    inline fn getBoundFromFirstCharIdx(vocabs: []SymbolType, idx: usize) usize {
        return idx + (vocabs[idx - 1] >> 8);
    }

    fn printVocabGetUnicodeLen(self: Self, vocabs: []SymbolType, x: *usize, offset: usize) usize {
        const symbols = self.getSelectedSymbols();
        var out: [MAX_KEY_LEN]u8 = undefined;
        const begin = x.* + 3; // trỏ tới nội dung
        const end = getEndFromFirstCharIdx(vocabs, begin);
        const count = getCountFromFirstCharIdx(vocabs, begin);
        var out_len: usize = 0;
        for (vocabs[begin + offset .. end]) |idx| {
            out_len += pairDecode(idx, out[out_len..], symbols);
        }
        std.debug.print("`{s}`:{d}", .{ out[0..out_len], count });
        // std.debug.print("{d}`{s}`:{d}", .{ end - begin, out[0..out_len], count });
        x.* = getBoundFromFirstCharIdx(vocabs, begin);
        return getUnicodeLen(out[0..out_len]);
    }
    inline fn getUnicodeLen(str: []const u8) usize {
        var i: usize = 0;
        var l: usize = 0;
        while (i < str.len) {
            switch (str[i]) {
                0b0000_0000...0b0111_1111 => i += 1,
                0b1100_0000...0b1101_1111 => i += 2,
                0b1110_0000...0b1110_1111 => i += 3,
                0b1111_0000...0b1111_0111 => i += 4,
                else => i += 1,
            }
            l += 1;
        }
        return l;
    }
    // Bộ từ vựng trên giúp việc cài đặt giải thuật rõ ràng, dễ debug
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    // BPE learn gồm 2 bước: selectMaxCountPair() và mergeLastSelectedPair()
    // Lặp lại 2 bước trên `MAX_SELECTED_PAIRS`
    pub fn learn(self: *Self) !void {
        var i: usize = 0;
        var _new_candidates: usize = 0;

        var thread_pool: ThreadPool = undefined;
        try thread_pool.init(self.allocator);
        defer thread_pool.deinit();
        var wait_group: WaitGroup = .{};

        // Show progress at beginning
        _ = self.showStatsGetBlanksPercent(0, self.total_new_candidates);

        // chọn cho đủ MAX_SELECTED_PAIRS pairs
        while (i < MAX_SELECTED_PAIRS) : (i += 1) {
            // chọn pair có count lớn nhất
            _new_candidates += self.total_new_candidates;
            const index = self.finalizeCandidatesGetMaxCountIdx();
            if (index == MAXX_INDEX) break; // not a valid index

            // Kết nạp pair được chọn
            const pair_key = self.candidates[index];
            const entry = self.pairs_count.getEntry(pair_key).?;
            self.selectSymbol(entry);

            // Loại bỏ candiate được chọn
            self.removeCandidateAt(index);

            // loại bỏ pair được chọn khỏi vocabs
            const last_symbol_idx = self.total_selected - 1;
            const last_selected = self.selected_symbols[last_symbol_idx];
            const left = getLeftSymbol(last_selected);
            const right = getRightSymbol(last_selected);
            std.debug.assert(left < MAXX_INDEX);
            std.debug.assert(right < MAXX_INDEX);

            const left_lookup_16 = @splat(16, left);
            const right_lookup_16 = @splat(16, right);

            const left_lookup_32 = @splat(32, left);
            const right_lookup_32 = @splat(32, right);

            wait_group.reset();
            var c: u8 = 0;
            while (c < MAX_CHUNKS) : (c += 1) {
                if (entry.in_chunks.isSet(c)) {
                    wait_group.start();
                    try thread_pool.spawn(mergeLastSelectedPair, .{
                        self,
                        &wait_group,
                        &left_lookup_16,
                        &right_lookup_16,
                        &left_lookup_32,
                        &right_lookup_32,
                        last_symbol_idx,
                        c,
                    });
                }
            }
            wait_group.wait();

            if (i % 200 == 199) { // Show progress
                const progress = i * 100 / MAX_SELECTED_PAIRS;
                self.showStatsGetBlanksPercent(progress, _new_candidates);
                _new_candidates = 0;
            }
        }

        // Show progress at the end
        _ = self.showStatsGetBlanksPercent(100, 0);
    }
    fn showStatsGetBlanksPercent(self: Self, progress: usize, _new_candidates: usize) void {
        std.debug.print("\n* BPE Learn ({d: >3}%)  total_candis {d: >5}  new_candis {d: >5}", .{ progress, self.total_candidates, _new_candidates });
    }

    inline fn dropout(self: Self) bool {
        return self.random.int(u16) < 40; // dropout rate ~= 0.06% (40 / 65536)
    }
    fn finalizeCandidatesGetMaxCountIdx(self: *Self) usize {
        var min_count: CountType = std.math.maxInt(CountType);
        var min_idx: usize = undefined;

        var x: usize = 0;
        // Update giá trị mảng candidates_count vì sau 1 lần scan vocabs là count đã thay đổi
        while (x < self.total_candidates) {
            // BPE-Dropout
            if (self.dropout()) {
                self.removeCandidateAt(x);
                continue;
            }
            // Dùng getEntry để chăc chắn `new_pair_key` có trong hashtable
            const count = self.pairs_count.getEntry(self.candidates[x]).?.count;
            if (count == 0) { // count đã bị trừ hết bởi scan vocabs thì loại luôn
                self.total_candidates -= 1;
                self.candidates[x] = self.candidates[self.total_candidates];
                // Tiếp tục xử lý phần tử vừa tráo vào vị trí x
            } else {
                // update candidate count tại vị trí `x`
                self.candidates_count[x] = count;
                // Nhân tiện tìm min_idx để tráo đổi với new_candidate ở bước sau
                if (count < min_count) {
                    min_count = count;
                    min_idx = x;
                }
                x += 1; // next :)
            }
        }

        // Với từng ứng viên mới (phần tử mảng new_candidates)
        for (self.getNewCandidates()) |new_pair_key| {
            // Dùng getEntry để chăc chắn `new_pair_key` có trong hashtable
            const new_count = self.pairs_count.getEntry(new_pair_key).?.count;

            if ((self.total_candidates < MAX_TOTAL_CANDIDATES)) {
                // Nếu chưa chọn đủ số lượng thì thêm vô tư
                const new_idx = self.total_candidates;
                self.total_candidates += 1; // ghi nhận việc cho thêm 1 phần tử vào candidates

                self.candidates[new_idx] = new_pair_key; // thêm 1 phần tử mới
                self.candidates_count[new_idx] = new_count; // và update count tương ứng

                // Update min_idx
                if (new_count < min_count) {
                    min_count = new_count;
                    min_idx = new_idx;
                }
                //
            } else if (new_count > min_count) { // hoặc tìm được ứng cử viên tốt hơn
                // thì thay vào vị trí min_idx
                self.candidates[min_idx] = new_pair_key;
                self.candidates_count[min_idx] = new_count; // update count
                min_count = new_count; // và lấy tạm new_count làm min_count mới

                // sau đó kiểm tra min_count mới với các candidates đã có
                var idx: usize = 0;
                while (idx < self.total_candidates) : (idx += 1) {
                    const count = self.candidates_count[idx];
                    if (count < min_count) {
                        min_count = count;
                        min_idx = idx;
                    }
                }
            } // else
        } // new_candidates

        self.resetNewCandidates(); // loại bỏ các phần tử còn lại

        // Return max_idx
        var max_count: CountType = 0;
        var max_idx: usize = MAXX_INDEX;
        var idx: usize = 0;
        while (idx < self.total_candidates) : (idx += 1) {
            const count = self.candidates_count[idx];
            if (count > max_count) {
                max_count = count;
                max_idx = idx;
            }
        }
        return max_idx;
    }

    // `mergeLastSelectedPair` là phần chạy chậm và phức tạp nhất của BPE Learn
    // Cần thiết kế để dễ chia wordload ra nhiều threads (sử dụng hết CPU)
    // Sau đó mới tính tới việc dùng SIMD để tăng tốc scan (tối ưu). Các bước cài đặt:
    //
    // 1/ scan tuần tự vocabs, gộp pair lại thành symbol phải move dữ liệu còn lại của key
    // lùi lại phía trước một ô trong mảng vocabs. Đồng thời loại bỏ count của pair trước và sau
    // và thêm count của 2 pairs mới.
    // Ví dụ: Nếu loại bỏ pair 'cd' có id 'x' trong key 'abcde' có count là 100
    // Thì new_key = 'abxe' và trừ count của 'bc' và 'de' đi 100
    // và tăng count cặp `bx` và `xe` thêm 100.
    //
    // 2/ Dùng SIMD để tăng tốc scan. Cần đổi vocabs sang []u32 để tiện load vào vectors
    // Mỗi chunk load 16 phần tử (512-bit), compare 2 patterns đan nhau (0101.., 1010..)
    // Cần lắp với đít chunk trước vào đầu chunk đang xem xét.
    fn mergeLastSelectedPair(
        self: *Self,
        wg: *WaitGroup,
        left_lookup_16: *const std.meta.Vector(16, SymbolType),
        right_lookup_16: *const std.meta.Vector(16, SymbolType),
        left_lookup_32: *const std.meta.Vector(32, SymbolType),
        right_lookup_32: *const std.meta.Vector(32, SymbolType),
        last_symbol_idx: SymbolType,
        curr_chunk: u8,
    ) void {
        defer wg.finish();

        const left = left_lookup_16.*[0];
        const right = right_lookup_16.*[0];

        var x = self.chunks[curr_chunk];
        const end = self.chunks[curr_chunk + 1];

        while (x < end) {
            const first_char_idx = x + 3; // bỏ qua 2 phần tử lưu key count và 1 phần tử lưu key len
            const last_char_idx = getEndFromFirstCharIdx(self.vocabs, first_char_idx) - 1;
            const key_bound = getBoundFromFirstCharIdx(self.vocabs, first_char_idx);

            if (first_char_idx == last_char_idx) { // key chỉ có 1 symbol
                x = key_bound;
                continue;
            }

            const count = getCountFromFirstCharIdx(self.vocabs, first_char_idx);
            const key_len_ptr = &self.vocabs[first_char_idx - 1];

            // 2/ Dùng SIMD để tìm kiếm pair theo mẻ
            // Chia key_len thành từng mức 16, 32, 48, 64 để tối ưu cho AVX2 256-bit (16x16)
            // AVX512 (32x16) tự lựa theo.
            var key_len = getLenFromFirstCharIdx(self.vocabs, first_char_idx);
            // std.debug.assert(key_len <= 64);

            switch (key_len) {
                0...16 => {
                    const input: std.meta.Vector(16, SymbolType) = self.vocabs[first_char_idx..][0..16].*;
                    const left_match_vec = input == left_lookup_16.*; // Zig Vector `==` op
                    const left_match_bin = @ptrCast(*const u16, &(left_match_vec)).*;
                    const right_match_vec = input == right_lookup_16.*;
                    const right_match_bin = @ptrCast(*const u16, &(right_match_vec)).*;
                    const match_bin = left_match_bin & (right_match_bin >> 1);
                    const match_begin = @ctz(u16, match_bin);

                    if (match_begin < key_len) { // match happened inside the key
                        const match_end = @clz(u16, match_bin);
                        if (key_len > match_end) key_len = match_end + 1;

                        self.mergeMatching(match_begin, key_len, match_bin, //
                            first_char_idx, last_char_idx, key_len_ptr, //
                            last_symbol_idx, count, left, right, curr_chunk);
                    }
                },
                17...32 => {
                    const input: std.meta.Vector(32, SymbolType) = self.vocabs[first_char_idx..][0..32].*;
                    const left_match_vec = input == left_lookup_32.*; // Zig Vector `==` op
                    const left_match_bin = @ptrCast(*const u32, &(left_match_vec)).*;
                    const right_match_vec = input == right_lookup_32.*;
                    const right_match_bin = @ptrCast(*const u32, &(right_match_vec)).*;
                    const match_bin = left_match_bin & (right_match_bin >> 1);
                    const match_begin = @ctz(u32, match_bin);

                    if (match_begin < 32 and match_begin < key_len) { // match happened inside the key
                        const match_end = @clz(u32, match_bin);
                        if (key_len > match_end) key_len = match_end + 1;

                        self.mergeMatching(match_begin, key_len, match_bin, //
                            first_char_idx, last_char_idx, key_len_ptr, //
                            last_symbol_idx, count, left, right, curr_chunk);
                    }
                },
                else => unreachable,
            }
            x = key_bound; // trỏ tới key tiếp theo
        }
    }

    inline fn mergeMatching(
        self: *Self,
        _match_begin: usize,
        key_len: usize,
        match_bin: anytype,
        first_char_idx: usize,
        _last_char_idx: usize,
        key_len_ptr: *SymbolType,
        last_symbol_idx: SymbolType,
        count: CountType,
        left: PairType,
        right: PairType,
        curr_chunk: u8,
    ) void {
        var match_begin = _match_begin;
        var last_char_idx = _last_char_idx;

        while (match_begin < key_len) : (match_begin += 1) {
            if (!inSet(match_bin, match_begin)) continue;

            const matchs_count = _last_char_idx - last_char_idx;
            const x = match_begin + first_char_idx - matchs_count; // điều chỉnh dồn toa (bên dưới)
            var y = x + 1;

            std.debug.assert(left == self.vocabs[x]);
            std.debug.assert(right == self.vocabs[y]);

            if (x > first_char_idx) { // có sym phía trước
                const prev_pair_reduc = makePairKey(self.vocabs[x - 1], self.vocabs[x]);
                const prev_paid_added = makePairKey(self.vocabs[x - 1], last_symbol_idx);
                self.adjustNearByLastSelected(prev_pair_reduc, prev_paid_added, count, curr_chunk);
            }

            if (y < last_char_idx) { // còn sym phía sau
                const next_pair_reduc = makePairKey(self.vocabs[y], self.vocabs[y + 1]);
                const next_paid_added = makePairKey(last_symbol_idx, self.vocabs[y + 1]);
                self.adjustNearByLastSelected(next_pair_reduc, next_paid_added, count, curr_chunk);
            }

            while (y < last_char_idx) : (y += 1) self.vocabs[y] = self.vocabs[y + 1]; // dồn toa
            self.vocabs[last_char_idx] = 0; // ô cuối bỏ đi
            self.vocabs[x] = last_symbol_idx; // symbol mới đại diện cho pair được merged

            last_char_idx -= 1;
            key_len_ptr.* -= 1; // Note: key_len_ptr mang cả key_bound nhưng -=1 chỉ ảnh hưởng tới key_len
            match_begin += 1; // Bỏ qua symbol đã được merged. VD key = "abcd" và
            // merge pair `ab` thì được `ab`cd với current match_begin = 0
            //                          .01.23  -> next match_begin = 2
            // nên += 1 ở đây trước, và += 1 ở đầu vòng lặp while là thành 2
        } // while match_begin
    }
    // Kết thúc phần liên quan tới BPE learn
    // - - - - - - - - - - - - - - - - - - -

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.type_entries);
        self.allocator.free(self.vocabs);
        self.pairs_count.deinit();
        self.allocator.free(self.selected_symbols);
        self.allocator.free(self.candidates);
    }

    pub fn init(self: *Self, allocator: std.mem.Allocator, totals_entries: usize, entries: []const shc.Entry, keys_bytes: []const u8, keys_bytes_len: usize) !void {
        std.debug.assert(MAX_KEY_LEN <= 64);

        self.shinks = 0;
        self.spinlock = lock_init;
        self.allocator = allocator;
        self.total_types = totals_entries;
        self.keys_bytes = keys_bytes;
        self.random = std.rand.Pcg.init(21091981).random();

        self.total_selected = TOTAL_CHARS; // 256 phần tử đầu dùng để định danh char
        self.selected_symbols = try self.allocator.alloc(PairType, MAX_SELECTED_SYMBOLS);

        self.total_candidates = 0;
        self.candidates = try self.allocator.alloc(PairType, MAX_TOTAL_CANDIDATES);
        self.candidates_count = try self.allocator.alloc(CountType, MAX_TOTAL_CANDIDATES);

        self.total_new_candidates = 0;
        self.new_candidates = try self.allocator.alloc(PairType, MAX_CANDIDATES);

        self.type_entries = try self.allocator.alloc(shc.Entry, self.total_types);
        try self.pairs_count.init(self.allocator);

        var i: usize = 0;
        var ss_puts: usize = 0;
        var ss_count: usize = 0;
        var ss_bytes: usize = 0;

        // Lọc entries có ý count > 0
        for (self.type_entries) |*type_entry| {
            while (entries[i].count == 0) : (i += 1) {} // bỏ qua
            type_entry.* = entries[i];
            if (type_entry.offset <= 8) {
                ss_puts += type_entry.count;
                ss_count += 1;
                ss_bytes += type_entry.offset;
            }
            i += 1;
        }
        std.debug.print("\n\n(( small string count: {d}, ss puts: {d}, ss bytes: {d}, remain: {d} ))\n", .{ ss_count, ss_puts, ss_bytes, keys_bytes_len });

        // Sắp xếp entries vừa lọc
        std.sort.sort(shc.Entry, self.type_entries, self, keyCountDesc);

        // Khởi tạo vocabs
        const n = keys_bytes_len + self.total_types + ss_bytes + ss_count * 2;
        self.vocabs = try self.allocator.alloc(SymbolType, n + 64);

        var x: usize = 0;
        var ss: shc.HashType = undefined;
        const ss_ptr = &ss;

        const delta = (n / MAX_CHUNKS);
        var curr = delta;
        var chunk: u8 = 0;

        for (self.type_entries) |type_entry| {
            const key_str = self.keyStr(type_entry, ss_ptr);
            const key_count = type_entry.count;

            self.vocabs[x] = @intCast(SymbolType, key_count >> 16); // 2 phần tử đầu chứa count
            self.vocabs[x + 1] = @intCast(SymbolType, key_count & 0x0000_ffff);
            const key_len_ptr = &self.vocabs[x + 2]; // phần tử thứ 3 chứa len
            key_len_ptr.* = 0;
            x += 3; // trỏ tới đầu nội dung

            var k: usize = 0;
            // Xử lý từng char trong key_str
            while (k < key_str.len) : (k += 1) {
                const char = key_str[k];
                if (char == 0) {
                    std.debug.print("\n>> Lỗi có byte = 0 tại {d} của `{s}` <<\n", .{ k, key_str });
                    break; // bỏ qua phần còn lại để xử lý key tiếp theo
                }

                self.vocabs[x] = char; // ghi current char vào vocabs
                key_len_ptr.* += 1;
                x += 1;

                if (k > 0) { // có previous char
                    const pair_key = makePairKey(key_str[k - 1], char);
                    const pair_entry = self.pairs_count.putCount(pair_key, key_count, chunk);
                    // Add pair_entry lần đầu tiên gặp vào danh sách ứng viên
                    if (pair_entry.count == key_count) self.addToNewCandidates(pair_key);
                }
            } // End: Xử lý từng char trong key_str
            const len = key_len_ptr.*;
            key_len_ptr.* = makeKeyBoundKeyLen(len); // key_bound|key_len
            // Lúc khởi tạo key_bound = key_lend

            if (chunk < MAX_CHUNKS and x >= curr) {
                self.chunks[chunk + 1] = x;
                curr += delta;
                chunk += 1;
                // std.debug.print("chunks[{d}]={d}\n", .{ chunk, x });
            }
        }

        self.vocabs_len = x;
        self.chunks[0] = 0;
        while (chunk < MAX_CHUNKS) : (chunk += 1) self.chunks[chunk + 1] = x;
    }

    fn keyCountDesc(context: *Self, a: shc.Entry, b: shc.Entry) bool {
        _ = context;
        return a.count > b.count;
    }
    fn keyLenDesc(context: *Self, a: shc.Entry, b: shc.Entry) bool {
        const al = if (a.offset <= 8) a.offset else context.keys_bytes[a.offset - 1];
        const bl = if (b.offset <= 8) b.offset else context.keys_bytes[b.offset - 1];
        return al > bl;
    } // `keyLenDesc()` dùng để sắp xếp vocabs theo key'len giảm dần

    pub inline fn totalSelectedPairs(self: Self) usize {
        return self.total_selected - TOTAL_CHARS;
    }
    pub fn showSelectedSymbols(self: Self, n: IndexType) void {
        std.debug.print("\n\n(( BPE selected symbols ))\n\n", .{});

        var out: [MAX_KEY_LEN]u8 = undefined;
        const symbols = self.getSelectedSymbols();
        var min = self.totalSelectedPairs();
        if (min > n) min = n;

        // Note: vị trí 0 bỏ trống để idx của selected_symbol > 0
        const end = TOTAL_CHARS + min;
        for (self.selected_symbols[TOTAL_CHARS..end]) |key| {
            const key_str = out[0..pairDecode(key, out[0..], symbols)];
            std.debug.print("'{s}':{d} \t", .{ key_str, self.pairs_count.get(key) });
        }

        std.debug.print("\nTOTAL: {d} symbols selected.\n", .{self.totalSelectedPairs()});
    }

    // Copy `keyStr()` từ str_hash_count.zig
    pub fn keyStr(self: Self, entry: shc.Entry, ss_ptr: *shc.HashType) []const u8 {
        const offset = entry.offset;
        if (offset <= 8) { // small string
            ss_ptr.* = entry.hash *% 0x2040003d780970bd;
            return std.mem.asBytes(ss_ptr)[0..offset];
        }
        const ending: usize = offset + self.keys_bytes[offset - 1];
        return self.keys_bytes[offset..ending];
    }

    // List để kiểm tra xem việc tạo dựng mảng vocabs đã chuẩn chưa
    pub fn listVocabs(self: Self, vocabs: []SymbolType, vocabs_len: usize, max: usize) void {
        std.debug.print("\n\n(( List {d} type counts ))\n\n", .{max});

        const n = if (max < self.total_types) max else self.total_types;
        var x: usize = 0;
        var l: usize = 0;
        var i: usize = 0;

        while (x < vocabs_len and i < n) : (i += 1) {
            l = self.printVocabGetUnicodeLen(vocabs, &x, 0);
            if (i % 3 != 2)
                std.debug.print("{s}\t", .{SPACES[5 .. MAX_KEY_LEN - l]})
            else
                std.debug.print("\n", .{});
        }
    }
    const SPACES = " " ** MAX_KEY_LEN;
};

test "TODO" {
    std.debug.print( //
        "\n\n" ++
        "  * Khởi tạo ban đầu new_candidates là utf-8 pairs thay vì byte-pairs?\n" ++
        "  * Viết test cases cho BPE Learn\n" ++
        "  * Viết BPE Apply. Xem https://github.com/glample/fastBPE/blob/master/fastBPE/fastBPE.hpp#L523" ++
        "\n\n", .{});
}
