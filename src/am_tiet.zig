const std = @import("std");
const sds = @import("syllable.zig"); // sds: Syllable Data Structures
const getInitial = @import("am_dau.zig").getInitial;
const getMiddle = @import("am_giua.zig").getMiddle;

const DEBUG = false;
pub fn main() void {
    std.debug.print("\n{s: >11}: {s: >5} {s: >5} {s: >5} {s: >5}", .{ "ÂM TIẾT", "ĐẦU", "GIỮA", "CUỐI", "THANH" });
    _ = parseSyllable("GÀN");
    _ = parseSyllable("GặN");
    _ = parseSyllable("GIừp");
    _ = parseSyllable("nGhiÊng");
    _ = parseSyllable("nGiêng");
    _ = parseSyllable("đim");
    _ = parseSyllable("ĩm");
    // _ = parseSyllable("gĩm");
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

    inline fn setb1b0t(self: *Char, b1: u8, b0: u8, t: sds.Tone) void {
        self.byte1 = b1;
        self.byte0 = b0;
        self.tone = t;
    }

    inline fn setb1b0tUp(self: *Char, b1: u8, b0: u8, t: sds.Tone, isUp: bool) void {
        self.byte1 = b1;
        self.byte0 = b0;
        self.tone = t;
        self.isUpper = isUp;
    }

    pub inline fn parse(self: *Char, str: []const u8, idx: usize) void {
        const x = str[idx];

        // DEBUG
        if (DEBUG and (x < 128 or idx < str.len - 1)) {
            const y = if (x < 128) 0 else str[idx + 1];
            const w = if (x < 128) [_]u8{ 32, x } else [_]u8{ x, y };
            std.debug.print("\nstr[{d}] = {s: >2} {d: >3}:{d: >3}", .{ idx, w, x, y });
        }

        self.tone = ._none;
        self.len = 0;

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
                var y = str[idx + 1];
                //              ê: 10101010
                //              Ê: 10001010
                self.isUpper = ((0b00100000 & y)) == 0;
                y |= 0b00100000; // toLower
                self.len = 2;

                switch (y) {
                    160 => self.setb1b0t(0, 'a', .f),
                    161 => self.setb1b0t(0, 'a', .s),
                    163 => self.setb1b0t(0, 'a', .x),
                    168 => self.setb1b0t(0, 'e', .f),
                    169 => self.setb1b0t(0, 'e', .s),
                    172 => self.setb1b0t(0, 'i', .f),
                    173 => self.setb1b0t(0, 'i', .s),
                    178 => self.setb1b0t(0, 'o', .f),
                    179 => self.setb1b0t(0, 'o', .s),
                    181 => self.setb1b0t(0, 'o', .x),
                    185 => self.setb1b0t(0, 'u', .f),
                    186 => self.setb1b0t(0, 'u', .s),
                    189 => self.setb1b0t(0, 'y', .s),
                    else => self.setb1b0t(y, x, ._none),
                }
            },
            196...198 => { // 2-byte chars B/
                var y = str[idx + 1];
                self.len = 2;

                switch (y) {
                    175 => self.setb1b0tUp(x, 176, ._none, true),
                    176 => self.setb1b0tUp(x, 176, ._none, false),
                    else => {
                        self.isUpper = (y & 0b1) == 0;
                        y |= 0b1; // toLower
                        if (y == 169) self.setb1b0t(0, if (x == 196) 'i' else 'u', .x) //
                        else self.setb1b0t(x, y, ._none);
                    },
                }
            },
            225 => { // 3-byte chars
                var y = str[idx + 2];
                self.isUpper = (y & 0b1) == 0;
                y |= 0b1; // toLower
                self.len = 3;

                switch (str[idx + 1]) {
                    186 => // 3-byte chars C/
                    switch (y) {
                        161 => self.setb1b0t(0, 'a', .j), // 'ạ'225:186:161
                        163 => self.setb1b0t(0, 'a', .r), // 'ả'225:186:163
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
                        185 => self.setb1b0t(0, 'e', .j), // 'ẹ'225:186:185
                        187 => self.setb1b0t(0, 'e', .r), // 'ẻ'225:186:187
                        189 => self.setb1b0t(0, 'e', .x), // 'ẽ'225:186:189
                        // 'ê'195:170
                        191 => self.setb1b0t(195, 170, .s), // 'ế'225:186:191
                        else => self.setb1b0t(0, 0, ._none),
                    },
                    187 => switch (y) { // 3-byte chars D/
                        // 'ê'195:170
                        129 => self.setb1b0t(195, 170, .f), // 'ề'225:187:129
                        131 => self.setb1b0t(195, 170, .r), // 'ể'225:187:131
                        133 => self.setb1b0t(195, 170, .x), // 'ễ'225:187:133
                        135 => self.setb1b0t(195, 170, .j), // 'ệ'225:187:135

                        // i
                        137 => self.setb1b0t(0, 'i', .r), // 'ỉ'225:187:137
                        139 => self.setb1b0t(0, 'i', .j), // 'ị'225:187:139

                        // o
                        141 => self.setb1b0t(0, 'o', .j), // 'ọ'225:187:141
                        143 => self.setb1b0t(0, 'o', .r), // 'ỏ'225:187:143

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

                        // u
                        165 => self.setb1b0t(0, 'u', .j), // 'ụ'225:187:165
                        167 => self.setb1b0t(0, 'u', .r), // 'ủ'225:187:167

                        // 'ư'198:176
                        169 => self.setb1b0t(198, 176, .s), // 'ứ'225:187:169
                        171 => self.setb1b0t(198, 176, .f), // 'ừ'225:187:171
                        173 => self.setb1b0t(198, 176, .r), // 'ử'225:187:173
                        175 => self.setb1b0t(198, 176, .x), // 'ữ'225:187:175
                        177 => self.setb1b0t(198, 176, .j), // 'ự'225:187:177

                        // y
                        179 => self.setb1b0t(0, 'y', .f), // 'ỳ'225:187:179
                        181 => self.setb1b0t(0, 'y', .j), // 'ỵ'225:187:181
                        183 => self.setb1b0t(0, 'y', .r), // 'ỷ'225:187:183
                        185 => self.setb1b0t(0, 'y', .x), // 'ỹ'225:187:185
                        else => self.setb1b0t(0, 0, ._none), // invalid
                    },
                    else => self.setb1b0t(0, 0, ._none), // invalid
                }
            }, // switch (x)
            else => self.setb1b0t(0, 0, ._none), // invalid
        }
        // DEBUG
        if (DEBUG) {
            const w: []const u8 = &.{ self.byte1, self.byte0 };
            std.debug.print(" >> {s: >2}: {d: >3}:{d: >3}", .{ w, self.byte1, self.byte0 });
        }
    }
};
