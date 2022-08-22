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

const max_total_chars = 100_000;
const max_selected_symbols = 5104; // = 20000 - 14896; // giống config của yttm trong ./run.sh
const max_total_symbols = 800_000;
const SymbolCount = shc.HashCount(max_total_symbols);
const CharCount = shc.HashCount(max_total_chars); // Unicode: 144,697 characters

const Entry = shc.Entry;
const HashType = shc.HashType;
const IndexType = shc.IndexType;
const GUARD_BYTE = shc.GUARD_BYTE;

pub const BPE = struct {
    allocator: std.mem.Allocator,
    len: usize,
    entries: []Entry,
    keys_bytes: []const u8,
    vocabs: []u8,
    vocabs_len: usize,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.entries);
        self.allocator.free(self.vocabs);
    }

    pub fn init(self: *Self, allocator: std.mem.Allocator, len: usize, entries: []const Entry, keys_bytes: []const u8, keys_bytes_len: usize) !void {
        self.allocator = allocator;
        self.len = len;
        self.keys_bytes = keys_bytes;

        self.entries = try self.allocator.alloc(Entry, self.len);

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

        self.vocabs = try self.allocator.alloc(u8, keys_bytes_len + len * 20);
        // cần thêm 3-bytes lưu count

        var x: usize = 0;
        var ss: HashType = undefined;
        const ss_ptr = &ss;
        for (self.entries) |entry| {
            const key_str = self.keyStr(entry, ss_ptr);

            // 3-bytes đầu lưu count
            self.vocabs[x] = @intCast(u8, (entry.count >> 16) & 0x00ff);
            self.vocabs[x + 1] = @intCast(u8, (entry.count >> 8) & 0x00ff);
            self.vocabs[x + 2] = @intCast(u8, entry.count & 0x00ff);
            self.vocabs[x + 3] = @intCast(u8, key_str.len) + 1; // key's len
            x += 4;
            // copy key bytes
            for (key_str) |byte| {
                self.vocabs[x] = byte;
                x += 1;
            }
            // tính cả GUARD_BYTE vào vocabs keys để chuẩn bị cho BPE
            self.vocabs[x] = GUARD_BYTE;
            x += 1;
        }
        self.vocabs_len = x;
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

    pub fn list(self: Self, max: usize) void {
        std.debug.print("\n\n(( List {d} type counts ))\n\n", .{max});
        var ss: HashType = undefined;
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
