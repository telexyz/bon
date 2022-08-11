// (Almost-)Concurrent Hash Count
//
// `key` là chuỗi ngắn <= 32-bytes (0 padding cho đủ 32-bytes để có thể so sánh = SIMD)
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
// unique tokens gọi là types. Giả sử có 1 triệu (2^20) types => 1M * 36-bytes = 36 Mb

// Modified from https://raw.githubusercontent.com/telexyz/engine/main/.save/hash_count.zig

const std = @import("std");
const Wyhash = std.hash.Wyhash;

const math = std.math;
const mem = std.mem;
const Allocator = mem.Allocator;

pub fn HashCount(comptime capacity: u32) type {
    std.debug.assert(math.isPowerOfTwo(capacity));

    const shift = 63 - math.log2_int(u64, capacity) + 1;
    const overflow = capacity / 10 + math.log2_int(u64, capacity) << 1;
    const size: usize = capacity + overflow;

    return struct {
        pub const HashType = u64;
        pub const CountType = u32;
        const VecType = @Vector(KEY_BYTE_LEN, u8);

        pub const KEY_BYTE_LEN: usize = 32;
        pub const KeyType = [KEY_BYTE_LEN]u8;
        const maxx_hash: HashType = std.math.maxInt(HashType);

        pub const Entry = struct {
            hash: HashType = maxx_hash,
            count: CountType = 0,
            key: KeyType = undefined,
        };

        const Self = @This();

        allocator: Allocator = undefined,
        entries: []Entry = undefined,
        len: usize = undefined,

        pub fn init(self: *Self, init_allocator: Allocator) !void {
            self.allocator = init_allocator;
            self.len = 0;

            self.entries = try self.allocator.alloc(Entry, size);
            var entry = Entry{ .hash = maxx_hash, .count = 0 };
            std.mem.set(u8, entry.key[0..], 0);
            mem.set(Entry, self.entries, entry);
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.entries);
        }

        pub fn slice(self: Self) []Self.Entry {
            return self.entries[0..size];
        }

        pub fn put(self: *Self, key: []const u8) CountType {
            if (key.len > 31) return 0;

            var it: Self.Entry = .{
                .hash = Wyhash.hash(0, key),
                .count = 1,
            };

            // std.debug.print("\nhash: {x}", .{it.hash});
            // gán giá trị cho entry.key
            var x: usize = 0;
            while (x < key.len) : (x += 1) it.key[x] = key[x];
            it.key[x] = 0;

            // Sử dụng capacity isPowerOfTwo và dùng hàm shift để băm hash vào index.
            // Nhờ dùng right-shift nên giữ được bit cao của hash value trong index
            // Vậy nên đảm bảo tính tăng dần của hash value (clever trick 1)
            var i = it.hash >> shift;

            while (true) : (i += 1) {
                // std.debug.print("{d}-", .{i});
                const entry = self.entries[i];

                // Vì hash được khởi tạo = maxx_hash nên đảm bảo slot trống
                // có hash value >= hash đang xem xét (clever trick 2)
                if (entry.hash >= it.hash) {
                    // Tìm dc slot
                    if (equal(entry.key, it.key)) {
                        // Tìm được đúng ô chứa, tăng count lên 1 and return :)
                        self.entries[i].count += 1;
                        return entry.count + 1;
                    }

                    // Không đúng ô chứa mà hash của ô lại lớn hơn thì ta ghi đè giá trị
                    // của it vào đó
                    self.entries[i] = it;

                    // Nếu ô đó là ô rỗng, count == 0 nghĩa là chưa lưu gì cả, thì
                    // key đầu vào lần đầu xuất hiện, ta tăng len và return :D
                    if (entry.count == 0) {
                        self.len += 1;
                        return 1;
                    }

                    // Tráo giá trị it và entries[i]
                    // để đảm bảo tính tăng dần của hash value
                    it = entry;
                }
            } // while
        }

        pub fn get(self: *Self, key: []const u8) CountType {
            if (key.len > 31) return 0;

            const hash = Wyhash.hash(0, key);
            // std.debug.print("\nhash: {x}", .{hash});

            var i = hash >> shift;
            // Vì hash value luôn tăng nên khi entry.hash > hash nghĩa là key chưa dc đếm
            while (true) : (i += 1) {
                const entry = self.entries[i];
                if (entry.hash >= hash) {
                    // std.debug.print("\nentry.key: {s}", .{entry.key[0..key.len]});
                    if (entry.key[key.len] == 0 and
                        std.mem.eql(u8, entry.key[0..key.len], key))
                    {
                        return entry.count;
                    }
                    return 0;
                }
            }
        }

        pub inline fn equal(a: KeyType, b: KeyType) bool {
            const v1: VecType = a;
            const v2: VecType = b;
            const match = @ptrCast(*const u32, &(v1 == v2)).*;
            return !(match < std.math.maxInt(u32));
        }
    };
}

test "HashCount" {
    const HC1024 = HashCount(1024);
    var counters: HC1024 = undefined;
    try counters.init(std.heap.page_allocator);
    defer counters.deinit();
    try std.testing.expectEqual(@as(HC1024.CountType, 1), counters.put("a"));
    try std.testing.expectEqual(@as(HC1024.CountType, 1), counters.get("a"));
    try std.testing.expectEqual(@as(HC1024.CountType, 0), counters.get("b"));
    try std.testing.expectEqual(@as(HC1024.CountType, 2), counters.put("a"));
    try std.testing.expectEqual(@as(HC1024.CountType, 1), counters.put("b"));
}
