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

const max_selected_pairs = 5104; // = 20000 - 14896; // giống config của yttm trong ./run.sh
const max_total_symbols = 900_000; // Unicode: 144,697 characters

const PairCount = shc.HashCount(.{ .capacity = max_total_symbols, .for_bpe = true });

const Entry = shc.Entry;
const HashType = shc.HashType;
const IndexType = shc.IndexType;
const GUARD_BYTE = shc.GUARD_BYTE;
const PairType = shc.PairType;
const maxx_index = shc.maxx_index;
const SYM_BOUND = shc.SYM_BOUND;

pub const BPE = struct {
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

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.entries);
        self.allocator.free(self.vocabs);
        self.pairs_count.deinit();
        self.allocator.free(self.selected_symbols);
    }

    pub fn init(self: *Self, allocator: std.mem.Allocator, len: usize, entries: []const Entry, keys_bytes: []const u8, keys_bytes_len: usize) !void {
        self.allocator = allocator;
        self.len = len;
        self.keys_bytes = keys_bytes;

        self.total_selected = 0;
        self.selected_symbols = try self.allocator.alloc(PairType, max_total_symbols);

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
                const sym_key = unicode + SYM_BOUND;
                var pair_entry = self.pairs_count.putCountReturnEntry(sym_key, entry.count);

                if (pair_entry.count == entry.count) { // char lần đầu xuất hiện
                    self.selected_symbols[self.total_selected] = sym_key;
                    pair_entry.offset = self.total_selected;
                    self.total_selected += 1;
                }

                self.vocabs[x] = pair_entry.offset; // ghi symbol lại
                x += 1;

                const is_new_pair = prev_sym != no_prev_sym;
                prev_sym = pair_entry.offset;

                if (is_new_pair) {
                    const pair_key = (@intCast(PairType, prev_sym) << 24) + pair_entry.offset;
                    pair_entry = self.pairs_count.putCountReturnEntry(pair_key, entry.count);
                    if (pair_entry.count == entry.count) { // pair lần đầu xuất hiện
                        self.selected_symbols[self.total_selected] = pair_key;
                        pair_entry.offset = self.total_selected;
                        self.total_selected += 1;
                    }
                } else k += char_len;

                chars_count.* += 1;
            }
            // tính cả GUARD_BYTE vào vocabs keys để chuẩn bị cho BPE
            // self.vocabs[x] = GUARD_BYTE;
        }
        self.vocabs_len = x;
    }

    pub fn showSelected(self: Self, n: IndexType) void {
        std.debug.print("\n\n(( BPE selected symbols ))\n\n", .{});
        var out: [4]u8 = undefined;
        const symbols = self.selected_symbols[0..];
        var min = self.total_selected;
        if (min > n) min = n;
        for (self.selected_symbols[0..min]) |key| {
            const key_str = out[0..Entry.pairStr(key, out[0..], symbols)];
            std.debug.print("'{s}':{d} \t", .{ key_str, self.pairs_count.get(key) });
        }

        std.debug.print("\n\nTOTAL: {d} symbols\n", .{self.pairs_count.len});
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
        var out: [64]u8 = undefined;
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
            const sep = if (i % 2 == 0) "\t\t\t" else "\n";
            std.debug.print("{s}", .{sep});
        }
    }

    pub fn listEntries(self: Self, max: usize) void {
        std.debug.print("\n\n(( List {d} type counts sorted by len ))\n\n", .{max});
        var ss: HashType = undefined; // ss = small string
        const ss_ptr = &ss;
        const n = if (max < self.len) max else self.len;
        for (self.entries[0..n]) |entry, i| {
            std.debug.print("`{s}`:{d: <6}", .{ self.keyStr(entry, ss_ptr), entry.count });
            const sep = if (i % 2 == 0) "\t\t\t" else "\n";
            std.debug.print("{s}", .{sep});
        }
    }

    fn count_desc(context: *Self, a: Entry, b: Entry) bool {
        const al = if (a.offset <= 8) a.offset else context.keys_bytes[a.offset - 1];
        const bl = if (b.offset <= 8) b.offset else context.keys_bytes[b.offset - 1];
        return al > bl;
    }
};
