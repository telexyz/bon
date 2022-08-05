// Xem phân tích ký tự utf8 tiếng Việt tại `docs/utf8tv.md`

const std = @import("std");
const sds = @import("syllable.zig"); // sds: Syllable Data Structures
const DEBUG = false;

pub const Char = struct {
    byte0: u8 = undefined,
    byte1: u8 = undefined,
    upper: bool = undefined,
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

    pub inline fn parse(self: *Char, bytes: []const u8, idx: usize) void {
        const curr_byte = bytes[idx];

        //  DEBUG
        if (DEBUG and (curr_byte < 128 or idx < bytes.len - 1)) {
            const next_byte = if (curr_byte < 128) 0 else bytes[idx + 1];
            var s = if (curr_byte < 128) [_]u8{ 32, curr_byte } else [_]u8{ curr_byte, next_byte };
            std.debug.print("\nbytes[{d}] = {s: >2} {d: >3}:{d: >3}", .{ idx, s, curr_byte, next_byte });
        }

        self.tone = ._none;
        self.len = 0;

        switch (curr_byte) {
            // 1-byte chars
            0...127 => {
                //              a: 01100001
                //              A: 01000001
                self.upper = ((0b00100000 & curr_byte)) == 0;
                self.byte0 = curr_byte | 0b00100000; // toLower
                self.byte1 = 0;
                self.len = 1;
            },

            // 2-byte chars A/
            195 => {
                var next_byte = bytes[idx + 1];
                //              ê: 10101010
                //              Ê: 10001010
                self.upper = ((0b00100000 & next_byte)) == 0;
                next_byte |= 0b00100000; // toLower
                self.len = 2;

                switch (next_byte) {
                    160 => self.setb1b0t(0, 'a', .f), // 'à'195:160
                    161 => self.setb1b0t(0, 'a', .s), // 'á'195:161
                    163 => self.setb1b0t(0, 'a', .x), // 'ã'195:163
                    168 => self.setb1b0t(0, 'e', .f), // 'è'195:168
                    169 => self.setb1b0t(0, 'e', .s), // 'é'195:169
                    172 => self.setb1b0t(0, 'i', .f), // 'ì'195:172
                    173 => self.setb1b0t(0, 'i', .s), // 'í'195:173
                    178 => self.setb1b0t(0, 'o', .f), // 'ò'195:178
                    179 => self.setb1b0t(0, 'o', .s), // 'ó'195:179
                    181 => self.setb1b0t(0, 'o', .x), // 'õ'195:181
                    185 => self.setb1b0t(0, 'u', .f), // 'ù'195:185
                    186 => self.setb1b0t(0, 'u', .s), // 'ú'195:186
                    189 => self.setb1b0t(0, 'y', .s), // 'ý'195:189
                    // còn lại giữ nguyên 'â'195:162 'ê'195:170 'ô'195:180
                    else => self.setb1b0t(next_byte, curr_byte, ._none),
                }
            },

            // 2-byte chars B/
            196...198 => {
                var next_byte = bytes[idx + 1];
                self.len = 2;

                switch (next_byte) {
                    175 => self.setb1b0tUp(curr_byte, 176, ._none, true),
                    176 => self.setb1b0tUp(curr_byte, 176, ._none, false),
                    else => {
                        self.upper = (next_byte & 0b1) == 0;
                        next_byte |= 0b1; // toLower
                        if (next_byte == 169) self.setb1b0t(0, if (curr_byte == 196) 'i' else 'u', .x) //
                        else self.setb1b0t(curr_byte, next_byte, ._none);
                    },
                }
            },

            // 3-byte chars C/ + D/
            225 => {
                var next_byte = bytes[idx + 2];
                self.upper = (next_byte & 0b1) == 0;
                next_byte |= 0b1; // toLower
                self.len = 3;

                switch (bytes[idx + 1]) {
                    // 3-byte chars C/
                    186 => switch (next_byte) {
                        161 => self.setb1b0t(0, 'a', .j), //   'ạ'225:186:161
                        163 => self.setb1b0t(0, 'a', .r), //   'ả'225:186:163

                        // 'â'195:162
                        165 => self.setb1b0t(195, 162, .s), // 'ấ'225:186:165
                        167 => self.setb1b0t(195, 162, .f), // 'ầ'225:186:167
                        169 => self.setb1b0t(195, 162, .r), // 'ẩ'225:186:169
                        171 => self.setb1b0t(195, 162, .x), // 'ẫ'225:186:171
                        173 => self.setb1b0t(195, 162, .j), // 'ậ'225:186:173

                        // 'ă'196:131
                        175 => self.setb1b0t(196, 131, .s), // 'ắ'225:186:175
                        177 => self.setb1b0t(196, 131, .f), // 'ằ'225:186:177
                        179 => self.setb1b0t(196, 131, .r), // 'ẳ'225:186:179
                        181 => self.setb1b0t(196, 131, .x), // 'ẵ'225:186:181
                        183 => self.setb1b0t(196, 131, .j), // 'ặ'225:186:183

                        185 => self.setb1b0t(0, 'e', .j), //   'ẹ'225:186:185
                        187 => self.setb1b0t(0, 'e', .r), //   'ẻ'225:186:187
                        189 => self.setb1b0t(0, 'e', .x), //   'ẽ'225:186:189

                        // 'ê'195:170
                        191 => self.setb1b0t(195, 170, .s), // 'ế'225:186:191
                        else => self.setb1b0t(0, 0, ._none),
                    },

                    // 3-byte chars D/
                    187 => switch (next_byte) {
                        // 'ê'195:170
                        129 => self.setb1b0t(195, 170, .f), // 'ề'225:187:129
                        131 => self.setb1b0t(195, 170, .r), // 'ể'225:187:131
                        133 => self.setb1b0t(195, 170, .x), // 'ễ'225:187:133
                        135 => self.setb1b0t(195, 170, .j), // 'ệ'225:187:135

                        137 => self.setb1b0t(0, 'i', .r), //   'ỉ'225:187:137
                        139 => self.setb1b0t(0, 'i', .j), //   'ị'225:187:139

                        141 => self.setb1b0t(0, 'o', .j), //   'ọ'225:187:141
                        143 => self.setb1b0t(0, 'o', .r), //   'ỏ'225:187:143

                        // 'ô'195:180
                        145 => self.setb1b0t(195, 180, .s), // 'ố'225:187:145
                        147 => self.setb1b0t(195, 180, .f), // 'ồ'225:187:147
                        149 => self.setb1b0t(195, 180, .r), // 'ổ'225:187:149
                        151 => self.setb1b0t(195, 180, .x), // 'ỗ'225:187:151
                        153 => self.setb1b0t(195, 180, .j), // 'ộ'225:187:153

                        // 'ơ'198:161
                        155 => self.setb1b0t(198, 161, .s), // 'ớ'225:187:155
                        157 => self.setb1b0t(198, 161, .f), // 'ờ'225:187:157
                        159 => self.setb1b0t(198, 161, .r), // 'ở'225:187:159

                        161 => self.setb1b0t(198, 161, .x), // 'ỡ'225:187:161
                        163 => self.setb1b0t(198, 161, .j), // 'ợ'225:187:163

                        165 => self.setb1b0t(0, 'u', .j), //   'ụ'225:187:165
                        167 => self.setb1b0t(0, 'u', .r), //   'ủ'225:187:167

                        // 'ư'198:176
                        169 => self.setb1b0t(198, 176, .s), // 'ứ'225:187:169
                        171 => self.setb1b0t(198, 176, .f), // 'ừ'225:187:171
                        173 => self.setb1b0t(198, 176, .r), // 'ử'225:187:173
                        175 => self.setb1b0t(198, 176, .x), // 'ữ'225:187:175
                        177 => self.setb1b0t(198, 176, .j), // 'ự'225:187:177

                        179 => self.setb1b0t(0, 'y', .f), //   'ỳ'225:187:179
                        181 => self.setb1b0t(0, 'y', .j), //   'ỵ'225:187:181
                        183 => self.setb1b0t(0, 'y', .r), //   'ỷ'225:187:183
                        185 => self.setb1b0t(0, 'y', .x), //   'ỹ'225:187:185
                        //
                        else => self.setb1b0t(0, 0, ._none), // invalid
                    },
                    else => self.setb1b0t(0, 0, ._none), //     invalid
                }
            }, // switch (curr_byte)
            else => self.setb1b0t(0, 0, ._none), //             invalid
        }
        //  DEBUG
        if (DEBUG) {
            const w: []const u8 = &.{ self.byte1, self.byte0 };
            std.debug.print(" >> {s: >2}: {d: >3}:{d: >3}", .{ w, self.byte1, self.byte0 });
        }
    }
};

fn charEqual(char: Char, byte1: u8, byte0: u8, tone: sds.Tone, len: usize, upper: bool) bool {
    return char.byte1 == byte1 and char.byte0 == byte0 and
        char.tone == tone and char.len == len and char.upper == upper;
}

const expect = std.testing.expect;
test "char.parse()" {
    var char: Char = undefined;
    char.parse("Ứ", 0);
    try expect(charEqual(char, 198, 176, .s, 3, true));
}
