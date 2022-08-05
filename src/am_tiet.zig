const std = @import("std");
const sds = @import("syllable.zig"); // sds: Syllable Data Structures
const getInitial = @import("am_dau.zig").getInitial;
const getMiddle = @import("am_giua.zig").getMiddle;
const Char = @import("ky_tu.zig").Char;

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

pub fn parseSyllable(bytes: []const u8) sds.Syllable {
    var syll = sds.Syllable.new();
    // chuỗi rỗng hoặc lớn hơn 10 bytes không phải âm tiết utf8
    if (bytes.len == 0 or bytes.len > MAX_SYLLABLE_LEN) return syll;

    var c0: Char = undefined;
    var c1: Char = undefined;

    c0.parse(bytes, 0);
    var idx = c0.len;

    if (bytes.len > 1) {
        // chỉ phân tích âm đầu khi có 2 ký tự trở lên
        // vì âm tiết lúc nào cũng có nguyên âm

        if (idx > 1) { // đ
            syll.am_dau = getInitial(c0.byte1, c0.byte0);
        } else {
            c1.parse(bytes, idx);
            idx += c1.len;
            syll.am_dau = getInitial(c0.byte0, c1.byte0);
        }
    }

    // bỏ qua h của ngh
    if (syll.am_dau == .ng and (bytes[idx] == 'h' or bytes[idx] == 'H')) idx += 1;

    // phân tích âm giữa
    switch (syll.am_dau.len()) {
        0 => { // không có âm đầu

        },
        1 => { // sử dụng lại c1
            c0 = c1;
            c1.parse(bytes, idx);
            idx += c1.len;
        },
        2 => {
            c0.parse(bytes, idx);
            idx += c0.len;

            c1.parse(bytes, idx);
            idx += c1.len;
        },
        else => unreachable,
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
        c1.parse(bytes, idx);
        idx += c1.len;
    }

    syll.am_giua = getMiddle(c0.byte0, c0.byte1, c1.byte0, c1.byte1);

    // xác định thanh điệu
    syll.tone = c0.tone;
    if (syll.tone == ._none) syll.tone = c1.tone;

    std.debug.print(
        "\n     - - - - - - - - - - - - - - - -" ++ "\n{s: >11}: {s: >5} {s: >5} {s: >5} {s: >5}",
        .{ bytes, @tagName(syll.am_dau), @tagName(syll.am_giua), @tagName(syll.am_cuoi), @tagName(syll.tone) },
    );

    return syll;
}
