const std = @import("std");
const builtin = @import("builtin");
const Prime = @import("primes.zig").Prime;

pub const HashType = u64;
pub const CountType = u32;
pub const IndexType = u24;
pub const KeyType = u32;
pub const SymbolType = u16;

pub const MAX_CAPACITY: usize = std.math.maxInt(IndexType);
pub const MAXX_HASH = std.math.maxInt(HashType);
pub const MAXX_INDEX = std.math.maxInt(IndexType);
pub const MAXX_SYMBOL = std.math.maxInt(SymbolType);

pub const Entry = struct {
    hash: HashType, //           u64
    count: CountType, //         u32
    in_chunks: InChunksType, //  u64 => 8+4+8 = 20-bytes

    // Với u64: x == (x *% 0x517cc1b727220a95) *% 0x2040003d780970bd // wrapping_mul
    pub inline fn key(self: Entry) KeyType {
        return @intCast(KeyType, self.hash *% 0x2040003d780970bd);
    }
};

pub const MAX_CHUNKS = 16;
const InChunksType = std.bit_set.IntegerBitSet(MAX_CHUNKS);

pub fn HashCount(comptime capacity: IndexType) type {
    const bits = std.math.log2_int(HashType, capacity);
    const shift = 63 - bits;
    const size = (@as(usize, 2) << bits) + (capacity / 8);

    // const prime = Prime.pick((capacity) * 2);
    // const size = prime.value;

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
            self.total_puts = 1;

            self.len = 0;
            self.spinlock = lock_init;
            self.allocator = init_allocator;

            self.entries = try self.allocator.alloc(Entry, size);
            std.mem.set(Entry, self.entries, .{
                .hash = MAXX_HASH,
                .count = 0,
                .in_chunks = InChunksType.initEmpty(),
            });
        }

        inline fn recordStats(self: *Self, _probs: usize) void {
            const probs = _probs + 1;
            self.total_probs += probs;
            self.total_puts += 1;
            if (probs > self.max_probs) self.max_probs = probs;
            if (self.max_probs > 500) {
                const percent = (self.len * 100) / size;
                std.debug.print("!!! hash_count_pair.zig:  capacity ko đủ lớn; hastable đầy {d}% !!!", .{percent});
                unreachable;
            }
        }

        // Với u64: x == (x *% 0x517cc1b727220a95) *% 0x2040003d780970bd // wrapping_mul
        inline fn _hash(key: KeyType) HashType {
            return @intCast(HashType, key) *% 0x517cc1b727220a95;
        }

        pub fn putCount(self: *Self, key: KeyType, count: CountType, curr_chunk: usize) *Entry {
            std.debug.assert(curr_chunk < MAX_CHUNKS);

            if (self.len == capacity) {
                std.debug.print("`hash_count_str.zig`: hashtable bị đầy.", .{});
                unreachable;
            }

            var it: Entry = .{
                .hash = _hash(key),
                .count = count,
                .in_chunks = InChunksType.initEmpty(),
            };
            var i: IndexType = @intCast(IndexType, it.hash >> shift);
            // var i = prime.mod(it.hash);
            // const _i = i;

            // Ba bước để đặt `it` vào hashtable
            // 1/ Bỏ qua các entry có hash < it.hash
            while (self.entries[i].hash < it.hash) : (i += 1) {}

            // 2/ Với các entry có hash = it.hash, nếu tìm được entry có key == it.key
            // thì tăng count và return entry.
            const lock_at_step_2 = (count > 1);
            if (lock_at_step_2) {
                while (@atomicRmw(bool, &self.spinlock, .Xchg, true, .SeqCst)) {}
            }
            if (self.entries[i].hash == it.hash) { // key đã tồn tại từ trước
                const entry = &self.entries[i];
                entry.count += count;
                entry.in_chunks.set(curr_chunk);
                // self.recordStats(i - _i);
                if (lock_at_step_2) { // Đảm bảo độ đúng đắn của spinlock,
                    std.debug.assert(@atomicRmw(bool, &self.spinlock, .Xchg, false, .SeqCst));
                } // trước khi trả về kết quả
                return entry;
            }

            // 3/ Nếu ko tìm được entry có key == it.key thì bắt đầu tráo entry với it cho tới khi
            // tìm được ô rỗng để ghi giá trị mới của hashtable
            // Chỉ dùng lock khi có xáo trộn dữ liệu lớn
            if (!lock_at_step_2) {
                while (@atomicRmw(bool, &self.spinlock, .Xchg, true, .SeqCst)) {}
            }

            while (true) : (i += 1) {
                // Tráo giá trị it và entries[i] để đảm bảo tính tăng dần của hash
                const tmp = self.entries[i];
                self.entries[i] = it;

                if (tmp.hash == MAXX_HASH and tmp.in_chunks.count() == 0) { // ô rỗng,
                    self.len += 1; // thêm 1 phần tử mới vào HashCount
                    // self.recordStats(i - _i);
                    self.entries[i].in_chunks.set(curr_chunk);
                    // Đảm bảo độ đúng đắn của spinlock
                    std.debug.assert(@atomicRmw(bool, &self.spinlock, .Xchg, false, .SeqCst));
                    return &self.entries[i];
                }

                it = tmp;
            } // while
        }

        pub inline fn get(self: Self, key: KeyType) CountType {
            const entry = self.getEntry(key);
            if (entry == null) return 0 else return entry.?.count;
        }

        pub fn getEntry(self: Self, key: KeyType) ?*Entry {
            const hash = _hash(key);
            var i = hash >> shift;
            // var i = prime.mod(hash);
            while (self.entries[i].hash < hash) : (i += 1) {}
            if (self.entries[i].hash == hash) return &self.entries[i];
            return null;
        }

        pub fn validate(self: *Self) bool {
            var prev: HashType = 0;

            for (self.entries[0..]) |*entry| {
                const curr = entry.hash;
                if (curr < MAXX_HASH and prev < MAXX_HASH) {
                    if (prev > curr) {
                        std.debug.print("\n!! hash ko tăng dần !!\n", .{});
                        return false;
                    }

                    prev = curr;

                    if (curr != _hash(entry.key())) {
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
