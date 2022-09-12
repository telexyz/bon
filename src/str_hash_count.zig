// (Almost-)Concurrent String Hash Count
//
// `key` là chuỗi ngắn độ dài trung bình 15-bytes, được lưu riêng trong mảng keys_bytes
// Mỗi hashtable entry gồm:
// * `hash` u64
// * `count` là u32
// * `offset` u24, trỏ tới vị trí đầu của key trong keys_bytes nếu key là string
// => Total 15-bytes (23% cache-line)
//
// HashCount chỉ cần 2 thao tác là `insert` và `count`
// HashCount cho phép nhiều threads truy cập
//
// Với `count` thực hiện cùng lúc bởi threads mà ko dùng lock có khả năng count update bị trùng lặp
// => chấp nhận được! vì với dữ liệu lớn sai số ko thành vấn đề.
//
// Với `insert` cần phải xử lý race condition ở thao tác grow hashtable. Giải pháp:
// * 1/ Init hashtable size đủ lớn để ko bao giờ phải grow
// * 2/ Dùng lock khi cần grow (chưa impl)
//
// - - -
//
// Có 2 cách cài đặt hash map tốt là `libs/youtokentome/third_party/flat_hash_map.h` và
// `cswisstable`; có thể tìm hiểu cả 2 để có lựa chọn tốt nhất cho HashCount.
//
// >> small strings: 1_099_201, ss puts: 38_210_356, ss bytes: 6_788_771, remain: 14_427_001 <<
//    total          2_051_991           43_811_775
// => Chiếm 87% số lần put vào HashCount

const std = @import("std");
const builtin = @import("builtin");

pub const HashType = u64;
pub const CountType = u32;
pub const IndexType = u24;

pub const GUARD_BYTE = 32; // vì token ko có space nên gán = 32 để in ra dễ đọc

pub const MAX_CAPACITY: usize = std.math.maxInt(IndexType);
pub const MAX_KEY_LEN: usize = 32; // need <= 63 (để dành 1 cho guard byte)
pub const AVG_KEY_LEN: usize = 15;

pub const MAXX_HASH = std.math.maxInt(HashType);
pub const MAXX_INDEX = std.math.maxInt(IndexType);

pub const Entry = packed struct {
    hash: HashType = MAXX_HASH,
    count: CountType = 0,
    offset: IndexType = 0,
};

pub fn HashCount(capacity: IndexType) type {
    const bits = std.math.log2_int(HashType, capacity);
    const shift = 63 - bits;
    const size = (@as(usize, 2) << bits) + capacity;
    const KeyType = []const u8;

    std.debug.assert(size < MAX_CAPACITY);
    std.debug.assert(size > capacity);

    return struct {
        const lock_init = if (builtin.single_threaded) {} else false;

        allocator: std.mem.Allocator,
        spinlock: @TypeOf(lock_init),

        entries: []Entry,
        len: usize,

        keys_bytes: []u8,
        keys_bytes_len: usize,

        // Statistic information
        max_probs: usize,
        total_probs: usize,
        total_puts: usize,

        const Self = @This();

        pub fn deinit(self: *Self) void {
            if (self.len > 0) {
                self.allocator.free(self.entries);
                self.allocator.free(self.keys_bytes);
                self.len = 0;
            }
        }

        pub fn init(self: *Self, init_allocator: std.mem.Allocator) !void {
            self.max_probs = 0;
            self.total_probs = 0;
            self.total_puts = 1; // tránh chia cho 0

            self.len = 0;
            self.keys_bytes_len = MAX_KEY_LEN + 1;
            // Đảm bảo entry.offset > MAX_KEY_LEN để với trường hợp long string
            // thì entry.offset luôn lớn hơn key.len

            self.spinlock = lock_init;
            self.allocator = init_allocator;

            var n: usize = capacity * AVG_KEY_LEN + MAX_KEY_LEN;
            if (n > std.math.maxInt(IndexType)) n = std.math.maxInt(IndexType);
            self.keys_bytes = try self.allocator.alloc(u8, n);
            std.mem.set(u8, self.keys_bytes, GUARD_BYTE);

            self.entries = try self.allocator.alloc(Entry, size);
            std.mem.set(Entry, self.entries, .{ .hash = MAXX_HASH, .count = 0, .offset = 0 });
        }

        inline fn recordStats(self: *Self, _probs: usize) void {
            const probs = _probs + 1;
            self.total_probs += probs;
            self.total_puts += 1;
            if (probs > self.max_probs) self.max_probs = probs;
        }

        fn keyStr(self: Self, entry: *const Entry, ss_ptr: *HashType) []const u8 {
            const offset = entry.offset;
            if (offset <= 8) { // small string
                ss_ptr.* = entry.hash *% 0x2040003d780970bd;
                return std.mem.asBytes(ss_ptr)[0..offset];
            }
            const ending: usize = offset + self.keys_bytes[offset - 1];
            return self.keys_bytes[offset..ending];
        }
        // x == (x * 0x517cc1b727220a95) * 0x2040003d780970bd // wrapping_mul
        inline fn _hash(key: KeyType) HashType {
            if (key.len <= 8) {
                var value: HashType = 0;
                for (key) |byte, i| value += @intCast(HashType, byte) << @intCast(u6, i) * 8;
                return value *% 0x517cc1b727220a95;
            }
            return std.hash.Wyhash.hash(key[0], key);
        }

        pub fn put(self: *Self, key: KeyType) void {
            if (key.len > MAX_KEY_LEN) return; // reject

            if (self.len == capacity) {
                std.debug.print("`str_hash_count.zig`: hashtable bị đầy.", .{});
                unreachable;
            }

            var it: Entry = .{ .hash = _hash(key), .count = 1 };
            var i: IndexType = @intCast(IndexType, it.hash >> shift);
            // const _i = i;

            while (self.entries[i].hash < it.hash) : (i += 1) {}

            var ss: HashType = undefined;
            const ss_ptr = &ss;
            var entry = &self.entries[i];
            while (entry.hash == it.hash) : (i += 1) {
                // key ngắn cần offset == key.len, còn ko so sánh cả key
                const found = (entry.offset == key.len) or
                    (std.mem.eql(u8, self.keyStr(entry, ss_ptr), key));
                if (found) { // key đã tồn tại từ trước
                    entry.count += 1; // xáo trộn duy nhất là thay đổi giá trị count
                    // self.recordStats(i - _i);
                    return;
                }
                entry = &self.entries[i + 1];
            }

            { // Chỉ dùng lock khi có xáo trộn dữ liệu lớn
                while (@atomicRmw(bool, &self.spinlock, .Xchg, true, .SeqCst)) {}
                defer std.debug.assert(@atomicRmw(bool, &self.spinlock, .Xchg, false, .SeqCst));

                // key lần đầu xuất hiện, ghi lại offset
                // for_bpe key đã được mã hoá trong hash nên ko cần ghi lại
                if (key.len <= 8) {
                    it.offset = @intCast(IndexType, key.len);
                } else {
                    var ending = self.keys_bytes_len;
                    self.keys_bytes[ending] = @intCast(u8, key.len);
                    it.offset = @intCast(IndexType, ending + 1);
                    ending += 1;
                    for (key) |byte| {
                        self.keys_bytes[ending] = byte;
                        ending += 1;
                    }
                    self.keys_bytes[ending] = GUARD_BYTE;
                    self.keys_bytes_len = ending + 1;
                }

                while (true) : (i += 1) {
                    // Tráo giá trị it và entries[i] để đảm bảo tính tăng dần của hash
                    const tmp = self.entries[i];
                    self.entries[i] = it;
                    // !! Luôn kiểm tra hash == MAXX_HASH để xác định ô rỗng !!
                    // Các so sánh khác khác để bổ trợ trường hợp edge case
                    if (tmp.hash == MAXX_HASH and tmp.offset == 0) { // ô rỗng, dừng thuật toán
                        self.len += 1; // thêm 1 phần tử mới được ghi vào HashCount
                        // self.recordStats(i - _i);
                        return;
                    }
                    it = tmp;
                } // while
            } // spinlock context
        }

        pub fn get(self: Self, key: KeyType) CountType {
            if (key.len > MAX_KEY_LEN) return 0;
            const hash = _hash(key);
            var i = hash >> shift;

            while (self.entries[i].hash < hash) : (i += 1) {}

            var entry = &self.entries[i];
            var ss: HashType = undefined;
            const ss_ptr = &ss;

            while (entry.hash == hash) : (i += 1) {
                const found = std.mem.eql(u8, self.keyStr(entry, ss_ptr), key);
                if (found) return entry.count;
                entry = &self.entries[i + 1];
            }

            return 0;
        }

        pub fn validate(self: *Self) bool {
            var prev: HashType = 0;
            var ss: HashType = undefined;
            const ss_ptr = &ss;

            for (self.entries[0..]) |*entry| {
                const curr = entry.hash;
                if (curr < MAXX_HASH) {
                    if (prev > curr) {
                        std.debug.print("\n!! hash ko tăng dần !!\n", .{});
                        return false;
                    }
                    prev = curr;

                    const hash = _hash(self.keyStr(entry, ss_ptr));
                    if (curr != hash) {
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
                "\nTOTAL {d} entries, max_probs: {d}, avg_probs: {d} ({d} / {d}).",
                .{ self.len, self.max_probs, avg_probs, self.total_probs, self.total_puts },
            );
            std.debug.print("\nHash Count Validation: {}\n", .{self.validate()});
        }
    };
}

test "HashCount for string" {
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
