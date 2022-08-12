// (Almost-)Concurrent Hash Count
//
// `key` là chuỗi ngắn độ dài trung bình 32-bytes
// `hash` u64
// `count` là u32
//
// HashCount chỉ cần 2 thao tác là `insert` và `count`
// HashCount cho phép nhiều threads truy cập
//
// Với `count` thực hiện cùng lúc bởi threads mà ko dùng lock có khả năng count update ko kịp
// => chấp nhận được! vì với dữ liệu lớn sai số ko thành vấn đề.
//
// Với `insert` cần phải xử lý race condition ở thao tác grow hashtable. Giải pháp:
// 1/ Init hashtable size đủ lớn để ko bao giờ phải grow bởi bất cứ threads nào
// 2/ Dùng lock khi cần grow
//
// - - -
//
// Có 2 cách cài đặt hash map tốt là `libs/youtokentome/third_party/flat_hash_map.h` và `libs/swisstable`
// có thể tìm hiểu cả 2 để có lựa chọn tốt nhất cho HashCount.
//
// => * Làm cách 1/ trước để thử nghiệm tốc độ!
//    * Dùng lại code của `telexyz/engine`
//
// 32-bytes + u32 + u64 = 44-bytes
// unique tokens gọi là types. Giả sử có 1 triệu (2^20) types => 1M * 36-bytes = 44 Mb

// Algorithm from https://raw.githubusercontent.com/lithdew/rheia/master/hash_map.zig

const std = @import("std");

pub const HashType = u64;
pub const CountType = u32;
pub const IndexType = u32;

pub const GUARD_BYTE = 32; // vì token ko có space nên gán = 32 để in ra dễ đọc

pub const MAX_CAPACITY: usize = std.math.maxInt(u24); // = IndexType - 5-bits (2^5 = 32)
pub const MAX_KEY_LEN: usize = 50;
pub const AVG_KEY_LEN: usize = 20;

const maxx_hash = std.math.maxInt(HashType);
const maxx_index = std.math.maxInt(IndexType);

pub const Entry = packed struct {
    hash: HashType = maxx_hash,
    count: CountType = 0,
    key_offset: IndexType = maxx_index,

    pub inline fn key(self: Entry, key_bytes: []const u8, len: usize) []const u8 {
        return key_bytes[self.key_offset .. self.key_offset + len];
    }

    pub inline fn key_str(self: Entry, key_bytes: []const u8) []const u8 {
        var ending: usize = self.key_offset + 1;
        while (key_bytes[ending] != GUARD_BYTE) ending += 1;
        return key_bytes[self.key_offset..ending];
    }
};

pub fn HashCount(capacity: usize) type {
    const bits = std.math.log2_int(u64, capacity);
    const shift = 63 - bits;
    const size = @as(usize, 2) << bits;

    std.debug.assert(size < MAX_CAPACITY);
    std.debug.assert(size > capacity);

    return struct {
        const Self = @This();

        allocator: std.mem.Allocator = undefined,
        entries: []Entry = undefined,
        len: usize = 0,

        key_bytes: []u8 = undefined,
        key_index: usize = 0,

        pub fn init(self: *Self, init_allocator: std.mem.Allocator) !void {
            self.allocator = init_allocator;
            self.len = 0;
            self.key_index = 0;

            self.key_bytes = try self.allocator.alloc(u8, capacity * AVG_KEY_LEN);
            self.entries = try self.allocator.alloc(Entry, size);

            const entry = Entry{ .hash = maxx_hash, .count = 0, .key_offset = maxx_index };
            std.mem.set(Entry, self.entries, entry);
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.entries);
            self.allocator.free(self.key_bytes);
        }

        pub fn slice(self: Self) []Self.Entry {
            return self.entries[0..size];
        }

        inline fn _hash(key: []const u8) u64 {
            return std.hash.Wyhash.hash(key[0], key);
        }

        pub fn put(self: *Self, key: []const u8) CountType {
            if (key.len > MAX_KEY_LEN) return 0;

            var it: Entry = .{
                .hash = _hash(key),
                .count = 1, // phần tử nếu được thêm sẽ có count = 1
            };

            // Sử dụng capacity isPowerOfTwo và dùng hàm shift để băm hash vào index.
            // Nhờ dùng right-shift nên giữ được bit cao của hash value trong index
            // Vậy nên đảm bảo tính tăng dần của hash value (clever trick 1)
            var i = it.hash >> shift;
            var first_swap_at: usize = maxx_index;

            while (true) : (i += 1) {
                const entry = self.entries[i];

                // Vì hash được khởi tạo = maxx_hash nên đảm bảo slot trống
                // có hash value >= hash đang xem xét (clever trick 2)
                if (entry.hash < it.hash) continue;

                if (entry.hash == it.hash) {
                    // Tìm được đúng ô chứa, tăng count lên 1 and return
                    self.entries[i].count += 1;
                    return entry.count + 1;
                    //
                } else {
                    // Không đúng ô chứa mà hash của ô lại lớn hơn
                    // thì ta ghi đè giá trị của it vào đó
                    self.entries[i] = it;
                    if (first_swap_at == maxx_index) {
                        first_swap_at = i;
                    }

                    // Nếu ô đó là ô rỗng, count == 0 nghĩa là chưa lưu gì cả, thì
                    // key đầu vào lần đầu xuất hiện, ta tăng len và return
                    if (entry.count == 0) {
                        // gán giá trị key cho entries[first_swap_at]
                        self.entries[first_swap_at].key_offset = @intCast(IndexType, self.key_index);
                        var ending = self.key_index;
                        @setRuntimeSafety(false);
                        for (key) |k| {
                            self.key_bytes[ending] = k;
                            ending += 1;
                        }
                        self.key_bytes[ending] = GUARD_BYTE;
                        self.key_index = ending + 1;

                        // tăng số lượng phần tử được đếm
                        self.len += 1;
                        return 1; // phần tử vừa được thêm nên count = 1
                    }

                    // Tráo giá trị it và entries[i]
                    // để đảm bảo tính tăng dần của hash value (clever trick 3)
                    it = entry;
                } // else
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

                const equal = (entry.hash == hash) and // check hash first
                    self.key_bytes[entry.key_offset + key.len] == GUARD_BYTE and // len eql
                    std.mem.eql(u8, entry.key(self.key_bytes, key.len), key);

                return if (equal) entry.count else 0;
            }
        }

        pub fn list(self: *Self, max: usize) void {
            var i: usize = 0;
            var n: usize = 0;
            while (i < size) : (i += 1) {
                const entry = self.entries[i];
                if (entry.count > 0) {
                    std.debug.print("\ncount[{s}]: {d}", .{
                        entry.key_str(self.key_bytes),
                        entry.count,
                    });
                    n += 1;
                    if (n > max) break;
                }
            }

            if (max == 0)
                std.debug.print("\nTOTAL {d}.\n{s}\n", .{ self.len, self.key_bytes[0..2048] });
        }
    };
}

test "HashCount" {
    const HC1024 = HashCount(1024);
    var counters: HC1024 = undefined;
    try counters.init(std.heap.page_allocator);
    defer counters.deinit();
    try std.testing.expectEqual(@as(CountType, 1), counters.put("a"));
    try std.testing.expectEqual(@as(CountType, 1), counters.get("a"));
    try std.testing.expectEqual(@as(CountType, 0), counters.get("b"));
    try std.testing.expectEqual(@as(CountType, 2), counters.put("a"));
    try std.testing.expectEqual(@as(CountType, 1), counters.put("b"));
}
