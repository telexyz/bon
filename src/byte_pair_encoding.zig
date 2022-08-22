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

pub const BPE = struct {
    candidates: []PairType,
    total_candidates: usize,

    selected_symbols: []PairType,
    total_selected: IndexType,

    allocator: std.mem.Allocator,
    len: usize,
    entries: []Entry,
    keys_bytes: []const u8,
    vocabs: []IndexType,
    vocabs_len: usize,
    pairs_count: PairCount,

    const Self = @This();

    pub fn learn(self: *Self) void {
        var i: usize = 0;
        // chọn cho đủ max_selected_pairs pairs
        while (i < max_selected_pairs) : (i += 1) {
            // chọn pair có count lớn nhất
            const selected_index = self.selectMaxCountPair();
            const valid = (selected_index != self.total_candidates);

            if (valid) {
                const pair_key = self.candidates[selected_index];
                const entry = self.pairs_count.getEntry(pair_key).?;

                // Loại bỏ candiate được chọn
                self.candidates[selected_index] = self.candidates[self.total_candidates - 1];
                self.total_candidates -= 1;

                // Kết nạp pair được chọn
                entry.offset = self.total_selected; // đánh dấu vị trí được kết nạp
                self.selected_symbols[self.total_selected] = pair_key;
                self.total_selected += 1; // thêm 1 pair mới được chọn

                // loại bỏ pair được chọn khỏi vocabs
                self.removeFromVocabs(pair_key);
            } else break;
        }
    }
    fn selectMaxCountPair(self: *Self) usize {
        var max: CountType = 0;
        var selected_index = self.total_candidates;
        const candidates = self.candidates[0..self.total_candidates];
        for (candidates) |pair_key, index| {
            const entry = self.pairs_count.getEntry(pair_key).?;
            if (entry.count > max) {
                max = entry.count;
                selected_index = index;
            }
        }
        return selected_index;
    }
    fn removeFromVocabs(self: *Self, pair: PairType) void {
        _ = self;
        _ = pair;
        // Phần chạy chậm và phức tạp nhất của BPE
        // Cần thiết kế để dễ chia wordload ra nhiều threads (sử dụng hết CPU)
        // Sau đó mới tính tới việc dùng SIMD để tăng tốc scan (tối ưu)
        //
        // Các bước cài đặt:
        //
        // 1/ scan tuần tự vocabs, gộp pair lại thành symbol phải move dữ liệu còn lại của key
        // lùi lại phía trước một ô trong mảng vocabs.
        //
        // 2/ Chia vocabs thành n phần, mỗi phần scan riêng trong 1 threads.
        // => Cần cài đặt spinlock ở việc tăng giảm count vì lúc này count được +/- số lớn
        // nên cần chính xác tuyệt đối!
        //
        // 3/ Dùng SIMD để tăng tốc scan. Cần đổi vocabs sang []u32 để tiện load vào vectors
        // Mỗi chunk load 16 phần tử (512-bit), compare 2 patterns đan nhau (0101.., 1010..)
        // Cần lắp với đít chunk trước vào đầu chunk đang xem xét.
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.entries);
        self.allocator.free(self.vocabs);
        self.pairs_count.deinit();
        self.allocator.free(self.selected_symbols);
        self.allocator.free(self.candidates);
    }

    pub fn init(self: *Self, allocator: std.mem.Allocator, len: usize, entries: []const Entry, keys_bytes: []const u8, keys_bytes_len: usize) !void {
        self.allocator = allocator;
        self.len = len;
        self.keys_bytes = keys_bytes;

        self.total_selected = 1; // bắt đầu bằng 1 để đảm bảo pair's value > maxx_index
        self.selected_symbols = try self.allocator.alloc(PairType, max_selected_symbols);

        self.total_candidates = 0;
        self.candidates = try self.allocator.alloc(PairType, max_candidates);

        self.entries = try self.allocator.alloc(Entry, self.len);
        try self.pairs_count.init(self.allocator);

        var i: IndexType = 0;
        var ss_puts: usize = 0;
        var ss_count: usize = 0;
        var ss_bytes: usize = 0;
        for (self.entries) |*new_entry| {
            while (entries[i].count == 0) : (i += 1) {} // bỏ qua
            new_entry.* = entries[i];
            if (new_entry.offset <= 8) {
                ss_puts += new_entry.count;
                ss_count += 1;
                ss_bytes += new_entry.offset;
            }
            i += 1;
        }
        std.debug.print("\n\n\n>> small string count: {d}, ss puts: {d}, ss bytes: {d}, remain: {d} <<\n", .{ ss_count, ss_puts, ss_bytes, keys_bytes_len });
        std.sort.sort(Entry, self.entries, self, count_desc);

        self.vocabs = try self.allocator.alloc(IndexType, keys_bytes_len + len * 20);
        // cần thêm 3-bytes lưu count

        var x: usize = 0;
        var ss: HashType = undefined;
        const ss_ptr = &ss;

        for (self.entries) |entry| {
            const key_str = self.keyStr(entry, ss_ptr);
            self.vocabs[x] = @intCast(IndexType, entry.count); // phần tử đầu chứa count
            const chars_count: *IndexType = &self.vocabs[x + 1]; // phần tử thứ 2 chứa len

            chars_count.* = 0;
            var k: usize = 0;
            x += 2; // trỏ tới đầu nội dung

            const no_prev_sym = maxx_index;
            var prev_sym: IndexType = no_prev_sym;

            while (k < key_str.len) {
                const char_len = std.unicode.utf8ByteSequenceLength(key_str[k]) catch unreachable;
                const unicode = std.unicode.utf8Decode(key_str[k .. k + char_len]) catch unreachable;
                const char_key = unicode + SYM_BOUND;
                const char_entry = self.pairs_count.putCountReturnEntry(char_key, entry.count);

                if (char_entry.count == entry.count) { // char lần đầu xuất hiện
                    self.selected_symbols[self.total_selected] = char_key;
                    char_entry.offset = self.total_selected;
                    self.total_selected += 1;
                }

                const curr_sym = char_entry.offset;
                self.vocabs[x] = curr_sym; // ghi symbol lại
                // std.debug.print("\n>> vocabs[{d}]={} <<\n", .{ x, self.vocabs[x] }); // DEBUG
                x += 1;

                if (prev_sym != no_prev_sym) {
                    const pair_key = (@intCast(PairType, prev_sym) << 24) + curr_sym;
                    const pair_entry = self.pairs_count.putCountReturnEntry(pair_key, entry.count);

                    if (pair_entry.count == entry.count) { // pair lần đầu xuất hiện
                        // Kết nạp pair vào tập ứng viên
                        self.candidates[self.total_candidates] = pair_key;
                        self.total_candidates += 1;
                    }
                }

                prev_sym = curr_sym;
                k += char_len;
                chars_count.* += 1;
            }
            // tính cả GUARD_BYTE vào vocabs keys để chuẩn bị cho BPE
            // self.vocabs[x] = GUARD_BYTE + SYM_BOUND;
            // x += 1;
        }
        self.vocabs_len = x;
    }

    pub fn showSelected(self: Self, n: IndexType) void {
        std.debug.print("\n\n(( BPE selected symbols ))\n\n", .{});
        var out: [MAX_KEY_LEN]u8 = undefined;
        const symbols = self.selected_symbols[0..];
        var min = self.total_selected;
        if (min > n) min = n;
        for (self.selected_symbols[1..min]) |key| {
            // std.debug.print("{d}-", .{key});
            const key_str = out[0..Entry.pairStr(key, out[0..], symbols)];
            std.debug.print("'{s}':{d} \t", .{ key_str, self.pairs_count.get(key) });
        }

        std.debug.print("\nTOTAL: {d} symbols\n", .{self.pairs_count.len});
    }

    pub fn keyStr(self: Self, entry: Entry, ss_ptr: *HashType) []const u8 {
        const offset = entry.offset;
        if (offset <= 8) { // small string
            ss_ptr.* = entry.hash *% 0x2040003d780970bd;
            return std.mem.asBytes(ss_ptr)[0..offset];
        }
        const ending: usize = offset + self.keys_bytes[offset - 1];
        return self.keys_bytes[offset..ending];
    }

    pub fn listVocabs(self: Self, max: usize) void {
        std.debug.print("\n\n(( List {d} type counts sorted by len ))\n\n", .{max});
        var out: [MAX_KEY_LEN]u8 = undefined;
        const symbols = self.selected_symbols[0..];

        const n = if (max < self.len) max else self.len;
        var x: usize = 0;
        var i: usize = 0;

        while (x < self.vocabs_len) {
            const count = self.vocabs[x];
            const len = self.vocabs[x + 1];
            x += 2; // trỏ tới nội dung
            var out_len: usize = 0;
            for (self.vocabs[x .. x + len]) |idx| {
                const key = symbols[idx];
                out_len += Entry.pairStr(key, out[out_len..], symbols);
            }
            x += len;
            std.debug.print("`{s}`:{d: <6}", .{ out[0..out_len], count });
            i += 1;
            if (i > n) break;
            const sep = if (i % 2 == 1) "\t\t\t" else "\n";
            std.debug.print("{s}", .{sep});
        }
    }

    fn count_desc(context: *Self, a: Entry, b: Entry) bool {
        const al = if (a.offset <= 8) a.offset else context.keys_bytes[a.offset - 1];
        const bl = if (b.offset <= 8) b.offset else context.keys_bytes[b.offset - 1];
        return al > bl;
    }
};
