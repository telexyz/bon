// const ztracy = @import("ztracy");
const std = @import("std");
const sds = @import("syllable.zig"); // sds: Syllable Data Structures
const getInitial = @import("am_dau.zig").getInitial;

const getMiddle = @import("am_giua.zig").getMiddle;
const getSingleMiddle = @import("am_giua.zig").getSingleMiddle;

const getFinal = @import("am_cuoi.zig").getFinal;
const isFinalConsonant = @import("am_cuoi.zig").isFinalConsonant;

const Char = @import("ky_tu.zig").Char;
const cmn = @import("common.zig");

fn _parse(bytes: []const u8) void {
    cmn.printSyll(bytes, parseSyllable(bytes));
}

pub fn main() void {
    cmn.printSyllTableHeaders();

    // _parse("GÀN");
    // _parse("GặN");
    // _parse("GIừp");
    // _parse("nGhiÊng");
    // _parse("nGiêng");
    // _parse("đim");
    // _parse("ĩm");
    // _parse("nghúýếng");
    // _parse("giếng");
    // _parse("gĩ");
    // _parse("ginh");
    // _parse("gim");
    // _parse("giâ");
    // _parse("a");

    // cmn.printSepLine();
    // _parse("gĩmmmm");
    // _parse("đ");
    // _parse("g");
    // _parse("nnnn");

    // cmn.printSepLine();
    // _parse("khủya");
    // _parse("tuảnh");
    // _parse("míach");
    // _parse("dưạng");
    // _parse("duơ");

    // cmn.printSepLine();
    // _parse("qa");
    // _parse("qui");
    // _parse("que");
    // _parse("quy");
    // _parse("cua");
    // _parse("qua");
    // // q chỉ đi với + âm đệm u, có quan điểm `qu` là 1 âm độc lập, quốc vs cuốc
    // _parse("quốc");
    // _parse("cuốc");
    // _parse("Thuở");

    // cmn.printSepLine();
    cmn.DEBUGGING = true;
    _parse("nh");
    _parse("nz");
    _parse("ai");
    _parse(" ̣");
    _parse(" ̣ ");
    // _parse("quẹc");
    // _parse("cuyễn");
    // _parse("quô");
    // _parse("quyêm");

    // unicode tổ hợp
    // "́ hệ của cái gia đình này và chắc chắn ră�"
    // const token = "của";
    // _parse(token);
    // for (token) |c, i| {
    //     std.debug.print("\n{d}-{d} {b}", .{ i, c, c });
    // }
}

const MAX_SYLL_BYTES_LEN = 12;

pub inline fn parseSyllable(bytes: []const u8) sds.Syllable {
    var syll = _parseSyllable(bytes);
    return syll.normalize();
}

pub fn _parseSyllable(bytes: []const u8) sds.Syllable {
    // const tracy_zone = ztracy.ZoneNC(@src(), "parseSyllable", 0x00_ff_00_00);
    // defer tracy_zone.End();

    var syll = sds.Syllable.new();
    // chuỗi rỗng hoặc lớn hơn 12 bytes không phải âm tiết utf8
    if (bytes.len == 0 or bytes.len > MAX_SYLL_BYTES_LEN) return syll; // NOT SYLLABLE

    const bytes_len = bytes.len;
    var c0: Char = undefined;
    var c1: Char = undefined;

    // phân tách ký tự đầu tiên
    c0.parse(bytes, 0);
    var idx = c0.len;

    // PHÂN TÍCH PHỤ ÂM ĐẦU
    // - - - - - - - - - -
    if (!c0.vowel) { // ko phải nguyên âm
        // VALIDATE: chỉ có phụ âm đầu => ko có nguyên âm
        if (idx == bytes_len) {
            syll.can_be_vietnamese = false; // vì ko có nguyên âm
            return syll; // NOT SYLLABLE
        }

        if (c0.byte1 == 196 and c0.byte0 == 145) {
            syll.am_dau = .zd; // đ'196:145
        } else { // lấy thêm 1 ký tự nữa để kiểm tra phụ âm đôi
            c1.parse(bytes, idx);
            idx += c1.len;
            syll.am_dau = if (c1.tone != ._none and c0.byte0 != 'q')
                // nếu char có thanh điệu thì thuộc về nguyên âm, ko áp dụng với qù
                // => phân tích phụ âm đầu bằng char đầu tiên thôi
                getInitial(c0.byte0, c0.byte1)
            else
                getInitial(c0.byte0, c1.byte0);
        }

        // bỏ qua h của ngh
        if (syll.am_dau == .ng and idx < bytes_len and
            (bytes[idx] == 'h' or bytes[idx] == 'H'))
        {
            idx += 1;
            if (idx == bytes_len) {
                // ko có nguyên âm nên ko phải âm tiết
                syll.can_be_vietnamese = false;
                return syll; // DONE
            }
        }

        // gi nhưng i là âm giữa vì âm sau là phụ âm cuối
        if (syll.am_dau == .gi) {
            syll.tone = c1.tone;

            if (idx == bytes_len) { // => `gi`, `gì`, `gỉ`, `gĩ`, `gị`
                syll.am_giua = .i;
                syll.am_cuoi = ._none;
                syll.can_be_vietnamese = true;
                return syll; // DONE
            }
            if (isFinalConsonant(bytes[idx])) {
                if (bytes_len > idx + 2) return syll; // NOT SYLLABLE
                // vì không có final nào > 2-bytes

                syll.am_dau = .g;
                syll.am_giua = .i;
                syll.tone = c1.tone;

                // Xác định âm cuối nhanh rồi trả về kết quả
                const curr = 0b00100000 | bytes[idx]; // toLower ascii
                const next = if (idx + 1 < bytes_len) 0b00100000 | bytes[idx + 1] else 0;
                syll.am_cuoi = getFinal(curr, next);
                syll.can_be_vietnamese = syll.am_cuoi != ._none;
                return syll; // DONE
            }
        }
    }

    // VALIDATION
    if (syll.am_dau.len() == bytes_len) { // => ko có âm giữa
        syll.can_be_vietnamese = false;
        return syll; // DONE
    }

    // PHÂN TÍCH ÂM GIỮA
    // - - - - - - - - -
    switch (syll.am_dau.len()) {
        // 0 => { // không có âm đầu
        // },
        1 => { // âm đầu 1 ký tự => sử dụng lại c1
            if (cmn.DEBUGGING) std.debug.print("\n(( MIDDLE: sử dụng lại `{c}` ))", .{c1.byte0});
            c0 = c1;
        },
        2 => { // âm đầu 2 ký tự
            c0.parse(bytes, idx);
            idx += c0.len;
        },
        else => {},
    }

    var MIDDLE_HAS_oa_oe_oo_uy = false;
    if (idx == bytes_len) { // âm giữa một ký tự và ko có âm cuối

        if (cmn.DEBUGGING) std.debug.print("\n(( MIDDLE: chỉ còn 1 ký tự để pt âm giữa ))", .{});

        syll.am_giua = if (c0.vowel) // kiểm tra c0 có là nguyên âm k trc khi parse
            getSingleMiddle(c0.byte0, c0.byte1)
        else
            ._none;

        if (syll.am_giua != ._none) { // âm tiết phải có âm giữa
            syll.can_be_vietnamese = true;
            syll.tone = c0.tone;
            syll.am_cuoi = ._none;
        }

        return syll; // DONE
        //
    } else { // âm giữa có thể có 2 ký tự

        if (c0.vowel and idx < bytes_len) {
            c1.parse(bytes, idx);
            idx += c1.len;
        }

        if (cmn.DEBUGGING) {
            const str: []const u8 = &.{ c1.byte1, c1.byte0 };
            std.debug.print("\n(( MIDDLE: lấy thêm ký tự `{s}` ))", .{str});
        }

        if (syll.am_dau == ._none and c0.byte0 == 'y' and c1.byte0 == 170 and c1.byte1 == 195) {
            if (cmn.DEBUGGING) std.debug.print("\n(( MIDDLE: yê => iê ))", .{});
            c0.byte0 = 'i';
        }

        if ((c0.byte0 == 'u' and c1.byte0 == 'y') or
            (c0.byte0 == 'o' and (c1.byte0 == 'a' or c1.byte0 == 'e' or c1.byte0 == 'o')))
        {
            if (cmn.DEBUGGING) std.debug.print("\n(( MIDDLE: oa oe oo uy ))", .{});
            MIDDLE_HAS_oa_oe_oo_uy = true;

            // Đẩy bytes vào char0
            c0.byte1 = c0.byte0;
            c0.byte0 = c1.byte0;

            // Gán thanh điệu
            if (syll.tone == ._none) syll.tone = c1.tone;
            if (syll.tone == ._none) syll.tone = c0.tone;

            if (idx == bytes_len) { // không có ký tự tiếp theo
                if (cmn.DEBUGGING) std.debug.print("\n(( MIDDLE: không có ký tự tiếp theo ))", .{});
                syll.am_giua = getSingleMiddle(c0.byte0, c0.byte1);
                syll.am_cuoi = ._none;
                syll.can_be_vietnamese = true;
                return syll; // DONE
            } else {
                c1.parse(bytes, idx); // Lấy ký tự tiếp theo
                idx += c1.len;

                if (cmn.DEBUGGING) {
                    const str: []const u8 = &.{ c1.byte1, c1.byte0 };
                    std.debug.print("\n(( MIDDLE_HAS_oa_oe_oo_uy: lấy thêm ký tự `{s}` ))", .{str});
                }
            }
        }

        syll.am_giua = if (c0.vowel) // kiểm tra c0 có là nguyên âm trước khi parse
            getMiddle(c0.byte0, c0.byte1, c1.byte0, c1.byte1)
        else
            ._none;

        // ưu tiên LẤY THANH ĐIỆU trên nguyên âm thứ 2
        if (c1.tone != ._none) syll.tone = c1.tone;
    }
    // rồi mới LẤY THANH ĐIỆU trên nguyên âm thứ nhất
    if (syll.tone == ._none) syll.tone = c0.tone;

    // VALIDATE: Âm tiết bắt buộc phải có âm giữa
    if (syll.am_giua == ._none) {
        syll.can_be_vietnamese = false;
        return syll; // NOT SYLLABLE
    }

    // PHÂN TÍCH ÂM CUỐI
    // - - - - - - - - -

    // Xác định ký tự thứ nhất của âm cuối
    // NẾU là nguyên âm đơn hoặc oa_oe_oo_uy
    const am_giua_len = syll.am_giua.len();
    if (am_giua_len < 2 or (MIDDLE_HAS_oa_oe_oo_uy and am_giua_len == 2)) {
        c0 = c1; // THÌ sử dụng lại char cuối của phân tích âm giữa
        if (cmn.DEBUGGING) std.debug.print("\n(( FINAL: sử dụng lại `{c}` ))", .{c1.byte0});
    } else if (idx < bytes_len) { // NẾU còn bytes để parse
        c0.parse(bytes, idx); // THÌ parse char mới
        idx += c0.len;
        if (cmn.DEBUGGING) std.debug.print("\n(( FINAL: lấy thêm ký tự `{c}` ))", .{c1.byte0});
    } else {
        if (cmn.DEBUGGING) std.debug.print("\n(( FINAL: ko có âm cuối ))", .{});

        // BẤT QUY TẮC
        if (syll.am_giua == .ui) {
            syll.am_giua = .u;
            syll.am_cuoi = .i;
        } else {
            syll.am_cuoi = ._none;
        }

        syll.can_be_vietnamese = true;
        return syll; // DONE vì ko có phụ âm cuối
    }

    if (idx < bytes_len) { // Xác định ký tự thứ hai của âm cuối
        c1.parse(bytes, idx); // NẾU lấy ký tự tiếp theo
        idx += c1.len;
        if (idx < bytes_len) { // MÀ vẫn còn 1 dữ liệu
            // THÌ còn lại có nhiều hơn 2 ký tự
            syll.am_cuoi = ._none;
            syll.can_be_vietnamese = false;
            return syll; // DONE vì ko hợp lệ!
        }
    } else { // chỉ có 1 ký tự
        c1.byte0 = 0; // để phân tích đúng âm cuối có 1 ký tự
    }

    syll.am_cuoi = getFinal(c0.byte0, c1.byte0);

    // TODO: cần check can_be_vietnamese từ khâu initial và middle
    // VALIDATE khi parse tới đây bắt buộc phải có âm cuối
    // vì các bước phân tích trên đã bao gồm trường hợp ko có âm cuối
    syll.can_be_vietnamese = syll.am_cuoi != ._none;

    return syll; // DONE
}
