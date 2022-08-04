const std = @import("std");
const sds = @import("syllable.zig"); // sds: Syllable Data Structures
const getInitial = @import("am_dau.zig").getInitial;
const getMiddle = @import("am_giua.zig").getMiddle;

const MAX_SYLLABLE_LEN = 10;

pub fn parseSyllable(str: []const u8) sds.Syllable {
    var syll = sds.Syllable.new();
    if (str.len > MAX_SYLLABLE_LEN) return syll;

    var c0: Char = undefined;
    var c1: Char = undefined;

    c0.parse(str, 0);
    var pos = c0.len();

    if (str.len > 1) {
        // chỉ phân tích âm đầu khi có 2 ký tự trở lên
        // vì âm tiết lúc nào cũng có nguyên âm

        if (pos > 1) { // đ
            syll.am_dau = getInitial(c0.byte1, c0.byte0);
        } else {
            c1.parse(str, pos);
            pos += c1.len();
            syll.am_dau = getInitial(c0.byte0, c1.byte0);
        }
    }

    // bỏ qua h của ngh
    if (syll.am_dau == .ng and (str[pos] == 'h' or str[pos] == 'H')) pos += 1;

    // phân tích âm giữa
    if (syll.am_dau.len() == 2) {
        c0.parse(str, pos);
        pos += c0.len();
        c1.parse(str, pos);
        pos += c1.len();
    } else { // sử dụng lại c1
        c0 = c1;
        c1.parse(str, pos);
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
    }

    syll.am_giua = getMiddle(c0.byte0, c0.byte1, c1.byte0, c1.byte1);

    // xác định thanh điệu
    syll.tone = c0.tone;
    if (syll.tone == ._none) syll.tone = c1.tone;

    std.debug.print(
        "\n{s: >11}: {s: >5} {s: >5} {s: >5} {s: >5}",
        .{ str, @tagName(syll.am_dau), @tagName(syll.am_giua), @tagName(syll.am_cuoi), @tagName(syll.tone) },
    );

    return syll;
}

const Char = struct {
    byte0: u8 = undefined,
    byte1: u8 = undefined,
    isUpper: bool = undefined,
    tone: sds.Tone = undefined,

    pub inline fn parse(self: *Char, str: []const u8, idx: usize) void {
        const x = str[idx];
        self.tone = ._none;

        switch (x) {
            0...127 => {
                // std.debug.print("\n\n{c}: {x}", .{ x, x });
                //              a: 01100001
                //              A: 01000001
                self.isUpper = ((0b00100000 & x)) == 0;
                self.byte0 = x | 0b00100000; // toLower
                self.byte1 = 0;
            },
            195 => {
                self.byte1 = x;
                var y = str[idx + 1];
                // const w = [_]u8{ x, y };
                // std.debug.print("\n\n{s}: {b:0>8}", .{ w, y });
                //              ê: 10101010
                //              Ê: 10001010
                self.isUpper = ((0b00100000 & x)) == 0;
                y |= 0b00100000; // toLower
                self.byte1 = 0;
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
            196...198 => {
                const y = str[idx + 1];
                self.isUpper = (y & 0b1) != 0;
            },
            255 => {},
            else => {
                self.byte0 = 0;
                self.byte1 = 0;
            },
        }
    }

    pub inline fn len(self: *Char) usize {
        switch (self.byte1) {
            0 => return 1,
            195...198 => return 2,
            186, 187 => return 3,
            else => return 4,
        }
    }

    pub inline fn isAscii(self: *Char) bool {
        return self.byte1 == 0 and self.byte0 < 128;
    }
};

pub fn main() void {
    std.debug.print("\n{s: >11}: {s: >5} {s: >5} {s: >5} {s: >5}\n     - - - - - - - - - - - - - - - -", .{ "ÂM TIẾT", "ĐẦU", "GIỮA", "CUỐI", "THANH" });
    _ = parseSyllable("GÀN");
    _ = parseSyllable("GáN");
    _ = parseSyllable("GIúp");
    _ = parseSyllable("nGhiÊng");
    _ = parseSyllable("nGiêng");

    // std.debug.print("\na:{b}\nA:{b}", .{ 'a', 'A' });
}

// Các thao tác trên âm tiết là 1 chuỗi ký tự utf-8 bao gồm:
//
// - utf8Mark(): để đánh dấu bytes thuộc utf-8
//
// - toLower(): convert thành toàn bộ âm thường
//
// - extractTone(): lọc tone ra khỏi nguyên âm viết thường `mượn => mươn + j_tone`
//
// MÃ UTF8 TIẾNG VIỆT
// - - - - - - - - -
//
// - chia tập mã utf8 tv thành 4 tập A/ B/ C/ D/
// - next-byte trong tập A/ C/ D/ là uniq
// - next-byte trong tập B/ bị trùng ở 'Ĩ'196:168 'ĩ'196:169
//                                     'Ũ'197:168 'ũ'197:169
//
// * Check byte == 195 => A/ 32-chars
//   - toLower: set next-byte's 5th-bit = 0
//
//   - extractTone: switch (next-byte) {
//          160: char = 0a, tone = f // 'à'195:160
//          161: char = 0a, tone = s // 'á'195:161
//          163: char = 0a, tone = x // 'ã'195:163
//          168: char = 0e, tone = f //
//          169: char = 0e, tone = s //
//          172: char = 0i, tone = f //
//          173: char = 0i, tone = s //
//          178: char = 0o, tone = f //
//          179: char = 0o, tone = s //
//          181: char = 0o, tone = x //
//          185: char = 0u, tone = f //
//          186: char = 0u, tone = s //
//          189: char = 0y, tone = s //
//          else: char = this-byte_next-byte, tone = 0;
//     }
//
// * Check byte in 196-198 => B/ 12-chars
//   - toLower:
//       if next-byte == 175 -> next-byte == 176
//       else -> set next-byte's 0th-bit = 0
//
//   - extractTone: if (next-byte == 169) {
//          tone = 'x'
//          char = if (this-byte == 196) 0i else 0u
//
//     } else: char = this-byte_next-byte, tone = 0;
//
// * Check byte == 186 => C/
//   - verify prev-byte == 225
//   - toLower: set next-byte's 0th-bit = 0
//   - extractTone: switch (next-byte) {
//           161: char = 0a, tone = j // 'ạ'225:186:161
//           163: char = 0a, tone = r // 'ả'225:186:163
//           165: char =  â, tone = s // 'ấ'225:186:165
//           167: char =  â, tone = f // 'ầ'225:186:167
//           169: char =  â, tone = r // 'ẩ'225:186:169
//           171: char =  â, tone = x // 'ẫ'225:186:171
//           173: char =  â, tone = j // 'ậ'225:186:173
//           175: char =  ă, tone = s // 'ắ'225:186:175
//           177: char =  ă, tone = f // 'ằ'225:186:177
//           179: char =  ă, tone = r // 'ẳ'225:186:179
//           181: char =  ă, tone = x // 'ẵ'225:186:181
//           183: char =  ă, tone = j // 'ặ'225:186:183
//           185: char = 0e, tone = j // 'ẹ'225:186:185
//           187: char = 0e, tone = r // 'ẻ'225:186:187
//           189: char = 0e, tone = x // 'ẽ'225:186:189
//           191: char =  ê, tone = s // 'ế'225:186:191
//     }
//
// * Check byte == 187 => D/
//   - verify prev-byte == 225
//   - toLower: set next-byte's 0th-bit = 0
//   - extractTone: switch (next-byte) {
//           129: char =  ê, tone = f // 'ề'225:187:129
//           131: char =  ê, tone = r // 'ể'225:187:131
//           133: char =  ê, tone = x // 'ễ'225:187:133
//           135: char =  ê, tone = j // 'ệ'225:187:135
//           137: char = 0i, tone = r // 'ỉ'225:187:137
//           139: char = 0i, tone = j // 'ị'225:187:139
//           141: char = 0o, tone = j // 'ọ'225:187:141
//           143: char = 0o, tone = r // 'ỏ'225:187:143
//           145: char =  ô, tone = s // 'ố'225:187:145
//           147: char =  ô, tone = f // 'ồ'225:187:147
//           149: char =  ô, tone = r // 'ổ'225:187:149
//           151: char =  ô, tone = x // 'ỗ'225:187:151
//           153: char =  ô, tone = j // 'ộ'225:187:153
//           155: char =  ơ, tone = s // 'ớ'225:187:155
//           157: char =  ơ, tone = f // 'ờ'225:187:157
//           159: char =  ơ, tone = r // 'ở'225:187:159
//           161: char =  ơ, tone = x // 'ỡ'225:187:161
//           163: char =  ơ, tone = j // 'ợ'225:187:163
//           165: char = 0u, tone = j // 'ụ'225:187:165
//           167: char = 0u, tone = r // 'ủ'225:187:167
//           169: char =  ư, tone = s // 'ứ'225:187:169
//           171: char =  ư, tone = f // 'ừ'225:187:171
//           173: char =  ư, tone = r // 'ử'225:187:173
//           175: char =  ư, tone = x // 'ữ'225:187:175
//           177: char =  ư, tone = j // 'ự'225:187:177
//           179: char = 0y, tone = f // 'ỳ'225:187:179
//           181: char = 0y, tone = j // 'ỵ'225:187:181
//           183: char = 0y, tone = r // 'ỷ'225:187:183
//           185: char = 0y, tone = x // 'ỹ'225:187:185
//     }
//
// A/ 32-chars: bit thứ 5 = 0 là viết hoa, 1 là viết thường
// - - - - - - - - - - -
// 'À'195:128 'Á'195:129 'Â'195:130 'Ã'195:131
// 'È'195:136 'É'195:137 'Ê'195:138
// 'Ì'195:140 'Í'195:141
// 'Ò'195:146 'Ó'195:147 'Ô'195:148 'Õ'195:149
// 'Ù'195:153 'Ú'195:154
// 'Ý'195:157
// 'à'195:160 'á'195:161 'â'195:162 'ã'195:163
// 'è'195:168 'é'195:169 'ê'195:170
// 'ì'195:172 'í'195:173
// 'ò'195:178 'ó'195:179 'ô'195:180 'õ'195:181
// 'ù'195:185 'ú'195:186
// 'ý'195:189
//
// B/ 12-chars: bit thấp nhất = 0 là viết hoa, 1 là viết thường trừ trường hợp `Ưư`
// - - - - - - - - - - -
// 'Ă'196:130 'ă'196:131
// 'Đ'196:144 'đ'196:145
// 'Ĩ'196:168 'ĩ'196:169
// 'Ũ'197:168 'ũ'197:169
// 'Ơ'198:160 'ơ'198:161
// 'Ư'198:175 'ư'198:176 // bit thấp nhất = 1 là viết hoa, 0 là viết thường
//
// C/ 32-chars: bit thấp nhất = 0 là viết hoa, 1 là viết thường
//    32-chars 225:186:160-191
// - - - - - - - - - - - - - -
// 'Ạ'225:186:160 'ạ'225:186:161 'Ả'225:186:162 'ả'225:186:163
// 'Ấ'225:186:164 'ấ'225:186:165 'Ầ'225:186:166 'ầ'225:186:167
// 'Ẩ'225:186:168 'ẩ'225:186:169 'Ẫ'225:186:170 'ẫ'225:186:171
// 'Ậ'225:186:172 'ậ'225:186:173 'Ắ'225:186:174 'ắ'225:186:175
// 'Ằ'225:186:176 'ằ'225:186:177 'Ẳ'225:186:178 'ẳ'225:186:179
// 'Ẵ'225:186:180 'ẵ'225:186:181 'Ặ'225:186:182 'ặ'225:186:183
// 'Ẹ'225:186:184 'ẹ'225:186:185 'Ẻ'225:186:186 'ẻ'225:186:187
// 'Ẽ'225:186:188 'ẽ'225:186:189 'Ế'225:186:190 'ế'225:186:191
//
// D/ 58-chars: bit thấp nhất = 0 là viết hoa, 1 là viết thường
//    58-chars 225:187:128-185
// - - - - - - - - - - - - - -
// 'Ề'225:187:128 'ề'225:187:129 'Ể'225:187:130 'ể'225:187:131
// 'Ễ'225:187:132 'ễ'225:187:133 'Ệ'225:187:134 'ệ'225:187:135
// 'Ỉ'225:187:136 'ỉ'225:187:137 'Ị'225:187:138 'ị'225:187:139
// 'Ọ'225:187:140 'ọ'225:187:141 'Ỏ'225:187:142 'ỏ'225:187:143
// 'Ố'225:187:144 'ố'225:187:145 'Ồ'225:187:146 'ồ'225:187:147
// 'Ổ'225:187:148 'ổ'225:187:149 'Ỗ'225:187:150 'ỗ'225:187:151
// 'Ộ'225:187:152 'ộ'225:187:153 'Ớ'225:187:154 'ớ'225:187:155
// 'Ờ'225:187:156 'ờ'225:187:157 'Ở'225:187:158 'ở'225:187:159
// 'Ỡ'225:187:160 'ỡ'225:187:161 'Ợ'225:187:162 'ợ'225:187:163
// 'Ụ'225:187:164 'ụ'225:187:165 'Ủ'225:187:166 'ủ'225:187:167
// 'Ứ'225:187:168 'ứ'225:187:169 'Ừ'225:187:170 'ừ'225:187:171
// 'Ử'225:187:172 'ử'225:187:173 'Ữ'225:187:174 'ữ'225:187:175
// 'Ự'225:187:176 'ự'225:187:177 'Ỳ'225:187:178 'ỳ'225:187:179
// 'Ỵ'225:187:180 'ỵ'225:187:181 'Ỷ'225:187:182 'ỷ'225:187:183
// 'Ỹ'225:187:184 'ỹ'225:187:185
//

// DỮ LIỆU ĐỂ SCAN TONE NHANH
//
// 'à'    195:160
// 'è'    195:168
// 'ì'    195:172
// 'ò'    195:178
// 'ù'    195:185
// 'ầ'225:186:167
// 'ằ'225:186:177
// 'ề'225:187:129
// 'ồ'225:187:147
// 'ờ'225:187:157
// 'ừ'225:187:171
// 'ỳ'225:187:179
//
//
// 'à'195:160 'á'195:161 'ã'195:163
// 'ạ'186:161 'ả'186:163

// 'è'195:168 'é'195:169
// 'ẹ'186:185 'ẻ'186:187 'ẽ'186:189

// 'ì'195:172 'í'195:173
// 'ĩ'196:169
// 'ỉ'187:137 'ị'187:139

// 'ò'195:178 'ó'195:179 'õ'195:181
// 'ọ'187:141 'ỏ'187:143

// 'ù'195:185 'ú'195:186
// 'ũ'197:169
// 'ụ'187:165 'ủ'187:167

// 'ý'195:189
// 'ỳ'187:179 'ỵ'187:181 'ỷ'187:183 'ỹ'187:185

// 'ấ'186:165 'ầ'186:167 'ẩ'186:169 'ẫ'186:171 'ậ'186:173
// 'ắ'186:175 'ằ'186:177 'ẳ'186:179 'ẵ'186:181 'ặ'186:183

// 'ế'186:191
// 'ề'187:129 'ể'187:131 'ễ'187:133 'ệ'187:135

// 'ố'187:145 'ồ'187:147 'ổ'187:149 'ỗ'187:151 'ộ'187:153
// 'ớ'187:155 'ờ'187:157 'ở'187:159 'ỡ'187:161 'ợ'187:163
// 'ứ'187:169 'ừ'187:171 'ử'187:173 'ữ'187:175 'ự'187:177

// 'ạ'225:186:161
// 'ả'225:186:163
// 'ấ'225:186:165
// 'ầ'225:186:167
// 'ẩ'225:186:169
// 'ẫ'225:186:171
// 'ậ'225:186:173
// 'ắ'225:186:175
// 'ằ'225:186:177
// 'ẳ'225:186:179
// 'ẵ'225:186:181
// 'ặ'225:186:183
// 'ẹ'225:186:185
// 'ẻ'225:186:187
// 'ẽ'225:186:189
// 'ế'225:186:191
//
// 'ề'225:187:129
// 'ể'225:187:131
// 'ễ'225:187:133
// 'ệ'225:187:135
// 'ỉ'225:187:137
// 'ị'225:187:139
// 'ọ'225:187:141
// 'ỏ'225:187:143
// 'ố'225:187:145
// 'ồ'225:187:147
// 'ổ'225:187:149
// 'ỗ'225:187:151
// 'ộ'225:187:153
// 'ớ'225:187:155
// 'ờ'225:187:157
// 'ở'225:187:159
// 'ỡ'225:187:161
// 'ợ'225:187:163
// 'ụ'225:187:165
// 'ủ'225:187:167
// 'ứ'225:187:169
// 'ừ'225:187:171
// 'ử'225:187:173
// 'ữ'225:187:175
// 'ự'225:187:177
// 'ỳ'225:187:179
// 'ỵ'225:187:181
// 'ỷ'225:187:183
// 'ỹ'225:187:185
