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
// - chia tập mã utf8 tv thành 3 tập A/ B/ C/
// - next-byte trong tập A/ C/ là uniq
// - next-byte trong tập B/ bị trùng ở 'Ĩ'196:168 'ĩ'196:169
//                                     'Ũ'197:168 'ũ'197:169
//
// * Check byte == 195 => A/
//   - toLower: set next-byte's 5th-bit = 0
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
//      }
//
// * Check byte in 196-198 => B/
//   - toLower:
//       if next-byte == 175 -> next-byte == 176
//       else -> set next-byte's 0th-bit = 0
//
// * Check byte == 186,187 => C/
//   - verify prev-byte == 225
//   - toLower: set next-byte's 0th-bit = 0
//
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
// C/ 90-chars: bit thấp nhất = 0 là viết hoa, 1 là viết thường trừ trường hợp `Ưư`
// - - - - - - - - - - - - -
// 32-chars 225:186:160-191
// 58-chars 225:187:128-185
// - - - - - - - - - - - - -
// 'Ạ'225:186:160 'ạ'225:186:161 'Ả'225:186:162 'ả'225:186:163
// 'Ấ'225:186:164 'ấ'225:186:165 'Ầ'225:186:166 'ầ'225:186:167
// 'Ẩ'225:186:168 'ẩ'225:186:169 'Ẫ'225:186:170 'ẫ'225:186:171
// 'Ậ'225:186:172 'ậ'225:186:173 'Ắ'225:186:174 'ắ'225:186:175
// 'Ằ'225:186:176 'ằ'225:186:177 'Ẳ'225:186:178 'ẳ'225:186:179
// 'Ẵ'225:186:180 'ẵ'225:186:181 'Ặ'225:186:182 'ặ'225:186:183
// 'Ẹ'225:186:184 'ẹ'225:186:185 'Ẻ'225:186:186 'ẻ'225:186:187
// 'Ẽ'225:186:188 'ẽ'225:186:189 'Ế'225:186:190 'ế'225:186:191
//
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

const std = @import("std");

pub fn main() void {
    // const c: []const []const u8 = &.{ "é", "ý", "ú", "í", "ó", "á", "ế", "ứ", "ớ", "ố", "ắ", "ấ", "è", "ỳ", "ù", "ì", "ò", "à", "ề", "ừ", "ờ", "ồ", "ằ", "ầ", "ẻ", "ỷ", "ủ", "ỉ", "ỏ", "ả", "ể", "ử", "ở", "ổ", "ẳ", "ẩ", "ẽ", "ỹ", "ũ", "ĩ", "õ", "ã", "ễ", "ữ", "ỡ", "ỗ", "ẵ", "ẫ", "ẹ", "ỵ", "ụ", "ị", "ọ", "ạ", "ệ", "ự", "ợ", "ộ", "ặ", "ậ" };
    const c: []const []const u8 = &.{ "Ư", "ư", "ậ", "Ạ", "Ậ", "Ỳ", "Ỷ", "Ỹ", "Ỵ" };
    for (c) |s| {
        if (s.len == 2) {
            std.debug.print("'{s}'{d}:{d} ", .{ s, s[0], s[1] });
        } else {
            std.debug.print("'{s}'{d}:{d}:{d} ", .{ s, s[0], s[1], s[2] });
        }
    }

    std.debug.print("\n\n", .{});
    const d: []const u8 = &.{ 195, 196, 197, 198, 186, 187, 225 };
    for (d) |x| {
        std.debug.print("{b}\n", .{x});
    }
}

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
