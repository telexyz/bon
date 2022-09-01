const std = @import("std");
const builtin = @import("builtin");

pub const HashType = u32;
pub const CountType = u32;
pub const IndexType = u24;
pub const KeyType = u32;
pub const SymbolType = u16;

pub const MAX_CAPACITY: usize = std.math.maxInt(IndexType);
pub const MAXX_HASH = std.math.maxInt(HashType);
pub const MAXX_INDEX = std.math.maxInt(IndexType);
pub const MAXX_SYMBOL = std.math.maxInt(SymbolType);

pub const Entry = packed struct {
    hash: HashType, //           u32
    count: CountType, //         u32
    key: KeyType, //             u32
    in_chunks: InChunksType, //  u64 => 8+12 = 20-bytes
};

pub const MAX_CHUNKS = 64;
const InChunksType = std.bit_set.IntegerBitSet(MAX_CHUNKS);

pub fn HashCount(capacity: IndexType) type {
    const bits = std.math.log2_int(HashType, capacity);
    const shift = 31 - bits;
    const size = (@as(usize, 2) << bits) + capacity;

    std.debug.assert(size < MAX_CAPACITY);
    std.debug.assert(size > capacity);

    return struct {
        const lock_init = if (builtin.single_threaded) {} else false;

        allocator: std.mem.Allocator,
        spinlock: @TypeOf(lock_init),

        entries: []Entry,
        len: usize,

        // Statistic information
        max_probs: usize,
        total_probs: usize,
        total_puts: usize,

        const Self = @This();

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.entries);
        }

        pub fn init(self: *Self, init_allocator: std.mem.Allocator) !void {
            self.max_probs = 0;
            self.total_probs = 0;
            self.total_puts = 0;

            self.len = 0;
            self.spinlock = lock_init;
            self.allocator = init_allocator;

            self.entries = try self.allocator.alloc(Entry, size);
            std.mem.set(Entry, self.entries, .{
                .hash = MAXX_HASH,
                .key = 0,
                .count = 0,
                .in_chunks = .{ .mask = 0 },
            });
        }

        inline fn recordStats(self: *Self, _probs: usize) void {
            const probs = _probs + 1;
            self.total_probs += probs;
            self.total_puts += 1;
            if (probs > self.max_probs) self.max_probs = probs;
            if (self.max_probs > 500) {
                const percent = (self.len * 100) / size;
                std.debug.print("!!! pair_hash_count.zig:  capacity ko đủ lớn; hastable đầy {d}% !!!", .{percent});
                unreachable;
            }
        }

        inline fn _hash(key: KeyType) HashType {
            return std.hash.Murmur2_32.hashUint32(key);
        }

        pub fn putCount(self: *Self, key: KeyType, count: CountType, curr_chunk: u8) *Entry {
            var it: Entry = .{ .hash = _hash(key), .count = count, .key = key, .in_chunks = .{ .mask = 0 } };
            var i: IndexType = @intCast(IndexType, it.hash >> shift);
            const _i = i;

            // Ba bước để đặt `it` vào hashtable
            // 1/ Bỏ qua các entry có hash < it.hash
            while (self.entries[i].hash < it.hash) : (i += 1) {
                if (i == size) {
                    std.debug.print("`str_hash_count.zig`: hashtable bị đầy.", .{});
                    unreachable;
                }
            }

            // 2/ Với các entry có hash = it.hash, nếu tìm được entry có key == it.key
            // thì tăng count và return entry.
            const lock_at_step_2 = (count > 1);

            if (lock_at_step_2) {
                while (@atomicRmw(bool, &self.spinlock, .Xchg, true, .SeqCst)) {}
            }

            var entry = &self.entries[i];
            while (entry.hash == it.hash) : (i += 1) {
                if (entry.key == key) { // key đã tồn tại từ trước
                    entry.count += count;
                    if (curr_chunk < MAX_CHUNKS) {
                        entry.in_chunks.set(curr_chunk);
                    }
                    self.recordStats(i - _i);

                    // Đảm bảo độ đúng đắn của spinlock
                    if (lock_at_step_2) {
                        std.debug.assert(@atomicRmw(bool, &self.spinlock, .Xchg, false, .SeqCst));
                    }

                    return entry;
                }
                entry = &self.entries[i + 1];
            }

            // 3/ Nếu ko tìm được entry có key == it.key thì bắt đầu tráo entry với it cho tới khi
            // tìm được ô rỗng để ghi giá trị mới của hashtable
            // Chỉ dùng lock khi có xáo trộn dữ liệu lớn
            if (!lock_at_step_2) while (@atomicRmw(bool, &self.spinlock, .Xchg, true, .SeqCst)) {};

            while (true) : (i += 1) {
                if (i == size) {
                    std.debug.print("`str_hash_count.zig`: hashtable bị đầy.", .{});
                    unreachable;
                }
                // Tráo giá trị it và entries[i] để đảm bảo tính tăng dần của hash
                const tmp = self.entries[i];
                self.entries[i] = it;

                // !! Luôn kiểm tra hash == MAXX_HASH để xác định ô rỗng !!
                // Các so sánh khác khác để bổ trợ trường hợp edge case
                if (tmp.hash == MAXX_HASH and tmp.key == 0) { // ô rỗng, dừng thuật toán
                    self.len += 1; // thêm 1 phần tử mới được ghi vào HashCount
                    self.recordStats(i - _i);
                    if (curr_chunk < MAX_CHUNKS) {
                        self.entries[i].in_chunks.set(curr_chunk);
                    }
                    // Đảm bảo độ đúng đắn của spinlock
                    std.debug.assert(@atomicRmw(bool, &self.spinlock, .Xchg, false, .SeqCst));
                    return &self.entries[i];
                }

                it = tmp;
            } // while
        }

        pub fn get(self: Self, key: KeyType) CountType {
            const entry = self.getEntry(key);
            if (entry == null) return 0 else return entry.?.count;
        }

        pub fn getEntry(self: Self, key: KeyType) ?*Entry {
            const hash = _hash(key);
            var i = hash >> shift;

            while (self.entries[i].hash < hash) : (i += 1) {}

            var entry = &self.entries[i];
            while (entry.hash == hash) : (i += 1) {
                if (entry.key == key) return entry;
                entry = &self.entries[i + 1];
            }
            return null;
        }

        pub fn validate(self: *Self) bool {
            var prev: HashType = 0;

            for (self.entries[0..]) |*entry| {
                const curr = entry.hash;
                if (curr < MAXX_HASH) {
                    if (prev > curr) {
                        std.debug.print("\n!! hash ko tăng dần !!\n", .{});
                        return false;
                    }

                    prev = curr;

                    if (curr != _hash(entry.key)) {
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

test "HashCount for bpe" {
    const HC4 = HashCount(4);
    var counters: HC4 = undefined;
    try counters.init(std.testing.allocator);
    defer counters.deinit();

    const x: IndexType = 111;
    try std.testing.expectEqual(counters.get(x), 0);
    // std.debug.print("\n{any}\n", .{counters.entries});
    _ = counters.putCount(x, 1, 0);
    // std.debug.print("\n{any}\n", .{counters.entries});
    try std.testing.expectEqual(counters.get(x), 1);
    _ = counters.putCount(x, 1, 0);
    // std.debug.print("\n{any}\n", .{counters.entries});
    try std.testing.expectEqual(@as(CountType, 2), counters.get(x));

    const y: IndexType = 888;
    try std.testing.expectEqual(counters.get(y), 0);
    _ = counters.putCount(y, 1, 0);
    _ = counters.putCount(y, 1, 0);
    try std.testing.expectEqual(counters.get(y), 2);
}

// FxHasher https://nnethercote.github.io/2021/12/08/a-brutally-effective-hash-function-in-rust.html
// (Are you wondering where the constant 0x517cc1b727220a95 comes from?
// 0xffff_ffff_ffff_ffff / 0x517c_c1b7_2722_0a95 = π.)
//
// Với key cùng type với hash, dùng FxHasher sẽ map 1-1 giữa key và hash nên ko cần lưu riêng giá trị key.
// => Đặc biệt tiện lợi để hash small string (len <= 8)
//
// Với u64: x == (x *% 0x517cc1b727220a95) *% 0x2040003d780970bd // wrapping_mul
// Với u32: 0xffff_ffff / π = 1367130551
//
// https://lemire.me/blog/2017/09/18/computing-the-inverse-of-odd-integers
//
test "TODO" {
    std.debug.print( //
        "\n\n" ++
        "  * Tìm giá trị còn lại của u32 để có wrapping mul giống u64\n" ++
        "\n", .{});
    // std.debug.print("> VAL {d}\n", .{(@as(u32, 3456) *% 1367130551) *% 2654435769});
    // var i: u32 = 0;
    // const max = std.math.maxInt(u32);
    // while (i < max) : (i += 1) {}
}
