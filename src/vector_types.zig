const std = @import("std");

pub const boolx32 = std.meta.Vector(32, bool);
pub const boolx16 = std.meta.Vector(16, bool);
pub const boolx8 = std.meta.Vector(8, bool);
pub const boolx4 = std.meta.Vector(4, bool);
pub const i1x32 = std.meta.Vector(32, i1);
pub const i8x8 = std.meta.Vector(8, i8);
pub const i8x16 = std.meta.Vector(16, i8);
pub const i8x32 = std.meta.Vector(32, i8);
pub const i16x4 = std.meta.Vector(4, i16);
pub const i16x8 = std.meta.Vector(8, i16);
pub const i32x2 = std.meta.Vector(2, i32);
pub const i32x4 = std.meta.Vector(4, i32);
pub const i32x8 = std.meta.Vector(8, i32);
pub const u1x4 = std.meta.Vector(4, u1);
pub const u1x8 = std.meta.Vector(8, u1);
pub const u1x16 = std.meta.Vector(16, u1);
pub const u1x32 = std.meta.Vector(32, u1);
pub const u8x8 = std.meta.Vector(8, u8);
pub const u8x16 = std.meta.Vector(16, u8);
pub const u8x32 = std.meta.Vector(32, u8);
pub const u8x64 = std.meta.Vector(64, u8);
pub const u16x8 = std.meta.Vector(8, u16);
pub const u32x4 = std.meta.Vector(4, u32);
pub const i64x2 = std.meta.Vector(2, i64);
pub const u64x2 = std.meta.Vector(2, u64);
