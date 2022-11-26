const std = @import("std");
const AmGiua = @import("syllable.zig").AmGiua;
const cmn = @import("common.zig");

// 23 âm giữa (âm đệm + nguyên âm)

const u16x16 = std.meta.Vector(16, u16);
const lookup16 = u16x16{
    'a',
    'e',
    'i',
    'o',
    'u',
    'y',
    (@as(u16, 195) << 8) + 162, // 'â'195:162
    (@as(u16, 196) << 8) + 131, // 'ă'196:131
    (@as(u16, 195) << 8) + 170, // 'ê'195:170
    (@as(u16, 195) << 8) + 180, // 'ô'195:180
    (@as(u16, 198) << 8) + 161, // 'ơ'198:161
    (@as(u16, 198) << 8) + 176, // 'ư'198:176
    (@as(u16, 'o') << 8) + 'a',
    (@as(u16, 'o') << 8) + 'e',
    (@as(u16, 'o') << 8) + 'o',
    (@as(u16, 'u') << 8) + 'y',
};
const middle16: []const AmGiua = &.{
    AmGiua.a, //     01: a
    AmGiua.e, //     02: e
    AmGiua.i, //     03: i
    AmGiua.o, //     04: o
    AmGiua.u, //     05: u
    AmGiua.y, //     06: y
    AmGiua.az, //    07: â
    AmGiua.aw, //    08: ă
    AmGiua.ez, //    09: ê
    AmGiua.oz, //    10: ô
    AmGiua.ow, //    11: ơ
    AmGiua.uw, //    12: ư
    AmGiua.oa, //    13: oa
    AmGiua.oe, //    14: oe
    AmGiua.oo, //    15: boong
    AmGiua.uy, //    16: uy
    AmGiua._none, // 17: none
};

const vec32 = std.meta.Vector(16, u32);
const bitmap32 = u16;
const lookup32 = vec32{
    (@as(u32, 'i') << 16) + (@as(u32, 195) << 8) + 170, // i'ê'195:170
    (@as(u32, 'o') << 16) + (@as(u32, 196) << 8) + 131, // o'ă'196:131
    (@as(u32, 'u') << 16) + (@as(u32, 195) << 8) + 162, // u'â'195:162
    (@as(u32, 'u') << 16) + (@as(u32, 195) << 8) + 170, // u'ê'195:170
    (@as(u32, 'u') << 16) + (@as(u32, 195) << 8) + 180, // u'ô'195:180
    (@as(u32, 'u') << 16) + (@as(u32, 198) << 8) + 161, // 'u'ơ'198:161
    (@as(u32, 198) << 24) + (@as(u32, 176) << 16) + (@as(u32, 198) << 8) + 161, // 'ư'198:176'ơ'
    (@as(u32, 'u') << 24) + (@as(u32, 'y') << 16) + (@as(u32, 195) << 8) + 170, // uy'ê'195:170
    (@as(u32, 'u') << 24) + (@as(u32, 'y') << 16) + 'a', // uya => uyê
    (@as(u32, 'i') << 16) + 'a', //                         ia  => iê
    (@as(u32, 198) << 24) + (176 << 16) + 'a', //           ưa  => ươ (ư'198:176)
    (@as(u32, 'u') << 16) + (@as(u32, 196) << 8) + 131, //  uă => `oă' với quắt => coắt
    (@as(u32, 'u') << 16) + 'o', //                         uo

    // TRẠNG THÁI CHUYỂN TIẾP
    (@as(u32, 'u') << 16) + 'a', //                         ua
    (@as(u32, 'u') << 16) + 'e', //                         ue
    (@as(u32, 'u') << 16) + 'i', //                         ui
};
const middle32: []const AmGiua = &.{
    AmGiua.iez, //  0: iê
    AmGiua.oaw, //  1: oă (loắt choắt)
    AmGiua.uaz, //  2: uâ (tuân)
    AmGiua.uez, //  3: uê (tuềnh toàng)
    AmGiua.uoz, //  4: uô
    AmGiua.u_ow, // 5: huơ tay, thuở xưa
    AmGiua.uow, //  6: ươ
    AmGiua.uyez, // 7: uyê
    AmGiua.uyez, // 8: uya => uyê
    AmGiua.iez, //     ia  => iê
    AmGiua.uow, //     ưa  => ươ (ư'198:176)
    AmGiua.oaw, //     uă  => oă (quắt => coắt)
    AmGiua.uo, //      uo  <= quọ

    // TRẠNG THÁI CHUYỂN TIẾP
    AmGiua.ua, // => `oa` với qua => coa, `uoz` với hua
    AmGiua.ue, // => `oe` với que => coe, `uez` với tue
    AmGiua.ui, // => `uy` với qui => cuy
    //
    AmGiua._none,
};

// “UƠ” HAY “UA”
// http://repository.ulis.vnu.edu.vn/handle/ULIS_123456789/164
// “ua” và “uơ” đều có âm trị là [uo]. [uo] còn có cách viết là “uô” khi có âm cuối.

pub inline fn getSingleMiddle(c0b0: u8, c0b1: u8) AmGiua {
    const b = (@intCast(u16, c0b1) << 8) + c0b0;
    const input16 = u16x16{ b, b, b, b, b, b, b, b, b, b, b, b, b, b, b, b };
    const match16 = @ptrCast(*const u16, &(input16 == lookup16)).*;
    const pos16 = if (match16 > 0) @ctz(match16) else 16;

    if (cmn.DEBUGGING) {
        const c0: []const u8 = &.{ c0b1, c0b0 };
        std.debug.print("\n\n>> getSingleMiddle: '{s}'{x}:{x}", .{ c0, c0b1, c0b0 });
    }

    return middle16[pos16];
}

pub inline fn getMiddle(c0b0: u8, c0b1: u8, c1b0: u8, c1b1: u8) AmGiua {
    const a = (@intCast(u32, c0b1) << 24) + (@intCast(u32, c0b0) << 16) +
        (@intCast(u32, c1b1) << 8) + c1b0;
    const input32 = vec32{ a, a, a, a, a, a, a, a, a, a, a, a, a, a, a, a };
    const match32 = @ptrCast(*const bitmap32, &(input32 == lookup32)).*;

    if (cmn.DEBUGGING) {
        const char0: []const u8 = &.{ c0b1, c0b0 };
        const char1: []const u8 = &.{ c1b1, c1b0 };
        std.debug.print(
            "\n\n>> getMiddle: '{s}'{x}:{x} '{s}'{x}:{x}",
            .{ char0, c0b1, c0b0, char1, c1b1, c1b0 },
        );
    }

    if (match32 > 0) {
        // if (cmn.DEBUGGING) {
        //     std.debug.print("\n{x:0>8}\n{x:0>8}", .{ input32, lookup32 });
        //     std.debug.print("\n{b:0>8} {d}\n", .{ match32, @ctz(match32) });
        // }
        return middle32[@ctz(match32)];
    } else {
        return getSingleMiddle(c0b0, c0b1);
    }
}
