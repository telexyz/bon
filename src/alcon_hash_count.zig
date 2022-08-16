// (Almost-)Concurrent Hash Count
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

// Init HashCount để count các tokens ko phải âm tiết tiếng Việt
pub const NotSyllHashCount = HashCount(2_500_000);

pub const HashType = u64;
pub const CountType = u32;
pub const IndexType = u32;

pub const GUARD_BYTE = 32; // vì token ko có space nên gán = 32 để in ra dễ đọc

pub const MAX_CAPACITY: usize = std.math.maxInt(u24); // = IndexType - 5-bits (2^5 = 32)
pub const MAX_KEY_LEN: usize = 63; // + 1 guard-byte = 64
pub const AVG_KEY_LEN: usize = 12;

const maxx_offset = maxx_index - 2;
const maxx_hash = std.math.maxInt(HashType);
const maxx_index = std.math.maxInt(IndexType);

pub const Entry = packed struct {
    hash: HashType = maxx_hash,
    count: CountType = 0,
    offset: IndexType = maxx_offset,
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
            std.mem.set(Entry, self.entries, .{ .hash = maxx_hash, .count = 0 });
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.entries);
            self.allocator.free(self.keys_bytes);
        }

        pub fn key_str(self: *Self, idx: usize) []const u8 {
            const offset = self.entries[idx].offset;
            var ending: usize = offset + self.keys_bytes[offset - 1];
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
            if (key.len > MAX_KEY_LEN) return;

            var it: Entry = .{ .hash = _hash(key), .count = 1, .offset = maxx_offset };
            var i: usize = it.hash >> shift;
            var never_swap = true;
            const _i = i;

            while (self.entries[i].hash < it.hash) : (i += 1) {}

            if (self.entries[i].hash == it.hash) { // key đã xuất hiện
                self.entries[i].count += 1;
                self.recordStats(i - _i);
                return;
            }

            // Chỉ dùng lock khi cần hoán đổi thành viên mảng entries
            self.mutex.lock();
            defer self.mutex.unlock();

            while (true) : (i += 1) {
                if (never_swap) { // key lần đầu xuất hiện, ghi lại offset
                    never_swap = false;
                    var ending = self.keys_bytes_len;
                    self.keys_bytes[ending] = @intCast(u8, key.len);
                    ending += 1;
                    it.offset = @intCast(IndexType, ending);
                    for (key) |k| {
                        self.keys_bytes[ending] = k;
                        ending += 1;
                    }
                    // self.keys_bytes[ending] = GUARD_BYTE;
                    self.keys_bytes_len = ending + 1;
                    self.len += 1;
                }

                // Tráo giá trị it và entries[i] để đảm bảo tính tăng dần của hash
                const tmp = self.entries[i];
                self.entries[i] = it;

                if (tmp.count == 0) { // ô rỗng, dừng thuật toán
                    self.recordStats(i - _i);
                    return;
                }
                it = tmp;
            } // while
        }

        pub fn get(self: *Self, key: []const u8) CountType {
            if (key.len > MAX_KEY_LEN) return 0;

            const hash = _hash(key);

            var i = hash >> shift;
            // Vì hash value luôn tăng nên khi entry.hash > hash nghĩa là key chưa dc đếm
            while (true) : (i += 1) {
                const entry = self.entries[i];
                if (entry.hash < hash) continue;

                const offset = entry.offset;
                const ending = offset + key.len;

                const equal = (entry.hash == hash) and // check hash first
                    self.keys_bytes[ending] == GUARD_BYTE and // len eql
                    std.mem.eql(u8, self.keys_bytes[offset..ending], key);

                return if (equal) entry.count else 0;
            }
        }

        pub fn validate(self: *Self) bool {
            var prev: HashType = 0;
            for (self.entries[0..]) |entry, i| {
                const curr = entry.hash;
                if (curr < maxx_hash) {
                    if (prev >= curr) {
                        std.debug.print("\n!! hash ko tăng dần !!\n", .{});
                        return false;
                    }
                    prev = curr;

                    if (curr != _hash(self.key_str(i))) {
                        std.debug.print("\n!! hash ko trùng với key !!\n", .{});

                        return false;
                    }
                }
            }
            return true;
        }

        pub fn showStats(self: *Self) void {
            std.debug.print("\n\n(( HASH COUNT STATS ))\n", .{});

            // const len = self.keys_bytes_len;
            // const x = if (len < 2048) len else 2048;
            // const begin = self.keys_bytes[0..x];
            // const y = if (len < 2048) 0 else len - 2048;
            // const end = self.keys_bytes[y..len];
            // std.debug.print("\n{s}\n\n{s}\n\nkeys_bytes_len: {d}\n", .{ begin, end, len });

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
    count_desc_keys: []u8,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.entries);
        self.allocator.free(self.count_desc_keys);
    }

    const pext_u32 = @import("intrinsics.zig").pext_u32;
    pub fn init(self: *Self, allocator: std.mem.Allocator, len: usize, entries: []const Entry, keys_bytes: []const u8, keys_bytes_len: usize) !void {
        self.allocator = allocator;
        self.len = len;
        self.keys_bytes = keys_bytes;

        self.entries = try self.allocator.alloc(Entry, self.len);
        std.mem.set(Entry, self.entries, .{ .hash = maxx_hash, .count = 0, .offset = maxx_offset });

        var i: IndexType = 0;
        for (self.entries) |*new_entry| {
            while (entries[i].count == 0) : (i += 1) {} // bỏ qua
            new_entry.* = entries[i];
            i += 1;
        }
        std.sort.sort(Entry, self.entries, {}, count_desc);

        self.count_desc_keys = try self.allocator.alloc(u8, keys_bytes_len + len * 2);
        // cần 2-bytes lưu reduced coun, lấy lại 1 byte từ GUARD_BYTE nên chỉ cần thêm `len * 1`
        // \count-byte1\count-byte2\len\'key' = key.len + 3
        const low_bitmap: u32 = 0b00000000_00000000_00101010_01010111;
        const high_bitmap: u32 = 0b0101010_10101010_10000000_00000000;
        var x: usize = 0;
        for (self.entries) |entry| {
            // Reduce count from u32 to u16
            self.count_desc_keys[x] = @intCast(u8, pext_u32(entry.count, high_bitmap));
            x += 1;
            self.count_desc_keys[x] = @intCast(u8, pext_u32(entry.count, low_bitmap));
            x += 1;

            const l = keys_bytes[entry.offset - 1];
            const end = entry.offset + l;
            self.count_desc_keys[x] = l; // key's len
            x += 1;

            // copy key bytes
            for (keys_bytes[entry.offset..end]) |byte| {
                self.count_desc_keys[x] = byte;
                x += 1;
            }
        }
        // https://lemire.me/blog/2018/01/08/how-fast-can-you-bit-interleave-32-bit-integers
        // `pdep` and `pext` instructions
    }

    const SPACES = "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t";
    pub fn list(self: Self, max: usize) void {
        std.debug.print("\n\n(( List {d} type counts ))\n", .{max});
        var i: usize = 0;
        const n = if (max < self.len) max else self.len;
        var x: usize = 0;
        while (i < n) : (i += 1) {
            const count = self.count_desc_keys[x] * @as(u32, 256) + self.count_desc_keys[x + 1];
            x += 2;

            const len = self.count_desc_keys[x];
            x += 1;

            const end = x + len;
            const key = self.count_desc_keys[x..end];
            x = end;

            const spaces = SPACES[0 .. (MAX_KEY_LEN - len) / 9];
            std.debug.print("\n\"{s}\" {d: <6}{s}", .{ key, count, spaces });
            // const x = self.len - i - 1;
            // std.debug.print("\"{s}\" {d}", .{ self.key_str(x), self.entries[x].count });
        }
    }

    // pub fn list(self: Self, max: usize) void {
    //     std.debug.print("\n\n(( List {d} type counts ))\n", .{max});
    //     var i: usize = 0;
    //     const n = if (max < self.len) max else self.len;
    //     while (i < n) : (i += 1) {
    //         const entry = self.entries[i];
    //         const key = self.key_str(i);
    //         const spaces = SPACES[0 .. (MAX_KEY_LEN - key.len) / 9];
    //         std.debug.print("\n\"{s}\" {d: <6}{s}", .{ key, entry.count, spaces });
    //         const x = self.len - i - 1;
    //         std.debug.print("\"{s}\" {d}", .{ self.key_str(x), self.entries[x].count });
    //     }
    // }

    // pub fn key_str(self: Self, idx: usize) []const u8 {
    //     const offset = self.entries[idx].offset;
    //     var ending: usize = offset + self.keys_bytes[offset - 1];
    //     return self.keys_bytes[offset..ending];
    // }

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
