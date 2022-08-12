const std = @import("std");
const Syllable = @import("syllable.zig").Syllable; // syllable data structures

pub const CountType = u24;
pub const KeyType = Syllable.UniqueId;
pub const MAXX_KEY = Syllable.MAXX_ID; // maxx: value < maxx (maxx = max + 1)

const SyllableCount = struct {
    allocator: std.mem.Allocator = undefined,
    counts: []CountType,

    const Self = @This();

    pub fn init(self: *Self, init_allocator: std.mem.Allocator) !void {
        self.allocator = init_allocator;
        self.counts = try self.allocator.alloc(CountType, MAXX_KEY);
        std.mem.set(CountType, self.counts, 0);
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.counts);
    }

    pub fn put(self: *Self, key: KeyType) void {
        std.debug.assert(key < MAXX_KEY);
        self.counts[key] += 1;
    }

    pub fn get(self: *Self, key: KeyType) CountType {
        std.debug.assert(key < MAXX_KEY);
        return self.counts[key];
    }

    pub fn key_str(key: KeyType, buf: []u8) []const u8 {
        return Syllable.newFromId(key).printBuffUtf8(buf);
    }
};

test "SyllableCount" {
    var sc: SyllableCount = undefined;
    try sc.init(std.heap.page_allocator);
    defer sc.deinit();

    var syll = Syllable{ .normalized = true, .am_dau = .ng, .am_giua = .uoz, .am_cuoi = .m, .tone = .s, .can_be_vietnamese = true };
    var key = syll.toId();

    try std.testing.expectEqual(sc.get(key), 0);
    sc.put(key);
    try std.testing.expectEqual(sc.get(key), 1);

    var buffer: [12]u8 = undefined;
    const token = SyllableCount.key_str(key, buffer[0..]);
    try std.testing.expectEqualStrings(token, "nguốm");
}
