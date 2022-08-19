// (Almost-)Concurrent String Hash Count
//
// `key` là chuỗi ngắn độ dài trung bình 32-bytes
// `hash` u64
// `count` là u32
//
// HashCount chỉ cần 2 thao tác là `insert` và `count`
// HashCount cho phép nhiều threads truy cập
//
// Với `count` thực hiện cùng lúc bởi threads mà ko dùng lock có khả năng count update bị trùng lặp
// => chấp nhận được! vì với dữ liệu lớn sai số ko thành vấn đề.
//
// Với `insert` cần phải xử lý race condition ở thao tác grow hashtable. Giải pháp:
// 1/ Init hashtable size đủ lớn để ko bao giờ phải grow bởi bất cứ threads nào
// 2/ Dùng lock khi cần grow
//
// - - -
//
// Có 2 cách cài đặt hash map tốt là `libs/youtokentome/third_party/flat_hash_map.h` và
// `cswisstable`; có thể tìm hiểu cả 2 để có lựa chọn tốt nhất cho HashCount.
//
// => * Làm cách 1/ trước để thử nghiệm tốc độ!
//    * Dùng lại code của `telexyz/engine`
//
// 32-bytes + u32 + u64 = 44-bytes
// unique tokens gọi là types. Giả sử có 1 triệu (2^20) types => 1M * 36-bytes = 44 Mb

const std = @import("std");

pub const HashType = u64;
pub const CountType = u32;
pub const IndexType = u32;

pub const GUARD_BYTE = 32; // vì token ko có space nên gán = 32 để in ra dễ đọc

pub const MAX_CAPACITY: usize = std.math.maxInt(u24); // = IndexType - 5-bits (2^5 = 32)
pub const MAX_KEY_LEN: usize = 63; // + 1 guard-byte = 64
pub const AVG_KEY_LEN: usize = 12;

const maxx_hash = std.math.maxInt(HashType);
const maxx_index = std.math.maxInt(IndexType);

pub const Entry = packed struct {
    hash: HashType = maxx_hash,
    count: CountType = 0,
    offset: IndexType = 0,
};

pub fn HashCount(capacity: usize) type {
    const bits = std.math.log2_int(u64, capacity);
    const shift = 63 - bits;
    const size = @as(usize, 2) << bits;

    std.debug.assert(size < MAX_CAPACITY);
    std.debug.assert(size > capacity);

    return struct {
        // Stats
        max_probs: usize,
        total_probs: usize,
        total_puts: usize,

        allocator: std.mem.Allocator,
        mutex: std.Thread.Mutex,

        entries: []Entry,
        len: usize,

        keys_bytes: []u8,
        keys_bytes_len: usize,

        const Self = @This();

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.entries);
            self.allocator.free(self.keys_bytes);
        }

        pub fn init(self: *Self, init_allocator: std.mem.Allocator) !void {
            self.max_probs = 0;
            self.total_probs = 0;
            self.total_puts = 0;

            self.len = 0;
            self.keys_bytes_len = 0;

            self.mutex = std.Thread.Mutex{};
            self.allocator = init_allocator;

            self.keys_bytes = try self.allocator.alloc(u8, capacity * AVG_KEY_LEN);
            self.entries = try self.allocator.alloc(Entry, size);

            std.mem.set(u8, self.keys_bytes, GUARD_BYTE);
            std.mem.set(Entry, self.entries, .{ .hash = maxx_hash, .count = 0, .offset = maxx_index });
        }

        pub fn keyStr(self: *Self, offset: IndexType) []const u8 {
            const ending: usize = offset + self.keys_bytes[offset - 1];
            return self.keys_bytes[offset..ending];
        }

        inline fn recordStats(self: *Self, _probs: usize) void {
            const probs = _probs + 1;
            self.total_probs += probs;
            self.total_puts += 1;
            if (probs > self.max_probs) self.max_probs = probs;
        }

        inline fn _hash(key: []const u8) u64 {
            return std.hash.Wyhash.hash(key[0], key);
        }

        pub inline fn put(self: *Self, key: []const u8) void {
            _ = self.putCount(key, 1);
        }

        pub fn putCount(self: *Self, key: []const u8, count: CountType) usize {
            if (key.len > MAX_KEY_LEN) return maxx_index; // reject

            var it: Entry = .{ .hash = _hash(key), .count = count };
            var i: usize = it.hash >> shift;
            const _i = i;

            while (self.entries[i].hash < it.hash) : (i += 1) {
                if (i == size) {
                    std.debug.print("`str_hash_count.zig`: hashtable bị đầy.", .{});
                    unreachable;
                }
            }

            self.recordStats(i - _i);

            var entry = &self.entries[i];
            if (entry.hash == it.hash) { // key đã xuất hiện
                entry.count += count; // xáo trộn duy nhất là tăng count lên 1
                return i;
            }

            { // Chỉ dùng lock khi có xáo trộn dữ liệu lớn
                self.mutex.lock();
                defer self.mutex.unlock();

                { // key lần đầu xuất hiện, ghi lại offset
                    var ending = self.keys_bytes_len;
                    self.keys_bytes[ending] = @intCast(u8, key.len);
                    ending += 1;
                    it.offset = @intCast(IndexType, ending);
                    for (key) |k| {
                        self.keys_bytes[ending] = k;
                        ending += 1;
                    }
                    self.keys_bytes[ending] = GUARD_BYTE;
                    self.keys_bytes_len = ending + 1;
                    self.len += 1; // thêm 1 phần tử nữa
                }

                while (true) : (i += 1) {
                    if (i == size) {
                        std.debug.print("`str_hash_count.zig`: hashtable bị đầy.", .{});
                        unreachable;
                    }
                    // Tráo giá trị it và entries[i] để đảm bảo tính tăng dần của hash
                    const tmp = self.entries[i];
                    self.entries[i] = it;
                    if (tmp.offset == maxx_index) { // ô rỗng, dừng thuật toán
                        return i;
                    }
                    it = tmp;
                } // while
            } // Mutex
        }

        pub fn get(self: *Self, key: []const u8) CountType {
            const entry = self.get_entry(key);
            if (entry == null) return 0 else return entry.?.count;
        }

        pub fn get_entry(self: *Self, key: []const u8) ?*Entry {
            if (key.len > MAX_KEY_LEN) return null;

            const hash = _hash(key);

            var i = hash >> shift;
            // Vì hash value luôn tăng nên khi entry.hash > hash nghĩa là key chưa dc đếm
            while (true) : (i += 1) {
                var entry = self.entries[i];
                if (entry.hash < hash) continue;

                const offset = entry.offset;
                const ending = offset + key.len;

                const equal = (entry.hash == hash) and // check hash first
                    self.keys_bytes[ending] == GUARD_BYTE and // len eql
                    std.mem.eql(u8, self.keys_bytes[offset..ending], key);

                return if (equal) &entry else null;
            }
        }

        pub fn validate(self: *Self) bool {
            var prev: HashType = 0;
            for (self.entries[0..]) |entry| {
                const curr = entry.hash;
                if (curr < maxx_hash) {
                    if (prev >= curr) {
                        std.debug.print("\n!! hash ko tăng dần !!\n", .{});
                        return false;
                    }
                    prev = curr;

                    if (curr != _hash(self.keyStr(entry.offset))) {
                        std.debug.print("\n!! hash ko trùng với key !!\n", .{});

                        return false;
                    }
                }
            }
            return true;
        }

        pub fn showStats(self: *Self) void {
            std.debug.print("\n\n(( HASH COUNT STATS ))\n", .{});

            const avg_probs = self.total_probs / self.total_puts;
            std.debug.print(
                "\nTOTAL {d} entries, max_probs: {d}, avg_probs: {d} ({d} / {d}).\n",
                .{ self.len, self.max_probs, avg_probs, self.total_probs, self.total_puts },
            );

            std.debug.print("\nHash Count Validation: {}\n\n", .{self.validate()});
        }
    };
}

pub const CountDesc = struct {
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

    // const pext_u32 = @import("instructions.zig").pext_u32;
    pub fn init(self: *Self, allocator: std.mem.Allocator, len: usize, entries: []const Entry, keys_bytes: []const u8, keys_bytes_len: usize) !void {
        self.allocator = allocator;
        self.len = len;
        self.keys_bytes = keys_bytes;

        self.entries = try self.allocator.alloc(Entry, self.len);
        std.mem.set(Entry, self.entries, .{ .hash = maxx_hash, .count = 0, .offset = maxx_index });

        var i: IndexType = 0;
        for (self.entries) |*new_entry| {
            while (entries[i].count == 0) : (i += 1) {} // bỏ qua
            new_entry.* = entries[i];
            i += 1;
        }
        std.sort.sort(Entry, self.entries, {}, count_desc);

        self.vocabs = try self.allocator.alloc(u8, keys_bytes_len + len * 2);
        // cần thêm 2-bytes lưu reduced count
        // \count-byte1\count-byte2\len\'key' = key.len + 3
        // const low_bitmap: u32 = 0b00000000_00000000_00101010_01010111;
        // const high_bitmap: u32 = 0b0101010_10101010_10000000_00000000;
        var x: usize = 0;
        for (self.entries) |entry| {
            // Reduce count from u32 to u16
            // self.vocabs[x] = @intCast(u8, pext_u32(entry.count, high_bitmap));
            // self.vocabs[x + 1] = @intCast(u8, pext_u32(entry.count, low_bitmap));
            const reduced = @intCast(u16, entry.count / 255 + 1);
            self.vocabs[x] = @intCast(u8, reduced >> 8);
            self.vocabs[x + 1] = @intCast(u8, reduced & 0x00ff);
            x += 2;

            const l = keys_bytes[entry.offset - 1];
            const end = entry.offset + l;
            self.vocabs[x] = l + 1; // key's len
            x += 1;

            // copy key bytes
            for (keys_bytes[entry.offset..end]) |byte| {
                self.vocabs[x] = byte;
                x += 1;
            }
            // tính cả GUARD_BYTE vào vocabs keys để chuẩn bị cho BPE
            self.vocabs[x] = GUARD_BYTE;
            x += 1;
        }
        self.vocabs_len = x;
    }

    pub fn vocabs_slice(self: *Self) []const u8 {
        return self.vocabs[0..self.vocabs_len];
    }

    pub fn list(self: Self, max: usize) void {
        std.debug.print("\n\n(( List {d} type counts ))\n\n", .{max});
        var i: usize = 0;
        const n = if (max < self.len) max else self.len;
        var x: usize = 0;
        while (i < n) : (i += 1) {
            // count trích xuất từ 2-bytes đầu tiên
            const count = self.vocabs[x] * @as(u32, 256) + self.vocabs[x + 1];
            x += 2;

            // byte tiếp theo chứa key's len
            const len = self.vocabs[x];
            x += 1;

            // các bytes tiếp theo là của key
            const end = x + len;
            const key = self.vocabs[x..end];
            x = end;

            std.debug.print("`{s}` {d: <6}", .{ key, count });
            const sep = if (i % 2 == 0)
                TABS[0 .. (MAX_KEY_LEN - key.len) / 9]
            else
                "\n";
            std.debug.print("{s}", .{sep});
        }
    }
    const TABS = "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t";

    pub fn keyStr(self: Self, idx: usize) []const u8 {
        const offset = self.entries[idx].offset;
        var ending: usize = offset + self.keys_bytes[offset - 1];
        return self.keys_bytes[offset..ending];
    }

    fn count_desc(context: void, a: Entry, b: Entry) bool {
        _ = context;
        return a.count > b.count;
    }
};

test "HashCount" {
    const HC1024 = HashCount(1024);
    var counters: HC1024 = undefined;
    try counters.init(std.testing.allocator);
    defer counters.deinit();
    counters.put("a");
    try std.testing.expectEqual(@as(CountType, 1), counters.get("a"));
    try std.testing.expectEqual(@as(CountType, 1), counters.get("a"));
    try std.testing.expectEqual(@as(CountType, 0), counters.get("b"));
    counters.put("a");
    try std.testing.expectEqual(@as(CountType, 2), counters.get("a"));
    counters.put("b");
    try std.testing.expectEqual(@as(CountType, 1), counters.get("b"));
}
