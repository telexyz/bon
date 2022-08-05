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
