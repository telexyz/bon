// (Almost-)Concurrent String Hash Count
//
// `key` là chuỗi ngắn độ dài trung bình 15-bytes, được lưu riêng trong mảng keys_bytes
// Mỗi hashtable entry gồm:
// * `hash` u64
// * `count` là u24
// * `offset` u24, trỏ tới vị trí đầu của key trong keys_bytes nếu key là string
// => Total 14-bytes (22% cache-line)
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
pub const CountType = u24;
pub const IndexType = u24;
pub const PairType = u48;

pub const GUARD_BYTE = 32; // vì token ko có space nên gán = 32 để in ra dễ đọc

pub const MAX_CAPACITY: usize = std.math.maxInt(IndexType);
pub const MAX_KEY_LEN: usize = 63; // need <= 63 (để dành 1 cho guard byte)
pub const AVG_KEY_LEN: usize = 15;

const maxx_hash = std.math.maxInt(HashType);
const maxx_index = std.math.maxInt(IndexType);

pub const Entry = packed struct {
    hash: HashType = maxx_hash,
    count: CountType = 0,
    offset: IndexType = 0,
};

pub const Config = struct {
    capacity: usize,
    for_bpe: bool,
};

pub fn HashCount(comptime cfg: Config) type {
    const bits = std.math.log2_int(u64, cfg.capacity);
    const shift = 63 - bits;
    const size = (@as(usize, 2) << bits) + cfg.capacity;
    const KeyType = if (cfg.for_bpe) PairType else []const u8;

    std.debug.assert(size < MAX_CAPACITY);
    std.debug.assert(size > cfg.capacity);
    // std.debug.assert(cfg.capacity * AVG_KEY_LEN < MAX_CAPACITY);

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
            self.allocator.free(self.entries);
            if (!cfg.for_bpe) {
                self.allocator.free(self.keys_bytes);
            }
        }

        pub fn init(self: *Self, init_allocator: std.mem.Allocator) !void {
            self.max_probs = 0;
            self.total_probs = 0;
            self.total_puts = 0;

            self.len = 0;
            self.keys_bytes_len = MAX_KEY_LEN; // 0-8 để dành lưu len của small string

            self.spinlock = lock_init;
            self.allocator = init_allocator;

            if (!cfg.for_bpe) {
                var n: usize = cfg.capacity * AVG_KEY_LEN;
                if (n > std.math.maxInt(IndexType)) n = std.math.maxInt(IndexType);
                self.keys_bytes = try self.allocator.alloc(u8, n);
                std.mem.set(u8, self.keys_bytes, GUARD_BYTE);
            }

            self.entries = try self.allocator.alloc(Entry, size);
            std.mem.set(Entry, self.entries, .{ .hash = maxx_hash, .count = 0, .offset = 0 });
        }

        inline fn recordStats(self: *Self, _probs: usize) void {
            const probs = _probs + 1;
            self.total_probs += probs;
            self.total_puts += 1;
            if (probs > self.max_probs) self.max_probs = probs;
        }

        fn keyPair(entry: Entry) PairType {
            return @intCast(PairType, entry.hash *% 0x2040003d780970bd);
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
            if (cfg.for_bpe) {
                return @intCast(HashType, key) *% 0x517cc1b727220a95;
            } else {
                if (key.len <= 8) {
                    var value: HashType = 0;
                    for (key) |byte, i| {
                        value += @intCast(HashType, byte) << @intCast(u6, i) * 8;
                    }
                    return value *% 0x517cc1b727220a95;
                } else {
                    return std.hash.Wyhash.hash(key[0], key);
                }
            }
        }

        pub inline fn put(self: *Self, key: KeyType) void {
            _ = self.putCount(key, 1);
        }

        pub fn putCount(self: *Self, key: KeyType, count: CountType) usize {
            if (!cfg.for_bpe and key.len > MAX_KEY_LEN) return maxx_index; // reject

            var it: Entry = .{ .hash = _hash(key), .count = count };
            var i: usize = it.hash >> shift;
            const _i = i;

            while (self.entries[i].hash < it.hash) : (i += 1) {
                if (i == size) {
                    std.debug.print("`str_hash_count.zig`: hashtable bị đầy.", .{});
                    unreachable;
                }
            }

            var entry = &self.entries[i];
            var ss: HashType = undefined;
            const ss_ptr = &ss;

            while (entry.hash == it.hash) {
                // for_bpe cần hash = nhau, key ngắn cần offset == key.len, còn ko so sánh cả key
                const found = cfg.for_bpe or entry.offset == key.len or (std.mem.eql(u8, self.keyStr(entry, ss_ptr), key));

                if (found) { // key đã tồn tại từ trước
                    entry.count += count; // xáo trộn duy nhất là thay đổi giá trị count
                    self.recordStats(i - _i);
                    return i;
                }

                i += 1;
                entry = &self.entries[i];
            }

            { // Chỉ dùng lock khi có xáo trộn dữ liệu lớn
                while (@atomicRmw(bool, &self.spinlock, .Xchg, true, .SeqCst)) {}
                defer std.debug.assert(@atomicRmw(bool, &self.spinlock, .Xchg, false, .SeqCst));

                // key lần đầu xuất hiện, ghi lại offset
                // for_bpe key đã được mã hoá trong hash nên ko cần ghi lại
                if (!cfg.for_bpe) {
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
                }

                while (true) : (i += 1) {
                    if (i == size) {
                        std.debug.print("`str_hash_count.zig`: hashtable bị đầy.", .{});
                        unreachable;
                    }
                    // Tráo giá trị it và entries[i] để đảm bảo tính tăng dần của hash
                    const tmp = self.entries[i];
                    self.entries[i] = it;
                    if (tmp.offset == 0) { // ô rỗng, dừng thuật toán
                        self.len += 1; // thêm 1 phần tử mới được ghi vào HashCount
                        self.recordStats(i - _i);
                        return i;
                    }
                    it = tmp;
                } // while
            } // Mutex
        }

        pub fn get(self: *Self, key: KeyType) CountType {
            const entry = self.getEntry(key);
            if (entry == null) return 0 else return entry.?.count;
        }

        pub fn getEntry(self: *Self, key: KeyType) ?*Entry {
            if (!cfg.for_bpe and key.len > MAX_KEY_LEN) return null;
            const hash = _hash(key);
            var i = hash >> shift;

            while (self.entries[i].hash < hash) : (i += 1) {}

            var entry = &self.entries[i];
            var ss: HashType = undefined;
            const ss_ptr = &ss;

            while (entry.hash == hash) {
                const found = cfg.for_bpe or std.mem.eql(u8, self.keyStr(entry, ss_ptr), key);
                if (found) {
                    return entry;
                }

                i += 1;
                entry = &self.entries[i];
            }

            return null;
        }

        pub fn validate(self: *Self) bool {
            var prev: HashType = 0;
            var ss: HashType = undefined;
            const ss_ptr = &ss;

            for (self.entries[0..]) |*entry| {
                const curr = entry.hash;
                if (curr < maxx_hash) {
                    if (prev > curr) {
                        std.debug.print("\n!! hash ko tăng dần !!\n", .{});
                        return false;
                    }
                    prev = curr;

                    if (curr != _hash(self.keyStr(entry, ss_ptr))) {
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

    pub fn init(self: *Self, allocator: std.mem.Allocator, len: usize, entries: []const Entry, keys_bytes: []const u8, keys_bytes_len: usize) !void {
        self.allocator = allocator;
        self.len = len;
        self.keys_bytes = keys_bytes;

        self.entries = try self.allocator.alloc(Entry, self.len);
        std.mem.set(Entry, self.entries, .{ .hash = maxx_hash, .count = 0, .offset = maxx_index });

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

    pub fn keyStr(self: *Self, entry: Entry, ss_ptr: *HashType) []const u8 {
        const offset = entry.offset;
        if (offset <= 8) { // small string
            ss_ptr.* = entry.hash *% 0x2040003d780970bd;
            return std.mem.asBytes(ss_ptr)[0..offset];
        }
        const ending: usize = offset + self.keys_bytes[offset - 1];
        return self.keys_bytes[offset..ending];
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
            // count trích xuất từ 3-bytes đầu tiên
            const count = (@as(u24, self.vocabs[x]) << 16) + (@as(u24, self.vocabs[x + 1]) << 8) + self.vocabs[x + 2];
            // byte tiếp theo chứa key's len
            const len = self.vocabs[x + 3];
            x += 4;

            // các bytes tiếp theo là của key
            const end = x + len;
            const key = self.vocabs[x..end];
            x = end;

            std.debug.print("`{s}`:{d: <6}", .{ key, count });
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

test "HashCount for string" {
    const HC1024 = HashCount(.{ .capacity = 1024, .for_bpe = false });
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

test "HashCount for bpe" {
    const HC4 = HashCount(.{ .capacity = 4, .for_bpe = true });
    var counters: HC4 = undefined;
    try counters.init(std.testing.allocator);
    defer counters.deinit();

    const x: IndexType = 111;
    try std.testing.expectEqual(counters.get(x), 0);
    // std.debug.print("\n{any}\n", .{counters.entries});
    counters.put(x);
    // std.debug.print("\n{any}\n", .{counters.entries});
    try std.testing.expectEqual(counters.get(x), 1);
    counters.put(x);
    // std.debug.print("\n{any}\n", .{counters.entries});
    try std.testing.expectEqual(@as(CountType, 2), counters.get(x));

    const y: IndexType = 888;
    try std.testing.expectEqual(counters.get(y), 0);
    counters.put(y);
    counters.put(y);
    try std.testing.expectEqual(counters.get(y), 2);
}

pub fn main() !void {
    const HC1024 = HashCount(.{ .capacity = 1024, .for_bpe = true });
    var counters: HC1024 = undefined;
    try counters.init(std.heap.c_allocator);
    defer counters.deinit();
    const x: IndexType = 111;
    counters.put(x);
    _ = counters.get(x);
}
