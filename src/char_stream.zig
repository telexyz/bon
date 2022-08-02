// - tìm vị trí space

const std = @import("std");
const v = @import("vector_types.zig");
// const simd = @import("simd.zig");
const BYTES_PROCESSED = 32;

pub fn main() !void {
    var file = try std.fs.cwd().openFile("utf8tv.txt", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var l3c: [3]u8 = undefined;
    std.mem.set(u8, l3c[0..], 32);

    var buf: [BYTES_PROCESSED]u8 = undefined;
    var vec: v.u8x32 = undefined;
    var len = try in_stream.read(&buf);

    while (len > 0) {
        const str = buf[0..len];
        std.debug.print("{s}{s}\n", .{ l3c[0..], str });

        vec = buf;
        const sp_comp = vec == @splat(BYTES_PROCESSED, @as(u8, ' '));
        const sp_bits = @ptrCast(*const u32, &sp_comp).*;
        const sp_1st_idx = @ctz(u32, sp_bits);
        std.debug.print("{b:0>31}\n{d}\n", .{ sp_bits, sp_1st_idx });

        l3c = buf[BYTES_PROCESSED - 3 .. BYTES_PROCESSED].*;
        len = try in_stream.read(&buf);
    }
}
