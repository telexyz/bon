// Xem phân tích ký tự utf8 tiếng Việt tại `docs/utf8tv.md`

const std = @import("std");
const sds = @import("syllable.zig"); // sds: Syllable Data Structures
const cmn = @import("common.zig");

const u8x6 = std.meta.Vector(6, u8);
const lookup = u8x6{ 'e', 'y', 'u', 'i', 'o', 'a' };

inline fn isAsciiVowel(b: u8) bool {
    const input = u8x6{ b, b, b, b, b, b };
    const match = @ptrCast(*const u6, &(input == lookup)).*;
    return match > 0;
}

const lookup_tables = @import("lookup_tables.zig");

pub const Char = struct {
    byte0: u8 = undefined,
    byte1: u8 = undefined,
    upper: bool = undefined,
    vowel: bool = undefined,
    tone: sds.Tone = undefined,
    len: usize = undefined,

    inline fn setb1b0t(self: *Char, b1: u8, b0: u8, t: sds.Tone) void {
        self.byte1 = b1;
        self.byte0 = b0;
        self.tone = t;
    }

    inline fn setb1b0tUp(self: *Char, b1: u8, b0: u8, t: sds.Tone, up: bool) void {
        self.byte1 = b1;
        self.byte0 = b0;
        self.tone = t;
        self.upper = up;
    }

    inline fn setInvalid(self: *Char) void {
        self.byte0 = 0;
    }

    inline fn isInvalid(self: Char) bool {
        return self.byte0 == 0 or self.isEndOfStr();
    }

    inline fn setEndOfStr(self: *Char) void {
        self.byte0 = 255;
    }

    inline fn isEndOfStr(self: Char) bool {
        return self.byte0 == 255;
    }

    pub inline fn parse(self: *Char, bytes: []const u8, idx: usize) void {
        // std.debug.assert(idx < bytes.len);
        if (idx >= bytes.len) {
            if (cmn.DEBUGGING) std.debug.print("\n\n>> {s} <<\n", .{bytes});
            self.setEndOfStr();
            return;
        }

        const curr_byte = bytes[idx];

        if (cmn.DEBUGGING) cmn.showChatAt(bytes, idx);

        self.vowel = true;
        self.len = 0;
        self.setInvalid();

        switch (curr_byte) {
            // 1-byte chars
            'A'...'Z', 'a'...'z' => {
                //           a: 01100001
                //           A: 01000001
                self.upper = (0b00100000 & curr_byte) == 0;
                self.byte0 = (0b00100000 | curr_byte); // toLower
                self.byte1 = 0;
                self.len = 1;
                self.tone = ._none;
                self.vowel = isAsciiVowel(self.byte0);
            },

            // 2-byte chars A/
            195 => {
                var next_byte = bytes[idx + 1];
                //           ê: 10101010
                //           Ê: 10001010
                self.upper = (0b00100000 & next_byte) == 0;
                next_byte |= (0b00100000); // toLower
                self.len = 2;

                // LOOKUP TABLE TO AVOID BRANCHING
                const result = lookup_tables.utf8tv_A[next_byte];
                if (result != 0) {
                    const b0 = @intCast(u8, result >> 8);
                    const tone = @intToEnum(sds.Tone, result & 0x00ff);
                    self.setb1b0t(0, b0, tone);
                } else {
                    self.setb1b0t(curr_byte, next_byte, ._none);
                }
            },

            // 2-byte chars B/
            196...198 => {
                var next_byte = bytes[idx + 1];
                self.len = 2;

                switch (next_byte) {
                    175 => self.setb1b0tUp(curr_byte, 176, ._none, true), //  'Ư'198:175
                    176 => self.setb1b0tUp(curr_byte, 176, ._none, false), // 'ư'198:176
                    else => {
                        self.upper = (0b1 & next_byte) == 0;
                        next_byte |= (0b1); // toLower
                        if (next_byte == 169) // 'ĩ'196:169 'ũ'197:169
                            self.setb1b0t(0, if (curr_byte == 196) 'i' else 'u', .x)
                        else { // 'ă'196:131 'đ'196:145 'ơ'198:161
                            self.setb1b0t(curr_byte, next_byte, ._none);
                            self.vowel = !(next_byte == 145); // not 'đ'196:145
                        }
                    },
                }
            },

            // TODO: Handle unicode tổ hợp
            204 => {
                const next_byte = bytes[idx + 1];
                switch (next_byte) {
                    137 => { // ̉ 204:137
                        self.byte0 = 0;
                        self.tone = .r;
                    },
                    else => {},
                }
            },

            // 3-byte chars C/ + D/
            225 => {
                var next_byte = bytes[idx + 2];
                self.upper = (0b1 & next_byte) == 0;
                next_byte |= (0b1); // toLower
                self.len = 3;

                switch (bytes[idx + 1]) {
                    // 3-byte chars C/
                    186 => {
                        // LOOKUP TABLE TO AVOID BRANCHING
                        const result = lookup_tables.utf8tv_C[next_byte];
                        const b1 = @intCast(u8, result >> 16);
                        const b0 = @intCast(u8, (result & 0x00FF00) >> 8);
                        const tone = @intToEnum(sds.Tone, result & 0x0000FF);
                        self.setb1b0t(b1, b0, tone);
                    },

                    // 3-byte chars D/
                    187 => {
                        // LOOKUP TABLE TO AVOID BRANCHING
                        const result = lookup_tables.utf8tv_D[next_byte];
                        const b1 = @intCast(u8, result >> 16);
                        const b0 = @intCast(u8, (result & 0x00FF00) >> 8);
                        const tone = @intToEnum(sds.Tone, result & 0x0000FF);
                        self.setb1b0t(b1, b0, tone);
                    },
                    else => {},
                }
            }, // switch (curr_byte)
            else => if (curr_byte < 128) {
                self.len = 1; // 1-byte chars
                self.vowel = false;
                self.setb1b0t(0, curr_byte, ._none);
            },
        }

        if (cmn.DEBUGGING) cmn.showChar(self);
    }
};

//
const expectEqual = std.testing.expectEqual;
fn charEqual(char: *Char, byte1: u8, byte0: u8, tone: sds.Tone, len: usize, upper: bool, vowel: bool) !void {
    // if (byte1 == 195) std.debug.print("{}", .{char}); // DEBUG
    try expectEqual(char.byte1, byte1);
    try expectEqual(char.byte0, byte0);
    try expectEqual(char.tone, tone);
    try expectEqual(char.len, len);
    try expectEqual(char.upper, upper);
    try expectEqual(char.vowel, vowel);
}

fn _parse(char: *Char, bytes: []const u8) *Char {
    char.parse(bytes, 0);
    return char;
}

test "char.parse(invalid)" {
    var char: Char = undefined;
    var str = [_]u8{ 225, 225, 225 };
    try std.testing.expect(_parse(&char, &str).isInvalid());
}

test "char.parse(ascii)" {
    var char: Char = undefined;
    var i: u8 = 0;
    var str: [1]u8 = undefined;
    while (i < 128) : (i += 1) {
        str[0] = i;
        // std.debug.print("\n>> char.parse(ascii): {s}-{d}\n", .{ str, i });
        const upper = (i >= 'A' and i <= 'Z');
        if (upper) i += 32; // A-Z => a-z

        var vowel: bool = switch (i) {
            'e', 'y', 'u', 'i', 'o', 'a' => true,
            else => false,
        };

        try charEqual(_parse(&char, &str), 0, i, ._none, 1, upper, vowel);
    }
}

test "char.parse(A/)" {
    var char: Char = undefined;
    try charEqual(_parse(&char, "à"), 0, 'a', .f, 2, false, true);
    try charEqual(_parse(&char, "á"), 0, 'a', .s, 2, false, true);
    try charEqual(_parse(&char, "â"), "â"[0], "â"[1], ._none, 2, false, true);
    try charEqual(_parse(&char, "ã"), 0, 'a', .x, 2, false, true);
    try charEqual(_parse(&char, "è"), 0, 'e', .f, 2, false, true);
    try charEqual(_parse(&char, "é"), 0, 'e', .s, 2, false, true);
    try charEqual(_parse(&char, "ê"), "ê"[0], "ê"[1], ._none, 2, false, true);
    try charEqual(_parse(&char, "ì"), 0, 'i', .f, 2, false, true);
    try charEqual(_parse(&char, "í"), 0, 'i', .s, 2, false, true);
    try charEqual(_parse(&char, "ò"), 0, 'o', .f, 2, false, true);
    try charEqual(_parse(&char, "ó"), 0, 'o', .s, 2, false, true);
    try charEqual(_parse(&char, "ô"), "ô"[0], "ô"[1], ._none, 2, false, true);
    try charEqual(_parse(&char, "õ"), 0, 'o', .x, 2, false, true);
    try charEqual(_parse(&char, "ù"), 0, 'u', .f, 2, false, true);
    try charEqual(_parse(&char, "ú"), 0, 'u', .s, 2, false, true);
    try charEqual(_parse(&char, "ý"), 0, 'y', .s, 2, false, true);

    try charEqual(_parse(&char, "À"), 0, 'a', .f, 2, true, true);
    try charEqual(_parse(&char, "Á"), 0, 'a', .s, 2, true, true);
    try charEqual(_parse(&char, "Â"), "â"[0], "â"[1], ._none, 2, true, true);
    try charEqual(_parse(&char, "Ã"), 0, 'a', .x, 2, true, true);
    try charEqual(_parse(&char, "È"), 0, 'e', .f, 2, true, true);
    try charEqual(_parse(&char, "É"), 0, 'e', .s, 2, true, true);
    try charEqual(_parse(&char, "Ê"), "ê"[0], "ê"[1], ._none, 2, true, true);
    try charEqual(_parse(&char, "Ì"), 0, 'i', .f, 2, true, true);
    try charEqual(_parse(&char, "Í"), 0, 'i', .s, 2, true, true);
    try charEqual(_parse(&char, "Ò"), 0, 'o', .f, 2, true, true);
    try charEqual(_parse(&char, "Ó"), 0, 'o', .s, 2, true, true);
    try charEqual(_parse(&char, "Ô"), "ô"[0], "ô"[1], ._none, 2, true, true);
    try charEqual(_parse(&char, "Õ"), 0, 'o', .x, 2, true, true);
    try charEqual(_parse(&char, "Ù"), 0, 'u', .f, 2, true, true);
    try charEqual(_parse(&char, "Ú"), 0, 'u', .s, 2, true, true);
    try charEqual(_parse(&char, "Ý"), 0, 'y', .s, 2, true, true);
}

test "char.parse(B/)" {
    var char: Char = undefined;
    try charEqual(_parse(&char, "ă"), "ă"[0], "ă"[1], ._none, 2, false, true);
    try charEqual(_parse(&char, "đ"), "đ"[0], "đ"[1], ._none, 2, false, false);
    try charEqual(_parse(&char, "ĩ"), 0, 'i', .x, 2, false, true);
    try charEqual(_parse(&char, "ũ"), 0, 'u', .x, 2, false, true);
    try charEqual(_parse(&char, "ơ"), "ơ"[0], "ơ"[1], ._none, 2, false, true);
    try charEqual(_parse(&char, "ư"), "ư"[0], "ư"[1], ._none, 2, false, true);

    try charEqual(_parse(&char, "Ă"), "ă"[0], "ă"[1], ._none, 2, true, true);
    try charEqual(_parse(&char, "Đ"), "đ"[0], "đ"[1], ._none, 2, true, false);
    try charEqual(_parse(&char, "Ĩ"), 0, 'i', .x, 2, true, true);
    try charEqual(_parse(&char, "Ũ"), 0, 'u', .x, 2, true, true);
    try charEqual(_parse(&char, "Ơ"), "ơ"[0], "ơ"[1], ._none, 2, true, true);
    try charEqual(_parse(&char, "Ư"), "ư"[0], "ư"[1], ._none, 2, true, true);
}

test "char.parse(C/)" {
    var char: Char = undefined;
    try charEqual(_parse(&char, "ạ"), 0, 'a', .j, 3, false, true);
    try charEqual(_parse(&char, "ả"), 0, 'a', .r, 3, false, true);
    try charEqual(_parse(&char, "ấ"), "â"[0], "â"[1], .s, 3, false, true);
    try charEqual(_parse(&char, "ầ"), "â"[0], "â"[1], .f, 3, false, true);
    try charEqual(_parse(&char, "ẩ"), "â"[0], "â"[1], .r, 3, false, true);
    try charEqual(_parse(&char, "ẫ"), "â"[0], "â"[1], .x, 3, false, true);
    try charEqual(_parse(&char, "ậ"), "â"[0], "â"[1], .j, 3, false, true);
    try charEqual(_parse(&char, "ắ"), "ă"[0], "ă"[1], .s, 3, false, true);
    try charEqual(_parse(&char, "ằ"), "ă"[0], "ă"[1], .f, 3, false, true);
    try charEqual(_parse(&char, "ẳ"), "ă"[0], "ă"[1], .r, 3, false, true);
    try charEqual(_parse(&char, "ẵ"), "ă"[0], "ă"[1], .x, 3, false, true);
    try charEqual(_parse(&char, "ặ"), "ă"[0], "ă"[1], .j, 3, false, true);
    try charEqual(_parse(&char, "ẹ"), 0, 'e', .j, 3, false, true);
    try charEqual(_parse(&char, "ẻ"), 0, 'e', .r, 3, false, true);
    try charEqual(_parse(&char, "ẽ"), 0, 'e', .x, 3, false, true);
    try charEqual(_parse(&char, "ế"), "ê"[0], "ê"[1], .s, 3, false, true);

    try charEqual(_parse(&char, "Ạ"), 0, 'a', .j, 3, true, true);
    try charEqual(_parse(&char, "Ả"), 0, 'a', .r, 3, true, true);
    try charEqual(_parse(&char, "Ấ"), "â"[0], "â"[1], .s, 3, true, true);
    try charEqual(_parse(&char, "Ầ"), "â"[0], "â"[1], .f, 3, true, true);
    try charEqual(_parse(&char, "Ẩ"), "â"[0], "â"[1], .r, 3, true, true);
    try charEqual(_parse(&char, "Ẫ"), "â"[0], "â"[1], .x, 3, true, true);
    try charEqual(_parse(&char, "Ậ"), "â"[0], "â"[1], .j, 3, true, true);
    try charEqual(_parse(&char, "Ắ"), "ă"[0], "ă"[1], .s, 3, true, true);
    try charEqual(_parse(&char, "Ằ"), "ă"[0], "ă"[1], .f, 3, true, true);
    try charEqual(_parse(&char, "Ẳ"), "ă"[0], "ă"[1], .r, 3, true, true);
    try charEqual(_parse(&char, "Ẵ"), "ă"[0], "ă"[1], .x, 3, true, true);
    try charEqual(_parse(&char, "Ặ"), "ă"[0], "ă"[1], .j, 3, true, true);
    try charEqual(_parse(&char, "Ẹ"), 0, 'e', .j, 3, true, true);
    try charEqual(_parse(&char, "Ẻ"), 0, 'e', .r, 3, true, true);
    try charEqual(_parse(&char, "Ẽ"), 0, 'e', .x, 3, true, true);
    try charEqual(_parse(&char, "Ế"), "ê"[0], "ê"[1], .s, 3, true, true);
}

test "char.parse(D/)" {
    var char: Char = undefined;
    try charEqual(_parse(&char, "ề"), "ê"[0], "ê"[1], .f, 3, false, true);
    try charEqual(_parse(&char, "ể"), "ê"[0], "ê"[1], .r, 3, false, true);
    try charEqual(_parse(&char, "ễ"), "ê"[0], "ê"[1], .x, 3, false, true);
    try charEqual(_parse(&char, "ệ"), "ê"[0], "ê"[1], .j, 3, false, true);
    try charEqual(_parse(&char, "ỉ"), 0, 'i', .r, 3, false, true);
    try charEqual(_parse(&char, "ị"), 0, 'i', .j, 3, false, true);
    try charEqual(_parse(&char, "ọ"), 0, 'o', .j, 3, false, true);
    try charEqual(_parse(&char, "ỏ"), 0, 'o', .r, 3, false, true);
    try charEqual(_parse(&char, "ố"), "ô"[0], "ô"[1], .s, 3, false, true);
    try charEqual(_parse(&char, "ồ"), "ô"[0], "ô"[1], .f, 3, false, true);
    try charEqual(_parse(&char, "ổ"), "ô"[0], "ô"[1], .r, 3, false, true);
    try charEqual(_parse(&char, "ỗ"), "ô"[0], "ô"[1], .x, 3, false, true);
    try charEqual(_parse(&char, "ộ"), "ô"[0], "ô"[1], .j, 3, false, true);
    try charEqual(_parse(&char, "ớ"), "ơ"[0], "ơ"[1], .s, 3, false, true);
    try charEqual(_parse(&char, "ờ"), "ơ"[0], "ơ"[1], .f, 3, false, true);
    try charEqual(_parse(&char, "ở"), "ơ"[0], "ơ"[1], .r, 3, false, true);
    try charEqual(_parse(&char, "ỡ"), "ơ"[0], "ơ"[1], .x, 3, false, true);
    try charEqual(_parse(&char, "ợ"), "ơ"[0], "ơ"[1], .j, 3, false, true);
    try charEqual(_parse(&char, "ụ"), 0, 'u', .j, 3, false, true);
    try charEqual(_parse(&char, "ủ"), 0, 'u', .r, 3, false, true);
    try charEqual(_parse(&char, "ứ"), "ư"[0], "ư"[1], .s, 3, false, true);
    try charEqual(_parse(&char, "ừ"), "ư"[0], "ư"[1], .f, 3, false, true);
    try charEqual(_parse(&char, "ử"), "ư"[0], "ư"[1], .r, 3, false, true);
    try charEqual(_parse(&char, "ữ"), "ư"[0], "ư"[1], .x, 3, false, true);
    try charEqual(_parse(&char, "ự"), "ư"[0], "ư"[1], .j, 3, false, true);
    try charEqual(_parse(&char, "ỳ"), 0, 'y', .f, 3, false, true);
    try charEqual(_parse(&char, "ỵ"), 0, 'y', .j, 3, false, true);
    try charEqual(_parse(&char, "ỷ"), 0, 'y', .r, 3, false, true);
    try charEqual(_parse(&char, "ỹ"), 0, 'y', .x, 3, false, true);

    try charEqual(_parse(&char, "Ề"), "ê"[0], "ê"[1], .f, 3, true, true);
    try charEqual(_parse(&char, "Ể"), "ê"[0], "ê"[1], .r, 3, true, true);
    try charEqual(_parse(&char, "Ễ"), "ê"[0], "ê"[1], .x, 3, true, true);
    try charEqual(_parse(&char, "Ệ"), "ê"[0], "ê"[1], .j, 3, true, true);
    try charEqual(_parse(&char, "Ỉ"), 0, 'i', .r, 3, true, true);
    try charEqual(_parse(&char, "Ị"), 0, 'i', .j, 3, true, true);
    try charEqual(_parse(&char, "Ọ"), 0, 'o', .j, 3, true, true);
    try charEqual(_parse(&char, "Ỏ"), 0, 'o', .r, 3, true, true);
    try charEqual(_parse(&char, "Ố"), "ô"[0], "ô"[1], .s, 3, true, true);
    try charEqual(_parse(&char, "Ồ"), "ô"[0], "ô"[1], .f, 3, true, true);
    try charEqual(_parse(&char, "Ổ"), "ô"[0], "ô"[1], .r, 3, true, true);
    try charEqual(_parse(&char, "Ỗ"), "ô"[0], "ô"[1], .x, 3, true, true);
    try charEqual(_parse(&char, "Ộ"), "ô"[0], "ô"[1], .j, 3, true, true);
    try charEqual(_parse(&char, "Ớ"), "ơ"[0], "ơ"[1], .s, 3, true, true);
    try charEqual(_parse(&char, "Ờ"), "ơ"[0], "ơ"[1], .f, 3, true, true);
    try charEqual(_parse(&char, "Ở"), "ơ"[0], "ơ"[1], .r, 3, true, true);
    try charEqual(_parse(&char, "Ỡ"), "ơ"[0], "ơ"[1], .x, 3, true, true);
    try charEqual(_parse(&char, "Ợ"), "ơ"[0], "ơ"[1], .j, 3, true, true);
    try charEqual(_parse(&char, "Ụ"), 0, 'u', .j, 3, true, true);
    try charEqual(_parse(&char, "Ủ"), 0, 'u', .r, 3, true, true);
    try charEqual(_parse(&char, "Ứ"), "ư"[0], "ư"[1], .s, 3, true, true);
    try charEqual(_parse(&char, "Ừ"), "ư"[0], "ư"[1], .f, 3, true, true);
    try charEqual(_parse(&char, "Ử"), "ư"[0], "ư"[1], .r, 3, true, true);
    try charEqual(_parse(&char, "Ữ"), "ư"[0], "ư"[1], .x, 3, true, true);
    try charEqual(_parse(&char, "Ự"), "ư"[0], "ư"[1], .j, 3, true, true);
    try charEqual(_parse(&char, "Ỳ"), 0, 'y', .f, 3, true, true);
    try charEqual(_parse(&char, "Ỵ"), 0, 'y', .j, 3, true, true);
    try charEqual(_parse(&char, "Ỷ"), 0, 'y', .r, 3, true, true);
    try charEqual(_parse(&char, "Ỹ"), 0, 'y', .x, 3, true, true);
}

test "Unicode tổ hợp" {
    // "́ hệ của cái gia đình này và chắc chắn ră�"
    var char: Char = undefined;
    _ = char.parse("ủ", 1);
}
