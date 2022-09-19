/// Cách phân tích ngữ âm dùng luật if-then-else chậm vì rẽ nhánh nhiều
/// Mục đích cuối cùng là để map token => syllable_id
/// Vậy ta tiếp cận bằng cách khác là sinh sẵn map khi khởi tạo chương trình
/// Và việc phân tích ngữ âm đơn giản chỉ là 1 cấu trúc dữ liệu
const std = @import("std");
const Syllable = @import("syllable.zig").Syllable;

// Công thức dùng để đảo người hash và keyStr:
// x == (x *% 0x517cc1b727220a95) *% 0x2040003d780970bd // *%: wrapping_mul
// inline fn _hash(key: *Syllable.BytesBuf, len: usize) u64 {
//     std.mem.set(u8, key[len..], 0);
//     const value = @ptrCast(*align(1) const u64, &key).*;
//     return value *% 0x517cc1b727220a95;
// }
inline fn _hash(key: *Syllable.BytesBuf, len: usize) u64 {
    const n: usize = if (len > 8) 8 else len;
    var value: u64 = key[n - 1];
    var i: usize = 2;
    while (i <= n) : (i += 1) {
        value <<= 8;
        value |= key[n - i];
    }
    return value *% 0x517cc1b727220a95;
}

pub const TokenToSyll = struct {
    const KeyType = []const u8;
    const IndexType = u24;
    const HashType = u64;
    const MAXX_HASH = std.math.maxInt(HashType);

    const Entry = packed struct {
        hash: HashType = MAXX_HASH,
        syll: Syllable.UniqueId = Syllable.MAXX_ID,
        lolb: u8 = 0,
        // lolb: len_or_last_byte có giá trị 1..8 nến key.len < 8 hoặc last_byte của key
        // bởi với các âm tiết utf-8 viết thường max sylalble bytes = 9
        pub inline fn keyStr(self: Entry, buf: *Syllable.BytesBuf) []const u8 {
            @ptrCast(*align(1) HashType, buf[0..8]).* = self.hash *% 0x2040003d780970bd;
            buf[8] = self.lolb;
            const n: usize = if (self.lolb > 8) 9 else self.lolb;
            return buf[0..n];
        }
    };

    const capacity: usize = Syllable.MAXX_ID;
    const bits = std.math.log2_int(usize, capacity);
    const shift = 63 - bits;
    const size = (@as(usize, 2) << bits) + (capacity / 8);

    allocator: std.mem.Allocator,
    entries: []Entry,
    entries_len: usize,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        if (self.entries_len > 0) {
            self.allocator.free(self.entries);
            self.entries_len = 0;
        }
    }

    pub fn init(self: *Self, init_allocator: std.mem.Allocator) !void {
        self.allocator = init_allocator;
        self.entries_len = 0;

        self.entries = try self.allocator.alloc(Entry, size);
        std.mem.set(Entry, self.entries, .{
            .hash = MAXX_HASH,
            .syll = Syllable.MAXX_ID,
            .lolb = 0,
        });
    }

    pub fn put(self: *Self, key: *Syllable.BytesBuf, len: usize, syll: Syllable.UniqueId) void {
        std.debug.assert(len <= 9);

        var it: Entry = .{ .hash = _hash(key, len), .syll = syll };
        var i = @intCast(usize, it.hash >> shift);
        while (true) : (i += 1) {
            const entry = self.entries[i];
            if (entry.hash > it.hash) {
                break;
            }
            if (entry.hash == it.hash and (entry.lolb == len or entry.lolb == key[8]) and
                syll != entry.syll)
            {
                var buf: Syllable.BytesBuf = undefined;
                std.debug.print("\n>> {d} => '{s}' and {d} => '{s}' map to the same token\n", .{ syll, key[0..len], entry.syll, entry.keyStr(&buf) });
                std.debug.print("\n{any}\n\n{any}\n\n", .{ Syllable.newFromId(syll), Syllable.newFromId(entry.syll) });
                unreachable;
            }
        }

        // key lần đầu xuất hiện, ghi lại offset
        it.lolb = if (len < 9) @intCast(u8, len) else key[8];

        // lolb (len or last byte) chỉ có <= 8 hoặc 'g' hoặc 'h', là ký tự cuối
        // của âm cuối dài nhất `ng`, `nh`, `ch`
        std.debug.assert(it.lolb <= 8 or it.lolb == 'g' or it.lolb == 'h');

        var buf: Syllable.BytesBuf = undefined;
        const token = it.keyStr(&buf);
        if (_hash(&buf, token.len) != it.hash) {
            std.debug.print("\n >> '{s}' =? '{s}'", .{ key[0..len], token });
            std.debug.print("\n >> {any}", .{it});
            unreachable;
        }

        while (true) : (i += 1) {
            // Tráo giá trị it và entries[i] để đảm bảo tính tăng dần của hash
            const tmp = self.entries[i];
            self.entries[i] = it;
            if (tmp.hash == MAXX_HASH and tmp.lolb == 0) { // ô rỗng, dừng thuật toán
                self.entries_len += 1; // thêm 1 phần tử mới được ghi vào HashCount
                return;
            }
            it = tmp;
        } // while
    }

    pub fn get(self: Self, key: *Syllable.BytesBuf, len: usize) ?*Entry {
        if (len > 9) return null;

        const hash = _hash(key, len);
        var i = hash >> shift;

        while (self.entries[i].hash < hash) : (i += 1) {}

        var entry = &self.entries[i];

        while (entry.hash == hash) : (i += 1) {
            const found = (entry.lolb == len) or entry.lolb == key[8];
            if (found) return entry;
            entry = &self.entries[i + 1];
        }

        return null;
    }

    pub fn validate(self: *Self) bool {
        var prev: HashType = 0;
        var buff: Syllable.BytesBuf = undefined;

        for (self.entries[0..]) |*entry| {
            const curr = entry.hash;
            if (curr < MAXX_HASH and prev < MAXX_HASH) {
                if (prev > curr) {
                    std.debug.print("\n!! hash ko tăng dần !!\n", .{});
                    return false;
                }
                prev = curr;

                const token = entry.keyStr(&buff);
                const hash = _hash(&buff, token.len);
                if (curr != hash) {
                    std.debug.print("\n!! hash ko trùng với key !!\n", .{});
                    return false;
                }
            }
        }
        return true;
    }
};

pub fn initToken2Syll(allocator: std.mem.Allocator) !TokenToSyll {
    var token2syll: TokenToSyll = undefined;
    try token2syll.init(allocator);

    var syll: Syllable.UniqueId = 0;
    var buf0: Syllable.BytesBuf = undefined;

    while (syll < Syllable.MAXX_ID) : (syll += 1) {
        var am_tiet = Syllable.newFromId(syll);
        if (am_tiet.invalid()) continue;

        const token = am_tiet.printBuffUtf8(buf0[0..]);
        am_tiet.normalize();
        if (!am_tiet.can_be_vietnamese) continue;

        const true_id = am_tiet.toId();
        token2syll.put(&buf0, token.len, true_id);
    }

    if (!token2syll.validate()) {
        std.debug.print("\ntoken2syll is invalid!\n", .{});
        unreachable;
    }

    return token2syll;
}

pub fn main() !void {
    var token2syll = try initToken2Syll(std.heap.page_allocator);
    defer token2syll.deinit();

    var syll: Syllable.UniqueId = 0;
    var buf0: Syllable.BytesBuf = undefined;
    var buf1: Syllable.BytesBuf = undefined;
    var count: usize = 0;

    while (syll < Syllable.MAXX_ID) : (syll += 1) {
        var am_tiet = Syllable.newFromId(syll);
        if (am_tiet.invalid()) continue;

        const token = am_tiet.printBuffUtf8(buf0[0..]);
        am_tiet.normalize();
        if (!am_tiet.can_be_vietnamese) continue;

        if (token.len > 8) {
            count += 1;
            std.debug.print("{s} ", .{token});
        }

        const true_id = am_tiet.toId();
        const entry = token2syll.get(&buf0, token.len);

        if (entry == null) {
            std.debug.print("{s} null; ", .{token});
            unreachable;
        }

        const value = entry.?.syll;
        const key = entry.?.keyStr(&buf1);

        if (true_id != value) {
            std.debug.print("{s} {d} {d}; ", .{ token, syll, value });
            std.debug.print("\n{any}\n{any}\n", .{ am_tiet, Syllable.newFromId(value) });
            unreachable;
        }

        if (!std.mem.eql(u8, token, key)) {
            std.debug.print("{s}|{s}; ", .{ token, key });
            unreachable;
        }
    }
    std.debug.print("\nTổng số âm tiết có len == 9 là {d}", .{count});
}

test "initToken2Syll" {
    main();
}
