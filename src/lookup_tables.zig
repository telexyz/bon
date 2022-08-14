// 160 => self.setb1b0t(0, 'a', .f), // 'à'195:160
// 161 => self.setb1b0t(0, 'a', .s), // 'á'195:161
// 163 => self.setb1b0t(0, 'a', .x), // 'ã'195:163

// 168 => self.setb1b0t(0, 'e', .f), // 'è'195:168
// 169 => self.setb1b0t(0, 'e', .s), // 'é'195:169
// 172 => self.setb1b0t(0, 'i', .f), // 'ì'195:172
// 173 => self.setb1b0t(0, 'i', .s), // 'í'195:173

// 178 => self.setb1b0t(0, 'o', .f), // 'ò'195:178
// 179 => self.setb1b0t(0, 'o', .s), // 'ó'195:179
// 181 => self.setb1b0t(0, 'o', .x), // 'õ'195:181

// 185 => self.setb1b0t(0, 'u', .f), // 'ù'195:185
// 186 => self.setb1b0t(0, 'u', .s), // 'ú'195:186
// 189 => self.setb1b0t(0, 'y', .s), // 'ý'195:189
// else => self.setb1b0t(curr_byte, next_byte, ._none),
pub const utf8tv_A = [_]u16{
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0x6103, 0x6101, 0x0000, 0x6105, 0x0000, 0x0000, 0x0000, 0x0000, // 160-167
    0x6503, 0x6501, 0x0000, 0x0000, 0x6903, 0x6901, 0x0000, 0x0000, // 168-175
    0x0000, 0x0000, 0x6F03, 0x6F01, 0x0000, 0x6F05, 0x0000, 0x0000, // 176-183
    0x0000, 0x7503, 0x7501, 0x0000, 0x0000, 0x7901, //                 184-189
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};

// 161 => self.setb1b0t(0, 'a', .j), //   'ạ'225:186:161
// 163 => self.setb1b0t(0, 'a', .r), //   'ả'225:186:163
// 165 => self.setb1b0t(195, 162, .s), // 'ấ'225:186:165
// 167 => self.setb1b0t(195, 162, .f), // 'ầ'225:186:167

// 169 => self.setb1b0t(195, 162, .r), // 'ẩ'225:186:169
// 171 => self.setb1b0t(195, 162, .x), // 'ẫ'225:186:171
// 173 => self.setb1b0t(195, 162, .j), // 'ậ'225:186:173
// 175 => self.setb1b0t(196, 131, .s), // 'ắ'225:186:175

// 177 => self.setb1b0t(196, 131, .f), // 'ằ'225:186:177
// 179 => self.setb1b0t(196, 131, .r), // 'ẳ'225:186:179
// 181 => self.setb1b0t(196, 131, .x), // 'ẵ'225:186:181
// 183 => self.setb1b0t(196, 131, .j), // 'ặ'225:186:183

// 185 => self.setb1b0t(0, 'e', .j), //   'ẹ'225:186:185
// 187 => self.setb1b0t(0, 'e', .r), //   'ẻ'225:186:187
// 189 => self.setb1b0t(0, 'e', .x), //   'ẽ'225:186:189
// 191 => self.setb1b0t(195, 170, .s), // 'ế'225:186:191
// else => self.setInvalid(),
pub const utf8tv_C: [256]u24 = .{
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
    0x006102, 0x000000, 0x006104, 0x000000, 0xC3A201, 0x000000, 0xC3A203, 0x000000, // 161
    0xC3A204, 0x000000, 0xC3A205, 0x000000, 0xC3A202, 0x000000, 0xC48301, 0x000000, // 169
    0xC48303, 0x000000, 0xC48304, 0x000000, 0xC48305, 0x000000, 0xC48302, 0x000000, // 177
    0x006502, 0x000000, 0x006504, 0x000000, 0x006505, 0x000000, 0xC3AA01, // 185-191
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};

// 129 => self.setb1b0t(195, 170, .f), // 'ề'225:187:129
// 131 => self.setb1b0t(195, 170, .r), // 'ể'225:187:131
// 133 => self.setb1b0t(195, 170, .x), // 'ễ'225:187:133
// 135 => self.setb1b0t(195, 170, .j), // 'ệ'225:187:135

// 137 => self.setb1b0t(0, 'i', .r), //   'ỉ'225:187:137
// 139 => self.setb1b0t(0, 'i', .j), //   'ị'225:187:139
// 141 => self.setb1b0t(0, 'o', .j), //   'ọ'225:187:141
// 143 => self.setb1b0t(0, 'o', .r), //   'ỏ'225:187:143

// 145 => self.setb1b0t(195, 180, .s), // 'ố'225:187:145
// 147 => self.setb1b0t(195, 180, .f), // 'ồ'225:187:147
// 149 => self.setb1b0t(195, 180, .r), // 'ổ'225:187:149
// 151 => self.setb1b0t(195, 180, .x), // 'ỗ'225:187:151

// 153 => self.setb1b0t(195, 180, .j), // 'ộ'225:187:153
// 155 => self.setb1b0t(198, 161, .s), // 'ớ'225:187:155
// 157 => self.setb1b0t(198, 161, .f), // 'ờ'225:187:157
// 159 => self.setb1b0t(198, 161, .r), // 'ở'225:187:159
pub const utf8tv_D = [_]u24{
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
    0, 0, 0, 0, //
    0xC3AA03, 0x000000, 0xC3AA04, 0x000000, 0xC3AA05, 0x000000, 0xC3AA02, 0x000000, // 129
    0x006904, 0x000000, 0x006902, 0x000000, 0x006F02, 0x000000, 0x006F04, 0x000000, // 137
    0xC3B401, 0x000000, 0xC3B403, 0x000000, 0xC3B404, 0x000000, 0xC3B405, 0x000000, // 145
    0xC3B402, 0x000000, 0xC6A101, 0x000000, 0xC6A103, 0x000000, 0xC6A104, 0x000000, // 153
    //
    //
    0xC6A105, 0x000000, 0xC6A102, 0x000000, 0x007502, 0x000000, 0x007504, 0x000000, // 161
    0xC6B001, 0x000000, 0xC6B003, 0x000000, 0xC6B004, 0x000000, 0xC6B005, 0x000000, // 169
    0xC6B002, 0x000000, 0x007903, 0x000000, 0x007902, 0x000000, 0x007904, 0x000000, // 177
    0x007905, // 185
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};
// 161 => self.setb1b0t(198, 161, .x), // 'ỡ'225:187:161
// 163 => self.setb1b0t(198, 161, .j), // 'ợ'225:187:163
// 165 => self.setb1b0t(0, 'u', .j), //   'ụ'225:187:165
// 167 => self.setb1b0t(0, 'u', .r), //   'ủ'225:187:167

// 169 => self.setb1b0t(198, 176, .s), // 'ứ'225:187:169
// 171 => self.setb1b0t(198, 176, .f), // 'ừ'225:187:171
// 173 => self.setb1b0t(198, 176, .r), // 'ử'225:187:173
// 175 => self.setb1b0t(198, 176, .x), // 'ữ'225:187:175

// 177 => self.setb1b0t(198, 176, .j), // 'ự'225:187:177
// 179 => self.setb1b0t(0, 'y', .f), //   'ỳ'225:187:179
// 181 => self.setb1b0t(0, 'y', .j), //   'ỵ'225:187:181
// 183 => self.setb1b0t(0, 'y', .r), //   'ỷ'225:187:183

// 185 => self.setb1b0t(0, 'y', .x), //   'ỹ'225:187:185

const std = @import("std");
const testing = std.testing;
const n = std.math.maxInt(u8) + @as(usize, 1);

test "utf8tv_A" {
    try testing.expectEqual(utf8tv_A[n - 1], 0);
    try testing.expectEqual(utf8tv_A.len, n);
}
test "utf8tv_C" {
    try testing.expectEqual(utf8tv_C[n - 1], 0);
    try testing.expectEqual(utf8tv_C.len, n);
}
test "utf8tv_D" {
    try testing.expectEqual(utf8tv_D[n - 1], 0);
    try testing.expectEqual(utf8tv_D.len, n);
    try testing.expectEqual(utf8tv_D[129], 0xC3AA03);
}
