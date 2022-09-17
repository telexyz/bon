/// Cách phân tích ngữ âm dùng luật if-then-else chậm vì rẽ nhánh nhiều
/// Mục đích cuối cùng là để map token => syllable_id
/// Vậy ta tiếp cận bằng cách khác là sinh sẵn map khi khởi tạo chương trình
/// Và việc phân tích ngữ âm đơn giản chỉ là 1 cấu trúc dữ liệu
const std = @import("std");
const Syllable = @import("syllable.zig").Syllable;

const TokenToSyll = struct {
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
        pub inline fn keyStr(self: Entry, ss_ptr: *u72) []const u8 {
            ss_ptr.* = (@intCast(u72, self.hash *% 0x2040003d780970bd) << 8) + self.lolb;
            const n = if (self.lolb < 8) self.lolb else 9;
            return std.mem.asBytes(ss_ptr)[0..n];
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

    inline fn _hash(key: [9]u8) HashType {
        const value = std.mem.readIntNative(HashType, key[0..8]);
        return value *% 0x517cc1b727220a95;
    }

    pub fn put(self: *Self, key: [9]u8, len: usize, syll: Syllable.UniqueId) void {
        std.debug.assert(len <= 9);

        var it: Entry = .{ .hash = _hash(key), .syll = syll };
        var i = @intCast(usize, it.hash >> shift);
        while (self.entries[i].hash <= it.hash) : (i += 1) {}

        // key lần đầu xuất hiện, ghi lại offset
        it.lolb = if (len < 9) @intCast(u8, len) else key[8];

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

    pub fn get(self: Self, key: [9]u8, len: usize) ?*Entry {
        if (len > 9) return null;

        const hash = _hash(key);
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
};

pub fn main() !void {
    var token2syll: TokenToSyll = undefined;
    defer token2syll.deinit();
    try token2syll.init(std.heap.page_allocator);

    var syll: Syllable.UniqueId = 0;
    var buffer: [9]u8 = undefined;
    const buf = buffer[0..];

    while (syll < Syllable.MAXX_ID) : (syll += 1) {
        const token = Syllable.newFromId(syll).printBuffUtf8(buf);
        if (token.len > 8) {
            std.debug.print("{d}:{s} ", .{ token.len, token });
        }
        token2syll.put(buffer, token.len, syll);
    }

    syll = 0;
    var ss: u72 = undefined;

    while (syll < Syllable.MAXX_ID) : (syll += 1) {
        const token = Syllable.newFromId(syll).printBuffUtf8(buf);
        const entry = token2syll.get(buffer, token.len);
        if (entry != null and entry.?.syll != syll) {
            std.debug.print("{s} {d} {s}; ", .{ token, syll, entry.?.keyStr(&ss) });
            // unreachable;
        }
    }
}
