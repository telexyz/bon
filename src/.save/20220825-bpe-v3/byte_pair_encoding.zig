const std = @import("std");
const builtin = @import("builtin");
const shc = @import("str_hash_count.zig");
const phc = @import("pair_hash_count.zig");

const max_selected_pairs = if (builtin.mode == .Debug) 500 else 5104;
const max_total_symbols = 800_000;
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
    candidates: []PairType,
    total_candidates: usize,

    selected_symbols: []PairType,
    total_selected: SymbolType,

    allocator: std.mem.Allocator,
    total_types: usize,
    type_entries: []shc.Entry,
    keys_bytes: []const u8,

    vocabs: []SymbolType,
    vocabs_len: usize,
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
    inline fn addToCandidates(self: *Self, pair_key: PairType) void {
        self.candidates[self.total_candidates] = pair_key;
        self.total_candidates += 1;
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
        if (entry.count == count) self.addToCandidates(pair_added);
    }
    inline fn getCountFromFirstCharIdx(self: Self, idx: usize) CountType {
        return (@intCast(CountType, self.vocabs[idx - 3]) << 16) + self.vocabs[idx - 2];
    }
    inline fn getLenFromFirstCharIdx(self: Self, idx: usize) usize {
        return self.vocabs[idx - 1] & 0x00ff;
    }
    inline fn getEndFromFirstCharIdx(self: Self, idx: usize) usize {
        return idx + self.getLenFromFirstCharIdx(idx);
    }
    inline fn getBoundFromFirstCharIdx(self: Self, idx: usize) usize {
        return idx + (self.vocabs[idx - 1] >> 8);
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
            const index = self.selectMaxCountPairFromCandidates();
            const valid = (index != maxx_index);

            if (valid) {
                // Kết nạp pair được chọn
                const pair_key = self.candidates[index];
                const entry = self.pairs_count.getEntry(pair_key).?;
                self.selectSymbol(entry);

                // Loại bỏ candiate được chọn
                self.removeCandidateAt(index);

                // loại bỏ pair được chọn khỏi vocabs
                self.removeLastSelectedFromVocabs();
            } else break;
        }
    }
    fn selectMaxCountPairFromCandidates(self: *Self) usize {
        var max: CountType = 0;
        var index: usize = maxx_index;
        var i: usize = 0;

        while (i < self.total_candidates) {
            const pair_key = self.candidates[i];
            const entry = self.pairs_count.getEntry(pair_key);
            if (entry == null) {
                // Lỗi này xuất hiện thường là do hàm equal của pair_hash_count chưa chuẩn
                std.debug.print("\nLỗi pairs_count ko tìm thấy key {d}:", .{pair_key});
                printPair(pair_key, self.getSelectedSymbols());
                unreachable;
            }
            if (entry.?.count > max) {
                max = entry.?.count;
                index = i;
            }
            i += 1;
        }
        return index;
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
        const left = getLeftSymbol(last_selected);
        const right = getRightSymbol(last_selected);
        std.debug.assert(left < maxx_index);
        std.debug.assert(right < maxx_index);

        var x: usize = 0;
        while (x < self.vocabs_len) {
            const first_char_idx = x + 3; // bỏ qua 2 phần tử lưu key count và 1 phần tử lưu key len
            var last_char_idx = self.getEndFromFirstCharIdx(first_char_idx) - 1;
            const key_bound = self.getBoundFromFirstCharIdx(first_char_idx);

            if (first_char_idx == last_char_idx) { // key chỉ có 1 symbol
                x = key_bound;
                continue;
            }
            const count = self.getCountFromFirstCharIdx(first_char_idx);
            const key_len_ptr = &self.vocabs[first_char_idx - 1];

            x = first_char_idx;
            while (x < last_char_idx) : (x += 1) {
                var y = x + 1;
                if (left == self.vocabs[x] and right == self.vocabs[y]) { // tìm thấy pair
                    if (x > first_char_idx) { // có sym phía
                        const prev_to_left = self.vocabs[x - 1];
                        const prev_pair_reduc = makePairKey(prev_to_left, self.vocabs[x]);
                        const prev_paid_added = makePairKey(prev_to_left, last_symbol_idx);
                        self.adjustNearByLastSelected(prev_pair_reduc, prev_paid_added, count);
                    }

                    self.vocabs[x] = last_symbol_idx;

                    if (y < last_char_idx) { // còn sym phía sau
                        const next_to_right = self.vocabs[y + 1];
                        const next_pair_reduc = makePairKey(self.vocabs[y], next_to_right);
                        const next_paid_added = makePairKey(last_symbol_idx, next_to_right);
                        self.adjustNearByLastSelected(next_pair_reduc, next_paid_added, count);
                    }

                    while (y < last_char_idx) { // dồn toa
                        self.vocabs[y] = self.vocabs[y + 1];
                        y += 1;
                    }
                    last_char_idx -= 1;
                    key_len_ptr.* -= 1;
                } // found pair
            }
            x = key_bound; // trỏ tới key tiếp theo
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

    pub fn init(self: *Self, allocator: std.mem.Allocator, totals_entries: usize, entries: []const shc.Entry, keys_bytes: []const u8, keys_bytes_len: usize) !void {
        self.allocator = allocator;
        self.total_types = totals_entries;
        self.keys_bytes = keys_bytes;

        self.total_selected = total_chars; // 256 phần tử đầu dùng để định danh char
        self.selected_symbols = try self.allocator.alloc(PairType, max_selected_symbols);

        self.total_candidates = 0;
        self.candidates = try self.allocator.alloc(PairType, max_candidates);

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
                    if (pair_entry.count == key_count) self.addToCandidates(pair_key);
                }
            } // End: Xử lý từng char trong key_str
            const len = key_len_ptr.*;
            key_len_ptr.* = (len << 8) + len;
        }
        self.vocabs_len = x;
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

    fn printVocabGetBound(self: Self, x: usize, offset: usize) usize {
        const symbols = self.getSelectedSymbols();
        var out: [MAX_KEY_LEN]u8 = undefined;
        const begin = x + 3; // trỏ tới nội dung
        const end = self.getEndFromFirstCharIdx(begin);
        const count = self.getCountFromFirstCharIdx(begin);
        var out_len: usize = 0;
        for (self.vocabs[begin + offset .. end]) |idx| {
            out_len += pairDecode(idx, out[out_len..], symbols);
        }
        std.debug.print("{d}`{s}`:{d: <6}", .{ end - begin, out[0..out_len], count });
        return self.getBoundFromFirstCharIdx(begin);
    }
    // List để kiểm tra xem việc tạo dựng mảng vocabs đã chuẩn chưa
    pub fn listVocabs(self: Self, max: usize) void {
        std.debug.print("\n\n(( List {d} type counts sorted by len ))\n\n", .{max});

        const n = if (max < self.total_types) max else self.total_types;
        var x: usize = 0;
        var i: usize = 0;
        while (x < self.vocabs_len and i < n) : (i += 1) {
            x = self.printVocabGetBound(x, 0);
            if (i % 2 == 1) std.debug.print("\n", .{}) else std.debug.print(" \t\t\t", .{});
        }
    }
};