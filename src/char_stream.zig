// - tìm vị trí space

const std = @import("std");

pub fn main() !void {
    var file = try std.fs.cwd().openFile("utf8tv.txt", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [1028]u8 = undefined;
    const len = try in_stream.read(&buf);
    std.debug.print("{d}\n{s}", .{ len, buf });
}
