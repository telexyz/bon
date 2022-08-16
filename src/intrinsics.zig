pub extern fn __pext_u32(x: u32, y: u32) u32;
pub inline fn pext_u32(x: u32, y: u32) u32 {
    return __pext_u32(x, y);
}

const std = @import("std");
test "pext" {
    const x: u32 = 0b00100011_00000000_00000000_10000001;
    const y: u32 = 0b10101010_10101010_10101010_10101011;
    try std.testing.expectEqual(pext_u32(x, y), 0b1010_0000_0001_0001);
}

pub fn main() void {
    const x: u32 = 0b00100011_00000000_00000000_10000001;
    const y: u32 = 0b00101010_10101010_10101010_10101011;
    //                               1010_0000_0001_0001
    std.debug.print("\npext: {b}\n", .{pext_u32(x, y)});
}
