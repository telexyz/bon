const std = @import("std");
const sds = @import("syllable.zig"); // sds: Syllable Data Structures
const getInitial = @import("am_dau.zig").getInitial;
const getMiddle = @import("am_giua.zig").getMiddle;
const DEBUG = true;

pub fn main() void {
    std.debug.print("\n{s: >11}: {s: >5} {s: >5} {s: >5} {s: >5}", .{ "ÂM TIẾT", "ĐẦU", "GIỮA", "CUỐI", "THANH" });
    // _ = parseSyllable("GÀN");
    // _ = parseSyllable("GặN");
    // _ = parseSyllable("GIừp");
    // _ = parseSyllable("nGhiÊng");
    // _ = parseSyllable("nGiêng");
    _ = parseSyllable("đim");
    _ = parseSyllable("ĩm");
    _ = parseSyllable("gĩm");
}

const MAX_SYLLABLE_LEN = 10;

pub fn parseSyllable(str: []const u8) sds.Syllable {
    var syll = sds.Syllable.new();
    if (str.len > MAX_SYLLABLE_LEN) return syll;

    var c0: Char = undefined;
    var c1: Char = undefined;

    c0.parse(str, 0);
    var pos = c0.len;

    if (str.len > 1) {
        // chỉ phân tích âm đầu khi có 2 ký tự trở lên
        // vì âm tiết lúc nào cũng có nguyên âm

        if (pos > 1) { // đ
            syll.am_dau = getInitial(c0.byte1, c0.byte0);
        } else {
            c1.parse(str, pos);
            pos += c1.len;
            syll.am_dau = getInitial(c0.byte0, c1.byte0);
        }
    }

    // bỏ qua h của ngh
    if (syll.am_dau == .ng and (str[pos] == 'h' or str[pos] == 'H')) pos += 1;

    // phân tích âm giữa
    if (syll.am_dau.len() == 2) {
        c0.parse(str, pos);
        pos += c0.len;

        c1.parse(str, pos);
        pos += c1.len;
        //
    } else { // sử dụng lại c1
        c0 = c1;
        c1.parse(str, pos);
        pos += c1.len;
    }
    // oa, // hoa
    // oe, // toe
    // oo, // boong
    // uy, // tuy
    if ((c0.byte0 == 'u' and c1.byte0 == 'y') or
        (c0.byte1 == 0 and c0.byte0 == 'o' and c1.byte1 == 0 and
        (c1.byte0 == 'a' or c1.byte0 == 'e' or c1.byte0 == 'o')))
    {
        c0.byte1 = c0.byte0;
        c0.byte0 = c1.byte0;
        c1.parse(str, pos);
        pos += c1.len;
    }

    syll.am_giua = getMiddle(c0.byte0, c0.byte1, c1.byte0, c1.byte1);

    // xác định thanh điệu
    syll.tone = c0.tone;
    if (syll.tone == ._none) syll.tone = c1.tone;

    std.debug.print(
        "\n     - - - - - - - - - - - - - - - -" ++ "\n{s: >11}: {s: >5} {s: >5} {s: >5} {s: >5}",
        .{ str, @tagName(syll.am_dau), @tagName(syll.am_giua), @tagName(syll.am_cuoi), @tagName(syll.tone) },
    );

    return syll;
}

const Char = struct {
    byte0: u8 = undefined,
    byte1: u8 = undefined,
    isUpper: bool = undefined,
    tone: sds.Tone = undefined,
    len: usize = undefined,

    pub inline fn parse(self: *Char, str: []const u8, idx: usize) void {
        const x = str[idx];
        self.tone = ._none;

        // DEBUG
        if (DEBUG and (x < 128 or idx < str.len - 1)) {
            const y = if (x < 128) 0 else str[idx + 1];
            const w = if (x < 128) [_]u8{ 32, x } else [_]u8{ x, y };
            std.debug.print("\nstr[{d}] = {s: >2} {d: >3}:{d: >3}", .{ idx, w, x, y });
        }

        switch (x) {
            0...127 => { // 1-byte chars
                //              a: 01100001
                //              A: 01000001
                self.isUpper = ((0b00100000 & x)) == 0;
                self.byte0 = x | 0b00100000; // toLower
                self.byte1 = 0;
                self.len = 1;
            },
            195 => { // 2-byte chars A/
                self.byte1 = x;
                var y = str[idx + 1];
                //              ê: 10101010
                //              Ê: 10001010
                self.isUpper = ((0b00100000 & x)) == 0;
                y |= 0b00100000; // toLower
                self.byte1 = 0;
                self.len = 2;

                switch (y) {
                    160 => {
                        self.byte0 = 'a';
                        self.tone = .f;
                    },
                    161 => {
                        self.byte0 = 'a';
                        self.tone = .s;
                    },
                    163 => {
                        self.byte0 = 'a';
                        self.tone = .x;
                    },
                    168 => {
                        self.byte0 = 'e';
                        self.tone = .f;
                    },
                    169 => {
                        self.byte0 = 'e';
                        self.tone = .s;
                    },
                    172 => {
                        self.byte0 = 'i';
                        self.tone = .f;
                    },
                    173 => {
                        self.byte0 = 'i';
                        self.tone = .s;
                    },
                    178 => {
                        self.byte0 = 'o';
                        self.tone = .f;
                    },
                    179 => {
                        self.byte0 = 'o';
                        self.tone = .s;
                    },
                    181 => {
                        self.byte0 = 'o';
                        self.tone = .x;
                    },
                    185 => {
                        self.byte0 = 'u';
                        self.tone = .f;
                    },
                    186 => {
                        self.byte0 = 'u';
                        self.tone = .s;
                    },
                    189 => {
                        self.byte0 = 'y';
                        self.tone = .s;
                    },
                    else => {
                        self.byte0 = y;
                        self.byte1 = x;
                        self.tone = ._none;
                    },
                }
            },
            196...198 => { // 2-byte chars B/
                var y = str[idx + 1];
                self.len = 2;

                switch (y) {
                    175 => {
                        self.byte0 = 176;
                        self.byte1 = x;
                        self.isUpper = true;
                    },
                    176 => {
                        self.byte0 = 176;
                        self.byte1 = x;
                        self.isUpper = false;
                    },
                    else => {
                        self.isUpper = (y & 0b1) == 0;
                        y |= 0b1; // toLower
                        if (y == 169) {
                            self.tone = .x;
                            self.byte0 = if (x == 196) 'i' else 'u';
                            self.byte1 = 0;
                        } else {
                            self.byte0 = y;
                            self.byte1 = x;
                        }
                    },
                }
            },
            225 => { // 3-byte chars
                self.byte1 = str[idx + 1];
                var y = str[idx + 2];
                self.isUpper = (y & 0b1) == 0;
                y |= 0b1; // toLower
                self.len = 3;

                switch (self.byte1) {
                    186 => // 3-byte chars C/
                    switch (y) {
                        161 => {
                            self.byte1 = 0;
                            self.byte0 = 'a';
                            self.tone = .j;
                        }, // 'ạ'225:186:161
                        163 => {
                            self.byte1 = 0;
                            self.byte0 = 'a';
                            self.tone = .r;
                        }, // 'ả'225:186:163
                        // 'â'195:162
                        165 => {
                            self.byte1 = 195;
                            self.byte0 = 162;
                            self.tone = .s;
                        }, // 'ấ'225:186:165
                        167 => {
                            self.byte1 = 195;
                            self.byte0 = 162;
                            self.tone = .f;
                        }, // 'ầ'225:186:167
                        169 => {
                            self.byte1 = 195;
                            self.byte0 = 162;
                            self.tone = .r;
                        }, // 'ẩ'225:186:169
                        171 => {
                            self.byte1 = 195;
                            self.byte0 = 162;
                            self.tone = .x;
                        }, // 'ẫ'225:186:171
                        173 => {
                            self.byte1 = 195;
                            self.byte0 = 162;
                            self.tone = .j;
                        }, // 'ậ'225:186:173
                        // 'ă'196:131
                        175 => {
                            self.byte1 = 196;
                            self.byte0 = 131;
                            self.tone = .s;
                        }, // 'ắ'225:186:175
                        177 => {
                            self.byte1 = 196;
                            self.byte0 = 131;
                            self.tone = .f;
                        }, // 'ằ'225:186:177
                        179 => {
                            self.byte1 = 196;
                            self.byte0 = 131;
                            self.tone = .r;
                        }, // 'ẳ'225:186:179
                        181 => {
                            self.byte1 = 196;
                            self.byte0 = 131;
                            self.tone = .x;
                        }, // 'ẵ'225:186:181
                        183 => {
                            self.byte1 = 196;
                            self.byte0 = 131;
                            self.tone = .j;
                        }, // 'ặ'225:186:183
                        185 => {
                            self.byte1 = 0;
                            self.byte0 = 'e';
                            self.tone = .j;
                        }, // 'ẹ'225:186:185
                        187 => {
                            self.byte1 = 0;
                            self.byte0 = 'e';
                            self.tone = .r;
                        }, // 'ẻ'225:186:187
                        189 => {
                            self.byte1 = 0;
                            self.byte0 = 'e';
                            self.tone = .x;
                        }, // 'ẽ'225:186:189
                        // 'ê'195:170
                        191 => {
                            self.byte1 = 195;
                            self.byte0 = 170;
                            self.tone = .s;
                        }, // 'ế'225:186:191
                        else => {
                            self.byte0 = 0;
                            self.byte1 = 0;
                        },
                    },
                    187 => switch (y) { // 3-byte chars D/
                        // 'ê'195:170
                        129 => {
                            self.byte1 = 195;
                            self.byte0 = 170;
                            self.tone = .f;
                        }, // 'ề'225:187:129
                        131 => {
                            self.byte1 = 195;
                            self.byte0 = 170;
                            self.tone = .r;
                        }, // 'ể'225:187:131
                        133 => {
                            self.byte1 = 195;
                            self.byte0 = 170;
                            self.tone = .x;
                        }, // 'ễ'225:187:133
                        135 => {
                            self.byte1 = 195;
                            self.byte0 = 170;
                            self.tone = .j;
                        }, // 'ệ'225:187:135
                        // i
                        137 => {
                            self.byte1 = 0;
                            self.byte0 = 'i';
                            self.tone = .r;
                        }, // 'ỉ'225:187:137
                        139 => {
                            self.byte1 = 0;
                            self.byte0 = 'i';
                            self.tone = .j;
                        }, // 'ị'225:187:139
                        // o
                        141 => {
                            self.byte1 = 0;
                            self.byte0 = 'o';
                            self.tone = .j;
                        }, // 'ọ'225:187:141
                        143 => {
                            self.byte1 = 0;
                            self.byte0 = 'o';
                            self.tone = .r;
                        }, // 'ỏ'225:187:143
                        // 'ô'195:180
                        145 => {
                            self.byte1 = 195;
                            self.byte0 = 180;
                            self.tone = .s;
                        }, // 'ố'225:187:145
                        147 => {
                            self.byte1 = 195;
                            self.byte0 = 180;
                            self.tone = .f;
                        }, // 'ồ'225:187:147
                        149 => {
                            self.byte1 = 195;
                            self.byte0 = 180;
                            self.tone = .r;
                        }, // 'ổ'225:187:149
                        151 => {
                            self.byte1 = 195;
                            self.byte0 = 180;
                            self.tone = .x;
                        }, // 'ỗ'225:187:151
                        153 => {
                            self.byte1 = 195;
                            self.byte0 = 180;
                            self.tone = .j;
                        }, // 'ộ'225:187:153
                        // 'ơ'198:161
                        155 => {
                            self.byte1 = 198;
                            self.byte0 = 161;
                            self.tone = .s;
                        }, // 'ớ'225:187:155
                        157 => {
                            self.byte1 = 198;
                            self.byte0 = 161;
                            self.tone = .f;
                        }, // 'ờ'225:187:157
                        159 => {
                            self.byte1 = 198;
                            self.byte0 = 161;
                            self.tone = .r;
                        }, // 'ở'225:187:159
                        161 => {
                            self.byte1 = 198;
                            self.byte0 = 161;
                            self.tone = .x;
                        }, // 'ỡ'225:187:161
                        163 => {
                            self.byte1 = 198;
                            self.byte0 = 161;
                            self.tone = .j;
                        }, // 'ợ'225:187:163
                        // u
                        165 => {
                            self.byte1 = 0;
                            self.byte0 = 'u';
                            self.tone = .j;
                        }, // 'ụ'225:187:165
                        167 => {
                            self.byte1 = 0;
                            self.byte0 = 'u';
                            self.tone = .r;
                        }, // 'ủ'225:187:167
                        // 'ư'198:176
                        169 => {
                            self.byte1 = 198;
                            self.byte0 = 176;
                            self.tone = .s;
                        }, // 'ứ'225:187:169
                        171 => {
                            self.byte1 = 198;
                            self.byte0 = 176;
                            self.tone = .f;
                        }, // 'ừ'225:187:171
                        173 => {
                            self.byte1 = 198;
                            self.byte0 = 176;
                            self.tone = .r;
                        }, // 'ử'225:187:173
                        175 => {
                            self.byte1 = 198;
                            self.byte0 = 176;
                            self.tone = .x;
                        }, // 'ữ'225:187:175
                        177 => {
                            self.byte1 = 198;
                            self.byte0 = 176;
                            self.tone = .j;
                        }, // 'ự'225:187:177
                        // y
                        179 => {
                            self.byte1 = 0;
                            self.byte0 = 'y';
                            self.tone = .f;
                        }, // 'ỳ'225:187:179
                        181 => {
                            self.byte1 = 0;
                            self.byte0 = 'y';
                            self.tone = .j;
                        }, // 'ỵ'225:187:181
                        183 => {
                            self.byte1 = 0;
                            self.byte0 = 'y';
                            self.tone = .r;
                        }, // 'ỷ'225:187:183
                        185 => {
                            self.byte1 = 0;
                            self.byte0 = 'y';
                            self.tone = .x;
                        }, // 'ỹ'225:187:185
                        else => {
                            self.byte0 = 0;
                            self.byte1 = 0;
                        },
                    },
                    else => {
                        self.byte0 = 0;
                        self.byte1 = 0;
                    },
                }
            },
            else => {
                // invalid
                self.byte0 = 0;
                self.byte1 = 0;
            },
        }
        // DEBUG
        if (DEBUG) {
            const w: []const u8 = &.{ self.byte1, self.byte0 };
            std.debug.print(" >> {s: >2}: {d: >3}:{d: >3}", .{ w, self.byte1, self.byte0 });
        }
    }
};
