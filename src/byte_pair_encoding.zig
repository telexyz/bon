//! Input: chuỗi vocabs có BYTE_GUARD ở cuối, mảng count[n] chứa count của từng key trong vocabs.
//! Output: selected_symbols theo thuật toán BPE
//! 
//! Định danh symbols bằng u24 (~16.7m):
//! * Chứa chars ở phần cuối u24, 
//! * chứa selected_symbols ở phần còn lại (hashtable < 2^23 entries).
//!
//! Thao tác tốn kém nhất là việc scan vocab để merge pair vừa được chọn. Pair được chọn là pair
//! cặp symbols liền nhau có số lần xuất hiện trong vocab lớn nhất. 
//! => Thể hiện lại vocabs bởi symbol_ids sẽ giúp scan nhanh hơn.
//! 
//! Mỗi key khi được merge sẽ giảm đi 1 symbol, tới khi chỉ còn 1 symbol thì ko cần quan tâm nữa
//! => Loại key 1 symbol ra khởi vocab. Nên sort vocabs theo key's len desc để tráo keys ở cuối vocabs vào vị trí key bị loại dễ thành công hơn
//! Ô đầu tiên của key bị loại được mark 1 bit riêng và có key len để nhảy qua giúp scan nhanh.
//!
//! Để scan pair thì mỗi lần lần cần so sánh 2 cặp u24, tức là 6-bytes hay 3 cặp u16. Dùng SIMD mỗi lần so sánh sẽ được ít nhất x5 lần so với scalar code.
//! 

const std = @import("std");
const shc = @import("str_hash_count.zig");

const max_selected_pairs = 5104; // = 20000 - 14896 // giống config của yttm trong ./run.sh
// const max_selected_pairs = 50;
const max_total_symbols = 900_000;
const max_selected_symbols = 100_000 + max_selected_pairs; // Unicode: 144,697 characters
const max_candidates = max_total_symbols - max_selected_symbols;

const PairCount = shc.HashCount(.{ .capacity = max_total_symbols, .for_bpe = true });

const Entry = shc.Entry;
const HashType = shc.HashType;
const IndexType = shc.IndexType;
const CountType = shc.CountType;
const GUARD_BYTE = shc.GUARD_BYTE;
const PairType = shc.PairType;
const maxx_index = shc.maxx_index;
const SYM_BOUND = shc.SYM_BOUND;
const MAX_KEY_LEN = shc.MAX_KEY_LEN;

// Bộ từ vụng cho keys của char và pair; và hàm pairDecode() để lấy utf8 string tương ứng với pair key
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
inline fn makeCharKey(char_str: []const u8) PairType { // char key luôn < maxx_index
    const unicode = std.unicode.utf8Decode(char_str) catch return 0;
    const char_key = unicode + SYM_BOUND; // SYM_BOUND để tách char ra khỏi pairs được lựa chọn sau này
    std.debug.assert(char_key < maxx_index);
    return char_key;
}
inline fn makePairKey(prev_sym: IndexType, curr_sym: IndexType) PairType { // pair key luôn > maxx_index
    const pair_key = (@intCast(PairType, prev_sym) << 24) + curr_sym;
    std.debug.assert(pair_key > maxx_index);
    return pair_key;
}
inline fn isSymbol(pair: PairType) bool {
    return pair < SYM_BOUND; // => phải luôn đảm bảo self.total_selected < SYM_BOUND
}
inline fn isChar(key: PairType) bool {
    return key < maxx_index and key > SYM_BOUND;
}
inline fn getUnicode(key: PairType) u21 {
    return @intCast(u21, key - SYM_BOUND);
}
inline fn getLeftSymbol(key: PairType) PairType {
    return key >> 24;
}
inline fn getRightSymbol(key: PairType) PairType {
    return key & 0x000000_ffffff;
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
        return std.unicode.utf8Encode(getUnicode(key), out) catch {
            // std.debug.print("\n>> Lỗi utf8Encode at char {d} <<\n", .{charcode}); // DEBUG
            // Hiển thị char ko encode được bằng dấu `?`
            out[0] = '?';
            return 1;
            // unreachable;
        };
    } else {
        const left = getLeftSymbol(key);
        const right = getRightSymbol(key);
        // std.debug.print("\n>> pair {d} {d} <<\n", .{ left, right });// DEBUG
        const left_len = pairDecode(left, out, symbols_to_keys);
        const right_len = pairDecode(right, out[left_len..], symbols_to_keys);
        return left_len + right_len;
    }
}
test "pairDecode" {
    var counts: shc.HashCount(.{ .capacity = 10, .for_bpe = true }) = undefined;
    try counts.init(std.heap.c_allocator);
    defer counts.deinit();
    var symbols: [10]PairType = undefined;

    const a = 0;
    const b = 1;
    const c = 2;
    const d = 3;
    const e = 4;

    const a_key = std.unicode.utf8Decode("ầ") catch unreachable;

    symbols[a] = counts.putCountgetEntry(makeCharKey(a_key), 1).keyPair();
    symbols[b] = counts.putCountgetEntry(makeCharKey('b'), 1).keyPair();
    symbols[c] = counts.putCountgetEntry(makeCharKey('c'), 1).keyPair();
    symbols[d] = counts.putCountgetEntry(makeCharKey('d'), 1).keyPair();
    symbols[e] = counts.putCountgetEntry(makeCharKey('e'), 1).keyPair();

    const ab = 5;
    const de = 6;
    const abc = 7;
    const abcde = 8;

    symbols[ab] = counts.putCountgetEntry(makePairKey(symbols[a], b), 1).keyPair();
    symbols[de] = counts.putCountgetEntry(makePairKey(d, e), 1).keyPair();
    symbols[abc] = counts.putCountgetEntry(makePairKey(ab, c), 1).keyPair();
    symbols[abcde] = counts.putCountgetEntry(makePairKey(abc, de), 1).keyPair();

    var out: [MAX_KEY_LEN]u8 = undefined;
    var len = Entry.pairDecode(symbols[ab], out[0..], symbols[0..]);
    try std.testing.expectEqualStrings(out[0..len], "ầb");

    len = Entry.pairDecode(symbols[de], out[0..], symbols[0..]);
    try std.testing.expectEqualStrings(out[0..len], "de");

    len = Entry.pairDecode(symbols[abc], out[0..], symbols[0..]);
    try std.testing.expectEqualStrings(out[0..len], "ầbc");

    len = Entry.pairDecode(symbols[abcde], out[0..], symbols[0..]);
    try std.testing.expectEqualStrings(out[0..len], "ầbcde");
}
// Dùng bộ từ vựng trên để đảm bảo tính vẹn toàn của mã hoá char, pair, sym
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

pub const BPE = struct {
    candidates: []PairType,
    total_candidates: usize,

    selected_symbols: []PairType,
    char_symbols_end_at: usize,
    total_selected: IndexType,

    allocator: std.mem.Allocator,
    total_types: usize,
    type_entries: []Entry,
    keys_bytes: []const u8,

    vocabs: []IndexType,
    vocabs_len: usize,
    pairs_count: PairCount,

    const Self = @This();

    // Bộ từ vựng là các hàm nhỏ, dùng lại nhiều lần, inline để ko làm giảm tốc độ
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // Bộ từ vựng cho selected symbols
    inline fn selectSymbol(self: *Self, sym_entry: *Entry) void {
        std.debug.assert(self.total_selected < SYM_BOUND); // để đảm bảo symbol key < char key
        sym_entry.offset = self.total_selected; // đánh dấu vị trí được kết nạp
        self.selected_symbols[self.total_selected] = sym_entry.keyPair();
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
    inline fn addToCandidates(self: *Self, pair_key: PairType) void {
        self.candidates[self.total_candidates] = pair_key;
        self.total_candidates += 1;
    }
    inline fn getCandidates(self: Self) []const PairType {
        return self.candidates[0..self.total_candidates];
    }
    inline fn adjustNearByLastSelected(self: *Self, pair_reduc: PairType, pair_added: PairType, count: CountType) void {
        // Điều chỉnh count của pair_reduc và pair_added
        self.pairs_count.getEntry(pair_reduc).?.count -= count;
        const entry = self.pairs_count.putCountgetEntry(pair_added, count);
        if (entry.count == count) self.addToCandidates(pair_added); // nếu mới xuất hiện thì cho vào tập candidates
    }
    // Bộ từ vựng trên giúp việc cài đặt giải thuật rõ ràng, dễ debug
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    // BPE learn gồm 2 bước: selectMaxCountPair() và removeLastSelectedFromVocabs()
    // Lặp lại 2 bước trên `max_selected_pairs` lần để chọn ra các symbols để tách token
    pub fn learn(self: *Self) void {
        var i: usize = 0;
        // chọn cho đủ max_selected_pairs pairs
        while (i < max_selected_pairs) : (i += 1) {
            // chọn pair có count lớn nhất
            const selected_index = self.selectMaxCountPair();
            const valid = (selected_index != self.total_candidates);

            if (valid) {
                // Kết nạp pair được chọn
                const pair_key = self.candidates[selected_index];
                const entry = self.pairs_count.getEntry(pair_key).?;
                self.selectSymbol(entry);

                // Loại bỏ candiate được chọn
                self.removeCandidateAt(selected_index);

                // loại bỏ pair được chọn khỏi vocabs
                self.removeLastSelectedFromVocabs();
            } else break;
        }
    }
    fn selectMaxCountPair(self: *Self) usize {
        var max: CountType = 0;
        var selected_index = self.total_candidates;

        for (self.getCandidates()) |pair_key, index| {
            const entry = self.pairs_count.getEntry(pair_key);

            if (entry == null) {
                // std.debug.print("\n>> Ko tìm thấy count của candidate {d}:`", .{pair_key});
                // printPair(pair_key, self.getSelectedSymbols());
                // std.debug.print("` <<\n", .{});
                // self.removeCandidateAt(index);
                continue;
            }

            const count = entry.?.count;
            if (count > max) {
                max = count;
                selected_index = index;
            }
        }
        return selected_index;
    }

    // Phần chạy chậm và phức tạp nhất của BPE
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
    // 2/ Chia vocabs thành n phần, mỗi phần scan riêng trong 1 threads.
    // => Cần cài đặt spinlock ở việc tăng giảm count vì lúc này count được +/- số lớn
    // nên cần chính xác tuyệt đối!
    //
    // 3/ Dùng SIMD để tăng tốc scan. Cần đổi vocabs sang []u32 để tiện load vào vectors
    // Mỗi chunk load 16 phần tử (512-bit), compare 2 patterns đan nhau (0101.., 1010..)
    // Cần lắp với đít chunk trước vào đầu chunk đang xem xét.
    fn removeLastSelectedFromVocabs(self: *Self) void {
        // Bước 1/
        const last_symbol_idx = self.total_selected - 1;
        const last_selected = self.selected_symbols[last_symbol_idx];

        // std.debug.print("\nRemove pair ", .{});
        // printPair(last_selected, self.getSelectedSymbols());
        // std.debug.print(":{d} ", .{self.pairs_count.get(last_selected)});

        const left = getLeftSymbol(last_selected);
        const right = getRightSymbol(last_selected);

        std.debug.assert(left < maxx_index);
        std.debug.assert(right < maxx_index);

        var x: usize = 0;
        while (x < self.vocabs_len) {
            while (self.vocabs[x] == 0) : (x += 1) {}
            const first_char_idx = x + 2; // bỏ qua 2 phần tử lưu key count và key len
            const count = self.vocabs[first_char_idx - 2];
            const key_len_ptr = &self.vocabs[first_char_idx - 1];
            var last_char_idx = first_char_idx + key_len_ptr.* - 1;

            x = first_char_idx;
            while (x < last_char_idx) : (x += 1) {
                if (left == self.vocabs[x] and right == self.vocabs[x + 1]) { // tìm thấy pair
                    // _ = self.printVocabGetEnd(first_char_idx - 2, x - first_char_idx); // DEBUG

                    if (x > first_char_idx) {
                        const prev_pair_reduc = makePairKey(self.vocabs[x - 1], self.vocabs[x]);
                        const prev_paid_added = makePairKey(self.vocabs[x - 1], last_symbol_idx);
                        self.adjustNearByLastSelected(prev_pair_reduc, prev_paid_added, count);
                    }

                    self.vocabs[x] = last_symbol_idx;
                    var y = x + 1;

                    if (y < last_char_idx) { // còn sym phía sau
                        const next_pair_reduc = makePairKey(self.vocabs[y], self.vocabs[y + 1]);
                        const next_paid_added = makePairKey(last_symbol_idx, self.vocabs[y + 1]);
                        self.adjustNearByLastSelected(next_pair_reduc, next_paid_added, count);
                        while (y < last_char_idx) : (y += 1) { // dồn toa
                            self.vocabs[y] = self.vocabs[y + 1];
                        }
                        self.vocabs[last_char_idx] = 0; // toa cuối rỗng
                        last_char_idx -= 1;
                        key_len_ptr.* -= 1;
                    }
                }
            }
            x = first_char_idx + key_len_ptr.*; // trỏ tới key tiếp theo
            if (x > 100) break; // DEBUG
        }
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

    pub fn init(self: *Self, allocator: std.mem.Allocator, totals_entries: usize, entries: []const Entry, keys_bytes: []const u8, keys_bytes_len: usize) !void {
        self.allocator = allocator;
        self.total_types = totals_entries;
        self.keys_bytes = keys_bytes;

        self.total_selected = 1; // bắt đầu bằng 1 để đảm bảo pair's value > maxx_index
        self.selected_symbols = try self.allocator.alloc(PairType, max_selected_symbols);

        self.total_candidates = 0;
        self.candidates = try self.allocator.alloc(PairType, max_candidates);

        self.type_entries = try self.allocator.alloc(Entry, self.total_types);
        try self.pairs_count.init(self.allocator);

        var i: IndexType = 0;
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

        // Sắp xếp entries vừa lọc theo thứ tự giảm dần của key's len
        std.sort.sort(Entry, self.type_entries, self, keyLenDesc);

        // Khởi tạo vocabs
        self.vocabs = try self.allocator.alloc(IndexType, keys_bytes_len + self.total_types * 20);

        var x: usize = 0;
        var ss: HashType = undefined;
        const ss_ptr = &ss;

        for (self.type_entries) |type_entry| {
            const key_str = self.keyStr(type_entry, ss_ptr);
            const key_count = type_entry.count;

            self.vocabs[x] = @intCast(IndexType, key_count); // phần tử đầu chứa count
            const chars_count: *IndexType = &self.vocabs[x + 1]; // phần tử thứ 2 chứa len

            chars_count.* = 0;
            var k: usize = 0;
            x += 2; // trỏ tới đầu nội dung

            const no_prev_sym = maxx_index;
            var prev_sym: IndexType = no_prev_sym;

            // Xử lý từng char trong key_str
            while (k < key_str.len) {
                // Lấy độ dài utf8 char
                const char_len: usize = switch (key_str[k]) {
                    0b0000_0000...0b0111_1111 => 1,
                    0b1100_0000...0b1101_1111 => 2,
                    0b1110_0000...0b1110_1111 => 3,
                    0b1111_0000...0b1111_0111 => 4,
                    else => 0,
                };
                if (char_len == 0) {
                    // std.debug.print("\n>> Lỗi utf8 at char `{c}` của key '{s}'<<\n", .{ key_str[k], key_str });
                    break; // bỏ qua phần còn lại, xử lý key tiếp theo
                }

                const char_end = k + char_len;
                if (char_end > key_str.len) {
                    std.debug.print("\n>> Lỗi ko đủ ký tự để utf8Decoder `{s}` <<\n", .{key_str[k..char_end]});
                    break; // bỏ qua phần còn lại, xử lý key tiếp theo
                }

                const char_key = makeCharKey(key_str[k..char_end]);
                if (char_key == 0) {
                    std.debug.print("\n>> Lỗi utf8Decode at `{s}` <<\n", .{key_str[k..char_end]});
                    break; // bỏ qua phần còn lại, xử lý key tiếp theo
                }
                const char_entry = self.pairs_count.putCountgetEntry(char_key, key_count);
                if (char_entry.count == key_count) self.selectSymbol(char_entry);
                // Add char_entry lần đầu tiên gặp vào danh sách các symbols được chọn

                // Phần tử vocabs là symbol được chọn được định danh bằng idx trong mảng selected_symbols
                const curr_sym = @intCast(IndexType, char_entry.offset); // idx này được tham chiếm trong offset
                self.vocabs[x] = curr_sym; // ghi current symbol vào vocabs
                x += 1;

                if (prev_sym != no_prev_sym) { // tồn tại previous symbol
                    const pair_key = makePairKey(prev_sym, curr_sym); // tạo cặp với current symbol
                    const pair_entry = self.pairs_count.putCountgetEntry(pair_key, key_count);
                    if (pair_entry.count == key_count) self.addToCandidates(pair_key);
                    // Add pair_entry lần đầu tiên gặp vào danh sách ứng viên
                }

                prev_sym = curr_sym;
                k += char_len; // nhảy tới char tiếp theo
                chars_count.* += 1; // tăng len lên
            }
        }
        self.vocabs_len = x;
        self.char_symbols_end_at = self.total_selected;
    }
    fn keyLenDesc(context: *Self, a: Entry, b: Entry) bool {
        const al = if (a.offset <= 8) a.offset else context.keys_bytes[a.offset - 1];
        const bl = if (b.offset <= 8) b.offset else context.keys_bytes[b.offset - 1];
        return al > bl;
    } // `keyLenDesc()` dùng để sắp xếp vocabs theo key'len giảm dần

    pub inline fn totalSelectedPairs(self: Self) usize {
        return self.total_selected - self.char_symbols_end_at;
    }
    pub fn showSelectedSymbols(self: Self, n: IndexType) void {
        std.debug.print("\n\n(( BPE selected symbols ))\n\n", .{});

        var out: [MAX_KEY_LEN]u8 = undefined;
        const symbols = self.getSelectedSymbols();
        var min = self.totalSelectedPairs();
        if (min > n) min = n;

        // Note: vị trí 0 bỏ trống để idx của selected_symbol > 0
        const end = self.char_symbols_end_at + min;
        for (self.selected_symbols[self.char_symbols_end_at..end]) |key| {
            const key_str = out[0..pairDecode(key, out[0..], symbols)];
            std.debug.print("'{s}':{d} \t", .{ key_str, self.pairs_count.get(key) });
        }

        std.debug.print("\nTOTAL: {d} symbols selected.\n", .{self.totalSelectedPairs()});
    }

    // Copy `keyStr()` từ str_hash_count.zig
    pub fn keyStr(self: Self, entry: Entry, ss_ptr: *HashType) []const u8 {
        const offset = entry.offset;
        if (offset <= 8) { // small string
            ss_ptr.* = entry.hash *% 0x2040003d780970bd;
            return std.mem.asBytes(ss_ptr)[0..offset];
        }
        const ending: usize = offset + self.keys_bytes[offset - 1];
        return self.keys_bytes[offset..ending];
    }

    fn printVocabGetEnd(self: Self, x: usize, offset: usize) usize {
        const symbols = self.getSelectedSymbols();
        var out: [MAX_KEY_LEN]u8 = undefined;
        const count = self.vocabs[x];
        const begin = x + 2; // trỏ tới nội dung
        const end = begin + self.vocabs[x + 1];
        var out_len: usize = 0;
        for (self.vocabs[begin + offset .. end]) |idx| {
            const key = symbols[idx];
            out_len += pairDecode(key, out[out_len..], symbols);
        }
        std.debug.print("`{s}`:{d: <6}", .{ out[0..out_len], count });
        return end;
    }
    // List để kiểm tra xem việc tạo dựng mảng vocabs đã chuẩn chưa
    pub fn listVocabs(self: Self, max: usize) void {
        std.debug.print("\n\n(( List {d} type counts sorted by len ))\n\n", .{max});

        const n = if (max < self.total_types) max else self.total_types;
        var x: usize = 0;
        var i: usize = 0;

        while (x < self.vocabs_len) {
            x = self.printVocabGetEnd(x, 0);
            if (i > n) break;
            i += 1;
            const sep = if (i % 2 == 1) "\t\t\t" else "\n";
            std.debug.print("{s}", .{sep});
        }
    }
};
