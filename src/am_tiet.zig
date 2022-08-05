const std = @import("std");
const sds = @import("syllable.zig"); // sds: Syllable Data Structures
const getInitial = @import("am_dau.zig").getInitial;
const getMiddle = @import("am_giua.zig").getMiddle;
const getFinal = @import("am_cuoi.zig").getFinal;
const Char = @import("ky_tu.zig").Char;
const cmn = @import("common.zig");

pub fn main() void {
    cmn.printSyllTableHeaders();

    // _ = parseSyllable("GÀN");
    // _ = parseSyllable("GặN");
    // _ = parseSyllable("GIừp");
    // _ = parseSyllable("nGhiÊng");
    // _ = parseSyllable("nGiêng");
    // _ = parseSyllable("đim");
    // _ = parseSyllable("gĩm");
    // _ = parseSyllable("ĩm");

    _ = parseSyllable("nghúýếng");
    _ = parseSyllable("giếng");
    _ = parseSyllable("gia");
    _ = parseSyllable("a");
}

const MAX_SYLL_BYTES_LEN = 12;

pub fn parseSyllable(bytes: []const u8) sds.Syllable {
    var syll = sds.Syllable.new();
    // chuỗi rỗng hoặc lớn hơn 10 bytes không phải âm tiết utf8
    if (bytes.len == 0 or bytes.len > MAX_SYLL_BYTES_LEN) return syll;

    var c0: Char = undefined;
    var c1: Char = undefined;

    // phân tách ký tự đầu tiên
    c0.parse(bytes, 0);
    var idx = c0.len;

    if (bytes.len > 1) {
        // chỉ phân tích âm đầu khi có 2 ký tự trở lên
        // vì âm tiết lúc nào cũng có nguyên âm, nên khi âm tiết
        // có 1 ký tự thì chắc chắn đó phải là nguyên âm

        if (idx > 1) { // đ
            syll.am_dau = getInitial(c0.byte1, c0.byte0);
        } else {
            c1.parse(bytes, idx);
            idx += c1.len;
            syll.am_dau = getInitial(c0.byte0, c1.byte0);
        }

        // bỏ qua h của ngh
        if (syll.am_dau == .ng and idx < bytes.len and
            (bytes[idx] == 'h' or bytes[idx] == 'H')) idx += 1;

        // gi nhưng i là âm giữa vì âm sau là phụ âm cuối
        if (syll.am_dau == .gi and getFinal(0, bytes[idx]) != ._none) syll.am_dau = .g;
    }

    // PHÂN TÍCH ÂM GIỮA
    switch (syll.am_dau.len()) {
        0 => { // không có âm đầu
            c1.parse(bytes, idx);
            idx += c1.len;
        },
        1 => { // âm đầu 1 ký tự => sử dụng lại c1
            c0 = c1;
            c1.parse(bytes, idx);
            idx += c1.len;
        },
        2 => { // âm đầu 2 ký tự
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

    // parse âm cuối
    var valid_final = true;
    var no_more = false;

    if (syll.am_giua.len() < 3) { // nguyên âm đơn
        // std.debug.print("\n >>>>> sử dụng lại char của phân tích âm giữa <<<<< \n", .{});
        c0 = c1;
    } else if (idx < bytes.len) {
        // parse char mới
        c0.parse(bytes, idx);
        idx += c0.len;
    } else {
        no_more = true;
        valid_final = true;
        syll.am_cuoi = ._none;
    }

    // khả năng âm cuối có hai ký tự
    if (idx < bytes.len) {
        // std.debug.print("\n >>>>> âm cuối có thêm 1 ký tự nữa <<<<< \n", .{});
        c1.parse(bytes, idx);
        idx += c1.len;
        if (idx < bytes.len) {
            // phần còn lại có nhiều hơn 2 ký tự
            syll.am_cuoi = ._none;
            valid_final = false;
        } else {
            syll.am_cuoi = getFinal(c0.byte0, c1.byte0);
            valid_final = (syll.am_cuoi != ._none); // parse không ra
        }
    } else if (!no_more) {
        // khả năng âm cuối có 1 ký tự
        syll.am_cuoi = getFinal(0, c0.byte0);
        valid_final = (syll.am_cuoi != ._none);
    }

    // TODO: cần check can_be_vietnamese từ khâu initial và middle
    syll.can_be_vietnamese = valid_final;

    cmn.printSyllParts(bytes, syll);

    return syll;
}
