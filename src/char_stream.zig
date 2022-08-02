// - tìm vị trí space

const std = @import("std");

pub fn main() !void {
    var file = try std.fs.cwd().openFile("utf8tv.txt", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [32]u8 = undefined;
    var len = try in_stream.read(&buf);

    while (len > 0) {
        std.debug.print("{s}\n", .{buf[0..len]});
        len = try in_stream.read(&buf);
    }
}
