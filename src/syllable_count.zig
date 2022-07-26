const std = @import("std");
const Syllable = @import("syllable.zig").Syllable; // syllable data structures

pub const CountType = u24;
pub const KeyType = Syllable.UniqueId;
pub const MAXX_KEY = Syllable.MAXX_ID; // value always < maxx (maxx = max + 1)

pub const SyllableCount = struct {
    allocator: std.mem.Allocator = undefined,
    counts: []CountType = undefined,
    freed: bool = false,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        if (!self.freed) {
            self.allocator.free(self.counts);
            self.freed = true;
        }
    }

    pub fn init(self: *Self, init_allocator: std.mem.Allocator) !void {
        self.allocator = init_allocator;
        self.counts = try self.allocator.alloc(CountType, MAXX_KEY);
        std.mem.set(CountType, self.counts, 0);
        self.freed = false;
    }

    pub fn put(self: *Self, key: KeyType) void {
        std.debug.assert(key < MAXX_KEY);
        self.counts[key] += 1;
    }

    pub fn get(self: *Self, key: KeyType) CountType {
        std.debug.assert(key < MAXX_KEY);
        return self.counts[key];
    }

    pub fn keyStr(key: KeyType, buf: []u8) []const u8 {
        var syll = Syllable.newFromId(key);
        return syll.printBuffUtf8(buf);
    }

    pub fn list(self: *Self, max: usize) void {
        var i: KeyType = 0;
        var n: usize = 0;
        var buffer: [12]u8 = undefined;

        std.debug.print("\n(( List {d} syllable counts ))\n", .{max});
        while (i < MAXX_KEY) : (i += 1) {
            const count = self.counts[i];
            if (count > 0) {
                n += 1;
                if (n > max) break;

                std.debug.print("\ncount[{s}]: {d}", .{
                    SyllableCount.keyStr(i, buffer[0..]),
                    count,
                });
            }
        }
    }
};

test "SyllableCount" {
    var sc: SyllableCount = undefined;
    try sc.init(std.testing.allocator);
    defer sc.deinit();

    var syll = Syllable{ .normalized = true, .am_dau = .ng, .am_giua = .uoz, .am_cuoi = .m, .tone = .s, .can_be_vietnamese = true };
    var key = syll.toId();

    try std.testing.expectEqual(sc.get(key), 0);
    sc.put(key);
    try std.testing.expectEqual(sc.get(key), 1);

    var buffer: [12]u8 = undefined;
    const token = SyllableCount.keyStr(key, buffer[0..]);
    try std.testing.expectEqualStrings(token, "nguốm");
}
