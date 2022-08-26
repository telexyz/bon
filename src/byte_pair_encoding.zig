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

// - - - - - - - - - - - - - - - - - -
// Performance Stats (2.3GB input data)
// - - - - - - - - - - - - - - - - - -
//
// 20/08/2022: Cài đặt BPE Learn v1
// - - - - - - - - - - - - - - - -
// 05s để tách tokens
// 20s để phân tích syllable
// 03s để count types ko phải syllables
// 02m00s 1k BPE Learn V1 (naive impl) => 5.1k cần 10m
// => chậm hơn youtokentome (Total 1m36s = 96s) 7.35 lần
//
// 25/08/2022: Cài đặt BPE Learn v3
// - - - - - - - - - - - - - - - -
// 413s để lọc 5.1k BPE (Total 7m13s - 20s)
// => chậm hơn youtokentome 4.3 lần
//
// 26/08/2022: Perf Tuning
// - - - - - - - - - - - -
// 274s cho SIMDify BPE Learn v3 (4m54s - 20s)
// => Nhanh hơn bản scalar 1.5x
// `274s` cho `5.1k` lượt quét vocabs => 5.4s cho 100 lượt quét
//
// [ Timming ]
// (( BPE Learn: total_select_time 158s total_merge_time 116s ))
//
// [ Enhancements ]
//
// E1/ Khoảng vài trăm lượt quét nên dồn vocabs một lần để loại bỏ blanks elemens
// (( BPE Learn: total_select_time 157s total_merge_time 102s ))
// => Tăng tốc ~14% -> Scan vocabs trên 1 miền bộ nhớ liên tục là rất hiệu quả.
//
// E2/ Select max candidate chiếm 3/5 thời gian chạy => Tìm 1 cách chọn hiệu quả hơn!
//
//  E2a/ Mảng chính `candidates` chỉ giữ `max_selected_pairs` có count lớn nhất.
//  Mảng phụ `new_candidates` chứa các candidates mới xuất hiện trong lần scan vocabs vừa diễn ra
//  Sau mỗi lần scans ta khởi tạo lại `candidates`.
//  (( BPE Learn: total_select_time 3s; total_merge_time 119s ))
//  => Tăng tốc 2.3x (select 52x)
//
//  E2b/ Chọn k phần tử có count lớn nhất từ candidates để remove k pairs trong 1 lần scan vocabs
//  Xem https://en.wikipedia.org/wiki/Selection_algorithm#Partial_selection_sort

const std = @import("std");
const builtin = @import("builtin");
const shc = @import("str_hash_count.zig");
const phc = @import("pair_hash_count.zig");

const max_selected_pairs: usize = if (builtin.mode == .Debug) 500 else 5104;
const max_total_candidates = (6 * max_selected_pairs) / 5;
const max_total_symbols = 1_500_000;
const total_chars = 256; // coi chars là byte nên có 256 chars
const max_selected_symbols = total_chars + max_selected_pairs;
const max_candidates = max_total_symbols - total_chars;

const PairCount = phc.HashCount(max_total_symbols);

const Entry = phc.Entry;
const HashType = phc.HashType;
const IndexType = phc.IndexType;
const CountType = phc.CountType;
const GUARD_BYTE = phc.GUARD_BYTE;
const PairType = phc.KeyType;
const SymbolType = phc.SymbolType;
const maxx_index = phc.maxx_index;
const maxx_symbol = phc.maxx_symbol;
const MAX_KEY_LEN = shc.MAX_KEY_LEN;
const inSet = @import("char_stream.zig").inSet;

// Bộ từ vụng cho keys của char và pair; và hàm pairDecode() để lấy utf8 string tương ứng với pair key
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
inline fn makeCharKey(byte: u8) PairType { // Cách làm đơn giản nhất là coi chars là byte
    return @intCast(PairType, byte);
}
inline fn isChar(pair: PairType) bool {
    return pair < total_chars; // vì chars là byte nên nếu pair là char thì sẽ < 256
}
inline fn makePairKey(prev_sym: SymbolType, curr_sym: SymbolType) PairType {
    // pair key luôn >= maxx_symbol
    const key = (@intCast(PairType, prev_sym) << 16) + curr_sym;
    std.debug.assert(key >= maxx_symbol);
    return key;
}
inline fn isSymbol(pair: PairType) bool {
    return (!isChar(pair)) and pair < maxx_symbol;
}
inline fn getLeftSymbol(pair: PairType) PairType {
    std.debug.assert(pair > maxx_symbol);
    return pair >> 16;
}
inline fn getRightSymbol(pair: PairType) PairType {
    std.debug.assert(pair > maxx_symbol);
    return pair & 0x0000_ffff;
}
fn printPair(pair: PairType, symbols_to_keys: []const PairType) void {
    var out: [MAX_KEY_LEN]u8 = undefined;
    const len = pairDecode(pair, out[0..], symbols_to_keys);
    const key = out[0..len];
    std.debug.print("`{s}`", .{key});
}
pub fn pairDecode(pair: PairType, out: []u8, symbols_to_keys: []const PairType) u6 {
    const key = if (isSymbol(pair)) symbols_to_keys[pair] else pair;
    // std.debug.print("\n> {d} -> {d}", .{ pair, key });

    if (isChar(key)) {
        out[0] = @intCast(u8, key);
        return 1;
    } else {
        const left = getLeftSymbol(key);
        const right = getRightSymbol(key);
        // std.debug.print("\n> l:{d} r:{d}", .{ left, right });
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

    symbols[ab] = counts.putCount(makePairKey('a', 'b'), 1).key;
    symbols[de] = counts.putCount(makePairKey('d', 'e'), 1).key;
    symbols[abc] = counts.putCount(makePairKey(ab, 'c'), 1).key;
    symbols[abcde] = counts.putCount(makePairKey(abc, de), 1).key;
    symbols[abcde_abcde] = counts.putCount(makePairKey(abcde, abcde), 1).key;

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
    candis_count: []CountType,
    candidates: []PairType,
    total_candidates: usize,

    new_candis: []PairType,
    total_new_candis: usize,

    selected_symbols: []PairType,
    total_selected: SymbolType,

    allocator: std.mem.Allocator,
    total_types: usize,
    type_entries: []shc.Entry,
    keys_bytes: []const u8,

    vocabs: []SymbolType,
    vocabs_len: usize,
    merged_vocabs_len: usize,
    pairs_count: PairCount,

    const Self = @This();

    // Bộ từ vựng là các hàm nhỏ, dùng lại nhiều lần, inline để ko làm giảm tốc độ
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // Bộ từ vựng cho selected symbols
    inline fn selectSymbol(self: *Self, sym_entry: *Entry) void {
        std.debug.assert(self.total_selected < maxx_index);
        sym_entry.symbol = self.total_selected; // đánh dấu vị trí được kết nạp
        self.selected_symbols[self.total_selected] = sym_entry.key;
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
        self.total_new_candis = 0;
    }
    inline fn addToNewCandidates(self: *Self, pair_key: PairType) void {
        self.new_candis[self.total_new_candis] = pair_key;
        self.total_new_candis += 1;
    }
    inline fn getCandidates(self: Self) []const PairType {
        return self.candidates[0..self.total_candidates];
    }
    inline fn adjustNearByLastSelected(self: *Self, pair_reduc: PairType, pair_added: PairType, count: CountType) void {
        // Điều chỉnh count của pair_reduc và pair_added
        const reduc_entry = self.pairs_count.getEntry(pair_reduc);
        if (reduc_entry != null) {
            reduc_entry.?.count -= count;
        } else {
            // Lỗi này xuất hiện thường là do hàm equal của pair_hash_count chưa chuẩn
            std.debug.print("\n>> Ko tìm thấy count của nearby symbol {d}:", .{pair_reduc});
            printPair(pair_reduc, self.getSelectedSymbols());
            unreachable;
        }
        const entry = self.pairs_count.putCount(pair_added, count);
        // nếu mới xuất hiện thì cho vào tập candidates
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
    fn printVocabGetBound(self: Self, vocabs: []SymbolType, x: usize, offset: usize) usize {
        const symbols = self.getSelectedSymbols();
        var out: [MAX_KEY_LEN]u8 = undefined;
        const begin = x + 3; // trỏ tới nội dung
        const end = getEndFromFirstCharIdx(vocabs, begin);
        const count = getCountFromFirstCharIdx(vocabs, begin);
        var out_len: usize = 0;
        for (vocabs[begin + offset .. end]) |idx| {
            out_len += pairDecode(idx, out[out_len..], symbols);
        }
        std.debug.print("{d}`{s}`:{d}", .{ end - begin, out[0..out_len], count });
        return getBoundFromFirstCharIdx(vocabs, begin);
    }
    // Bộ từ vựng trên giúp việc cài đặt giải thuật rõ ràng, dễ debug
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    // BPE learn gồm 2 bước: selectMaxCountPair() và removeLastSelectedFromVocabs()
    // Lặp lại 2 bước trên `max_selected_pairs` lần để chọn ra các symbols để tách token
    pub fn learn(self: *Self) void {
        var i: usize = 0;
        // Time measure
        var select_time: i64 = 0;
        var merge_time: i64 = 0;
        var total_select_time: i64 = 0;
        var total_merge_time: i64 = 0;
        var _new_candis: usize = 0;
        _ = self.showStatsgetBlankPercent(0, self.total_new_candis, select_time, merge_time);
        // chọn cho đủ max_selected_pairs pairs
        while (i < max_selected_pairs) : (i += 1) {
            // chọn pair có count lớn nhất
            _new_candis += self.total_new_candis;
            const select_start_time = std.time.milliTimestamp();
            const index = self.finalizeCandidatesGetMaxCountIdx();
            select_time += std.time.milliTimestamp() - select_start_time;

            if (index == maxx_index) break; // not a valid index

            // Kết nạp pair được chọn
            const pair_key = self.candidates[index];
            const entry = self.pairs_count.getEntry(pair_key).?;
            self.selectSymbol(entry);

            // Loại bỏ candiate được chọn
            self.removeCandidateAt(index);

            // loại bỏ pair được chọn khỏi vocabs
            const merge_start_time = std.time.milliTimestamp();
            self.mergeLastSelectedPair();
            merge_time += std.time.milliTimestamp() - merge_start_time;

            if (i % 150 == 149) {
                const progress = i * 100 / max_selected_pairs;
                const blank_percent = self.showStatsgetBlankPercent(progress, _new_candis, select_time, merge_time);

                total_select_time += select_time;
                total_merge_time += merge_time;

                select_time = 0; // reset timers, and counters
                merge_time = 0;
                _new_candis = 0;

                if (blank_percent >= 3) { // 3% change then merge vocabs
                    self.shinkVocabs() catch unreachable;
                }
            }
        }

        _ = self.showStatsgetBlankPercent(100, 0, select_time, merge_time);

        std.debug.print("\n\n(( BPE Learn: total_select_time {d}s; total_merge_time {d}s ))", .{ @divTrunc(total_select_time, 1000), @divTrunc(total_merge_time, 1000) });
    }
    fn showStatsgetBlankPercent(self: Self, progress: usize, _new_candis: usize, select_time: i64, merge_time: i64) usize {
        const blank = self.vocabs_len - self.merged_vocabs_len;
        const blank_percent = blank * 100 / self.vocabs_len;
        std.debug.print(
            "\n* BPE Learn ({d: >3}%)  blanks {d: >8} ({d: >2}%) total_candis {d: >5}  new_candi {d: >5};" ++
                "   select {d}s   merge {d}s",
            .{ progress, blank, blank_percent, self.total_candidates, _new_candis, @divTrunc(select_time, 1000), @divTrunc(merge_time, 1000) },
        );
        return blank_percent;
    }

    fn finalizeCandidatesGetMaxCountIdx(self: *Self) usize {
        // Update giá trị mảng candis_count để tiện cho việc lựa chọn sau này
        var min_count: CountType = std.math.maxInt(CountType);
        var min_idx: usize = undefined;
        for (self.getCandidates()) |pair_key, idx| {
            const count = self.pairs_count.get(pair_key);
            self.candis_count[idx] = count;
            if (count < min_count) {
                min_count = count;
                min_idx = idx;
            }
        }

        var x: usize = 0;
        while (x < self.total_new_candis) : (x += 1) {
            const new_pair_key = self.new_candis[x];
            const count = self.pairs_count.get(new_pair_key);
            const not_enough_candidates = (self.total_candidates < max_total_candidates);
            if (not_enough_candidates) { // Nếu chưa chọn đủ số lượng thì thêm vô tư
                self.candidates[self.total_candidates] = new_pair_key;
                self.candis_count[self.total_candidates] = count;
                if (count < min_count) {
                    min_count = count;
                    min_idx = self.total_candidates;
                }
                self.total_candidates += 1;
            } else if (count > min_count) { // hoặc tìm được ứng cử viên tốt hơn
                self.candidates[min_idx] = new_pair_key;
                self.candis_count[min_idx] = count;
                min_count = count;
                var idx: usize = 0;
                while (idx < self.total_candidates) : (idx += 1) {
                    const c = self.candis_count[idx];
                    if (c < min_count) {
                        min_count = c;
                        min_idx = idx;
                    }
                }
            }
        }
        self.resetNewCandidates();
        // Return max_idx
        var max_count: CountType = 0;
        var max_idx: usize = maxx_index;
        var idx: usize = 0;
        while (idx < self.total_candidates) : (idx += 1) {
            const count = self.candis_count[idx];
            if (count > max_count) {
                max_count = count;
                max_idx = idx;
            }
        }
        return max_idx;
    }

    fn selectMaxCountPairIdxFromCandidates(self: Self) !usize {
        if (self.total_candidates > 45_000) {
            // Chia làm 3 chunks chạy trên 3 threads
            const chunk1 = self.total_candidates / 3;
            const chunk2 = 2 * chunk1;

            var idx: usize = undefined;
            var idx1: usize = undefined;
            var idx2: usize = undefined;

            var thread1 = try std.Thread.spawn(.{}, selectMaxByChunk, .{ self, 0, chunk1, &idx1 });
            var thread2 = try std.Thread.spawn(.{}, selectMaxByChunk, .{ self, chunk1, chunk2, &idx2 });
            self.selectMaxByChunk(chunk2, self.total_candidates, &idx);
            thread1.join();

            var max = self.pairs_count.get(self.candidates[idx]);
            const max1 = self.pairs_count.get(self.candidates[idx1]);
            if (max < max1) {
                max = max1;
                idx = idx1;
            }

            thread2.join();
            const max2 = self.pairs_count.get(self.candidates[idx2]);
            if (max < max2) idx = idx2;

            return idx;
        } else {
            var idx: usize = undefined;
            self.selectMaxByChunk(0, self.total_candidates, &idx);
            return idx;
        }
    }

    fn selectMaxByChunk(self: Self, begin: usize, end: usize, idx_ptr: *usize) void {
        var max: CountType = 0;
        var index: usize = maxx_index;
        var i: usize = begin;
        while (i < end) {
            const pair_key = self.candidates[i];
            const entry = self.pairs_count.getEntry(pair_key).?;
            if (entry.count > max) {
                max = entry.count;
                index = i;
            }
            i += 1;
        }
        idx_ptr.* = index;
    }

    // `mergeLastSelectedPair` là phần chạy chậm và phức tạp nhất của BPE
    // Cần thiết kế để dễ chia wordload ra nhiều threads (sử dụng hết CPU)
    // Sau đó mới tính tới việc dùng SIMD để tăng tốc scan (tối ưu)
    //
    // Các bước cài đặt:
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
    //
    // 3/ Remove nhiều pairs cùng 1 lần scan vocabs, `n pairs` giúp tăng tốc `n lần`.
    // Cần xử lý trường hợp nhập nhằng. VD: key = "abcd", và pairs to be removed là "ab", "bc"
    // Trong trường hợp này chỉ remove được "ab"
    //
    // 4/ Chia vocabs thành n phần, mỗi phần scan riêng trong 1 thread.
    // => Cần cài đặt spinlock ở việc tăng giảm count vì lúc này count được +/- số lớn
    // nên cần chính xác tuyệt đối!
    //
    fn mergeLastSelectedPair(self: *Self) void {
        const last_symbol_idx = self.total_selected - 1;
        const last_selected = self.selected_symbols[last_symbol_idx];
        const left = getLeftSymbol(last_selected);
        const right = getRightSymbol(last_selected);
        std.debug.assert(left < maxx_index);
        std.debug.assert(right < maxx_index);

        const left_lookup_32 = @splat(32, left);
        const right_lookup_32 = @splat(32, right);
        const left_lookup_16 = @splat(16, left);
        const right_lookup_16 = @splat(16, right);

        var x: usize = 0;
        while (x < self.vocabs_len) {
            const first_char_idx = x + 3; // bỏ qua 2 phần tử lưu key count và 1 phần tử lưu key len
            const last_char_idx = getEndFromFirstCharIdx(self.vocabs, first_char_idx) - 1;
            const key_bound = getBoundFromFirstCharIdx(self.vocabs, first_char_idx);

            if (first_char_idx == last_char_idx) { // key chỉ có 1 symbol
                x = key_bound;
                continue;
            }

            const count = getCountFromFirstCharIdx(self.vocabs, first_char_idx);
            const key_len = getLenFromFirstCharIdx(self.vocabs, first_char_idx);
            const key_len_ptr = &self.vocabs[first_char_idx - 1];

            // std.debug.print("\nMerge ", .{});
            // printPair(left, self.getSelectedSymbols());
            // std.debug.print("+", .{});
            // printPair(right, self.getSelectedSymbols());
            // std.debug.print(" for ", .{});
            // _ = self.printVocabGetBound(x, 0);

            // 2/ Dùng SIMD để tìm kiếm pair theo mẻ
            if (key_len <= 16) {
                const input: std.meta.Vector(16, u16) = self.vocabs[first_char_idx..][0..16].*;
                const left_match_vec = input == left_lookup_16; // Zig Vector `==` op
                const left_match_bin = @ptrCast(*const u16, &(left_match_vec)).*;
                const right_match_vec = input == right_lookup_16;
                const right_match_bin = @ptrCast(*const u16, &(right_match_vec)).*;
                const match_bin = left_match_bin & (right_match_bin >> 1);
                var match_begin = @ctz(u16, match_bin);

                if (match_begin < 16 and match_begin < key_len) { // match happened inside the key
                    // std.debug.print("\nleft  {b: >32}\nright {b: >32}\n      {b: >32} => {d}, {any}, {any}\n", .{ left_match_bin, right_match_bin, match_bin, match_begin, left_match_vec[match_begin], right_match_vec[match_begin + 1] });

                    self.mergeMatching(match_begin, key_len, match_bin, //
                        first_char_idx, last_char_idx, key_len_ptr, //
                        last_symbol_idx, count, left, right);
                }
            } else {
                const input: std.meta.Vector(32, u16) = self.vocabs[first_char_idx..][0..32].*;
                const left_match_vec = input == left_lookup_32; // Zig Vector `==` op
                const left_match_bin = @ptrCast(*const u32, &(left_match_vec)).*;
                const right_match_vec = input == right_lookup_32;
                const right_match_bin = @ptrCast(*const u32, &(right_match_vec)).*;
                const match_bin = left_match_bin & (right_match_bin >> 1);
                var match_begin = @ctz(u32, match_bin);

                if (match_begin < 32 and match_begin < key_len) { // match happened inside the key
                    self.mergeMatching(match_begin, key_len, match_bin, //
                        first_char_idx, last_char_idx, key_len_ptr, //
                        last_symbol_idx, count, left, right);
                }
            }

            x = key_bound; // trỏ tới key tiếp theo
        }
    }

    fn mergeMatching(
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
    ) void {
        var match_begin = _match_begin;
        var last_char_idx = _last_char_idx;

        while (match_begin < key_len) : (match_begin += 1) {
            while (!inSet(match_bin, match_begin) and match_begin < key_len) : (match_begin += 1) {}
            if (match_begin >= key_len) break;

            const matchs_count = _last_char_idx - last_char_idx;
            const x = match_begin + first_char_idx - matchs_count; // điều chỉnh dồn toa (bên dưới)
            var y = x + 1;

            std.debug.assert(left == self.vocabs[x]);
            std.debug.assert(right == self.vocabs[y]);

            if (x > first_char_idx) { // có sym phía trước
                const prev_pair_reduc = makePairKey(self.vocabs[x - 1], self.vocabs[x]);
                const prev_paid_added = makePairKey(self.vocabs[x - 1], last_symbol_idx);
                self.adjustNearByLastSelected(prev_pair_reduc, prev_paid_added, count);
            }

            if (y < last_char_idx) { // còn sym phía sau
                const next_pair_reduc = makePairKey(self.vocabs[y], self.vocabs[y + 1]);
                const next_paid_added = makePairKey(last_symbol_idx, self.vocabs[y + 1]);
                self.adjustNearByLastSelected(next_pair_reduc, next_paid_added, count);
            }

            while (y < last_char_idx) : (y += 1) self.vocabs[y] = self.vocabs[y + 1]; // dồn toa

            self.vocabs[last_char_idx] = 0; // ô cuối bỏ đi
            self.vocabs[x] = last_symbol_idx; // symbol mới đại diện cho pair được merged

            last_char_idx -= 1;
            key_len_ptr.* -= 1; // Note: key_len_ptr mang cả key_bound nhưng -=1 chỉ ảnh hưởng tới key_len
            match_begin += 1; // để bỏ qua symbol đã được merged

            self.merged_vocabs_len -= 1; // dung tích thực trừ đi 1
            if (key_len_ptr.* == 1) self.merged_vocabs_len -= 4; // key có 1 symbol loại toàn bộ
        } // while match_begin
    }

    fn shinkVocabs(self: *Self) !void {
        var new_vocabs = try self.allocator.alloc(SymbolType, self.merged_vocabs_len);
        var x: usize = 0;
        var y: usize = 0;

        while (x < self.vocabs_len) {
            //
            const begin = x + 3; // bỏ qua 2 phần tử lưu key count và 1 phần tử lưu key len
            const len = getLenFromFirstCharIdx(self.vocabs, begin);
            const key_bound = getBoundFromFirstCharIdx(self.vocabs, begin);

            if (len > 1) { // chỉ ghi nhận những key có nhiều hơn 1 symbols
                // copy count
                new_vocabs[y] = self.vocabs[x];
                new_vocabs[y + 1] = self.vocabs[x + 1];
                new_vocabs[y + 2] = makeKeyBoundKeyLen(@intCast(SymbolType, len));

                y += 3; // trỏ tới đầu key mới và copy phần nội dung của key
                std.mem.copy(SymbolType, new_vocabs[y .. y + len], self.vocabs[begin .. begin + len]);

                // _ = self.printVocabGetBound(self.vocabs, x, 0);
                // std.debug.print(" -> ", .{});
                // _ = self.printVocabGetBound(new_vocabs, y - 3, 0);
                // std.debug.print("\n", .{});

                y += len; // nhảy tới cuối new vocabs
            }
            //
            x = key_bound; // nhảy tới key tiếp theo
        }
        // self.listVocabs(self.vocabs, self.vocabs_len, 10); // @@@ Kiểm tra old vocabs
        // self.listVocabs(new_vocabs, y, 10); // @@@ Kiểm tra new vocabs

        self.allocator.free(self.vocabs);
        self.vocabs = new_vocabs;
        self.vocabs_len = y;
        self.merged_vocabs_len = y;
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
        self.allocator = allocator;
        self.total_types = totals_entries;
        self.keys_bytes = keys_bytes;

        self.total_selected = total_chars; // 256 phần tử đầu dùng để định danh char
        self.selected_symbols = try self.allocator.alloc(PairType, max_selected_symbols);

        self.total_candidates = 0;
        self.candidates = try self.allocator.alloc(PairType, max_total_candidates);
        self.candis_count = try self.allocator.alloc(CountType, max_total_candidates);

        self.total_new_candis = 0;
        self.new_candis = try self.allocator.alloc(PairType, max_candidates);

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
        std.debug.print("\n(( small string count: {d}, ss puts: {d}, ss bytes: {d}, remain: {d} ))\n", .{ ss_count, ss_puts, ss_bytes, keys_bytes_len });

        // Sắp xếp entries vừa lọc
        std.sort.sort(shc.Entry, self.type_entries, self, keyCountDesc);

        // Khởi tạo vocabs
        self.vocabs = try self.allocator.alloc(SymbolType, keys_bytes_len + self.total_types * 2 + ss_count * 10);

        var x: usize = 0;
        var ss: shc.HashType = undefined;
        const ss_ptr = &ss;

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
                    const pair_entry = self.pairs_count.putCount(pair_key, key_count);
                    // Add pair_entry lần đầu tiên gặp vào danh sách ứng viên
                    if (pair_entry.count == key_count) self.addToNewCandidates(pair_key);
                }
            } // End: Xử lý từng char trong key_str
            const len = key_len_ptr.*;
            key_len_ptr.* = makeKeyBoundKeyLen(len); // key_bound|key_len
            // Lúc khởi tạo key_bound = key_lend
        }
        self.vocabs_len = x;
        self.merged_vocabs_len = x;
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
        return self.total_selected - total_chars;
    }
    pub fn showSelectedSymbols(self: Self, n: IndexType) void {
        std.debug.print("\n\n(( BPE selected symbols ))\n\n", .{});

        var out: [MAX_KEY_LEN]u8 = undefined;
        const symbols = self.getSelectedSymbols();
        var min = self.totalSelectedPairs();
        if (min > n) min = n;

        // Note: vị trí 0 bỏ trống để idx của selected_symbol > 0
        const end = total_chars + min;
        for (self.selected_symbols[total_chars..end]) |key| {
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
        std.debug.print("\n\n(( List {d} type counts sorted by len ))\n\n", .{max});

        const n = if (max < self.total_types) max else self.total_types;
        var x: usize = 0;
        var i: usize = 0;
        while (x < vocabs_len and i < n) : (i += 1) {
            x = self.printVocabGetBound(vocabs, x, 0);
            if (i % 2 == 1) std.debug.print("\n", .{}) else std.debug.print(" \t\t\t", .{});
        }
    }
};
