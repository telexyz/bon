const std = @import("std");
const expect = std.testing.expect;
const fmt = std.fmt;

pub const AmDau = enum {
    // 25 âm đầu
    _none,
    b,
    c, // Viết thành k trước các nguyên âm e, ê, i (iê, ia) => cần kiểm tra từ vay mượn Bắc Kạn
    d,
    q, // => c; q chỉ đi với + âm đệm u
    g,
    h,
    l,
    m,
    n,
    p, // 10
    r,
    s,
    t,
    v,
    x,
    ch,
    gi, // dùng như âm d, `gì` viết đúng, đủ là `giì`, đọc là `dì`
    kh,
    ng,
    nh, // 20th
    ph,
    th,
    tr,
    zd, // âm đ, 24th
    // Transit states: gh, ngh trước các nguyên âm e, ê, i, iê (ia).
    gh, // => g
    ngh, // ng
    // NOTE: `q` hoặc `qu` chắc chắn là 1 âm độc lập như trong, quốc vs cuốc và quơ vs cua (quơ tay)
    // - Dùng `q` thì hợp với cách phiên âm
    // - Dùng `qu` thì đỡ công phân tích

    pub fn len(self: AmDau) u8 {
        return switch (@enumToInt(self)) {
            0 => 0,
            1...15 => 1,
            26 => 3, // ngh
            else => 2,
        };
    }
    pub fn isSaturated(self: AmDau) bool {
        return switch (self) {
            .c, .d, .g, .n, .p, .t, ._none, .ng => false,
            else => return true,
        };
    }
    pub fn noMark(self: AmDau) AmDau {
        return switch (self) {
            .zd => .d,
            else => self,
        };
    }
};

test "Enum AmDau" {
    try expect(AmDau.b.len() == 1);
    try expect(AmDau.x.len() == 1);
    try expect(AmDau.ch.len() == 2);
    try expect(AmDau.tr.len() == 2);
    try expect(AmDau._none.len() == 0);
    try expect(AmDau._none.isSaturated() == false);
    try expect(AmDau.zd.isSaturated() == true);
}

// https://tieuluan.info/ti-liu-bdhsg-mn-ting-vit-lp-4-5.html?page=12
// 2. Vần gồm có 3 phần: âm đệm, âm chính, âm cuối.
// - Âm đệm được ghi bằng con chữ u và o.
//     + Ghi bằng con chữ o khi đứng trước các nguyên âm: a, ă, e.
//     + Ghi bằng con chữ u khi đứng trước các nguyên âm y, ê, ơ, â.
//
// - Âm đệm không xuất hiện sau các phụ âm b, m, v, ph, n, r, g. Trừ các trường hợp:
//     + sau ph, b: thùng phuy, voan, ô tô buýt (là từ nước ngoài)
//     + sau n: thê noa, noãn sào (2 từ Hán Việt)
//     + sau r: roàn roạt (1 từ)
//     + sau g: goá (1 từ)
//
// Trong Tiếng Việt, nguyên âm nào cũng có thể làm âm chính của tiếng.
// - Các nguyên âm đơn: (11 nguyên âm ghi ở trên)
//
// - Các nguyên âm đôi: Có 3 nguyên âm đôi và được tách thành 8 nguyên âm sau:
//
// * iê:
//   - Ghi bằng ia khi phía trước không có âm đệm và phía sau không có âm cuối
//     (VD: mía, tia, kia,...)
//   - Ghi bằng yê khi phía trước có âm đệm hoặc không có âm nào, phía sau có âm cuối
//     (VD: yêu, chuyên,...)
//   - Ghi bằng ya khi phía trước có âm đệm và phía sau không có âm cuối (VD: khuya...)
//   - Ghi bằng iê khi phía trước có phụ âm đầu, phía sau có âm cuối (VD: tiên, kiến...)
//
// + uơ:
//   - Ghi bằng ươ khi sau nó có âm cuối ( VD: mượn,...)
//   - Ghi bằng ưa khi phía sau nó không có âm cuối (VD: mưa,...)
//
// + uô:
//   - Ghi bằng uô khi sau nó có âm cuối (VD: muốn,...)
//   - Ghi bằng ua khi sau nó không có âm cuối (VD: mua,...)

pub const AmGiua = enum {
    // 26 âm giữa (âm đệm_nguyên âm) + 2 âm hỗ trợ rút gọn = 28
    a, // 0th
    e,
    i,
    o,
    u,
    y, // nhập làm một với i? í ới, người í, người Ý, người ý ??? => ko nên
    az, // â
    aw, // ă
    ez, // ê
    oz, // ô
    ow, // ơ // 10th
    uw, // ư

    oa,
    oe,
    oo, // boong
    uy, // 15th
    ua, // => `oa` với qua => coa, xử lý ở am_tiet.zig
    uo, // quọ

    iez, //  iê <= ie (tiên <= tien, tieen, tiezn)
    oaw, //  oă (loắt choắt)
    uaz, //  uâ (tuân <= tuan), ua mà có âm cuối chuyển thanh uaz; 20th
    uez, //  uê <= ue (tuê <= tue) tuềnh toàng, que => coe
    uoz, //  uô
    uow, //  ươ
    u_ow, // uơ <= quơ, huơ, thuở
    uyez, // uyê // 25th

    // Hỗ trợ
    // - - - - - - - - - - - - -
    ah, // giúp rút gọn âm cuối
    oah, // giúp rút gọn âm cuối // 27

    // Transit States
    // - - - - - - - - - - - - - - - - - - - - -
    ue, // => `oe` với que => coe
    ui, // => `uy` với qui => cuy // 29

    _none, // none chỉ để đánh dấu chưa parse, sau bỏ đi

    pub fn len(self: AmGiua) u8 {
        return switch (@enumToInt(self)) {
            0...11 => 1,
            25 => 3,
            30 => 0,
            else => 2,
        };
    }

    pub fn startWithIY(self: AmGiua) bool {
        return switch (self) {
            .i, .y, .iez => true,
            else => false,
        };
    }
    pub fn hasMark(self: AmGiua) bool {
        return switch (self) {
            .az, .aw, .ez, .uw, .oz, .ow, .oaw, .uaz, .uez, .uow, .uoz, .uaw, .iez, .uyez => true,
            else => false,
        };
    }
    pub fn isSaturated(self: AmGiua) bool {
        if (self.len() == 4 or self.len() == 3) return true;
        if (self.len() == 2) {
            switch (self) {
                .oa, .oo, .ua, .uw, .uy => { // .uo,
                    return false;
                },
                else => {
                    return true;
                },
            }
        }
        return false;
    }
    pub fn hasAmDem(self: AmGiua) bool {
        return switch (self) {
            .uaz, .uez, .uy, .uyez => true,
            .oa, .oaw, .oe, .oo => true,
            else => false,
        };
    }
};

test "Enum AmGiua" {
    try expect(AmGiua.a.len() == 1);
    try expect(AmGiua.y.len() == 1);
    try expect(AmGiua.az.len() == 1);
    try expect(AmGiua.uy.len() == 2);
    try expect(AmGiua.iez.len() == 2);
    try expect(AmGiua.uow.len() == 2);
    try expect(AmGiua.uyez.len() == 3);
    try expect(AmGiua._none.len() == 0);
}

/// * Âm cuối:
/// - Các phụ âm cuối vần : p, t, c (ch), m, n, ng (nh)
/// - 2 bán âm cuối vần : i (y), u (o)
pub const AmCuoi = enum {
    // 13 âm cuối
    _none, // 0
    i,
    u,
    m,
    n,
    ng,
    c, // 6
    p,
    t, // 8
    ch,
    nh,
    y,
    o,
    pub fn len(self: AmCuoi) u8 {
        return switch (@enumToInt(self)) {
            0 => 0,
            5, 9, 10 => 2,
            else => 1,
        };
    }
    pub fn isSaturated(self: AmCuoi) bool {
        if (self.len() == 2) return true;
        if (self.len() == 1) {
            switch (self) {
                .c, .n => {
                    return false;
                },
                else => {
                    return true;
                },
            }
        }
        return false;
    }
    pub fn isStop(self: AmCuoi) bool {
        return switch (self) {
            .c, .t, .p, .ch => true,
            else => false,
        };
    }
};

test "Enum AmCuoi.len" {
    try expect(AmCuoi.c.len() == 1);
    try expect(AmCuoi.y.len() == 1);
    try expect(AmCuoi.ch.len() == 2);
    try expect(AmCuoi.nh.len() == 2);
    try expect(AmCuoi._none.len() == 0);
}

pub const Tone = enum(u3) {
    // 6 thanh
    _none,
    s,
    j,
    f,
    r,
    x,
    pub fn len(self: Tone) u8 {
        return if (self == ._none) 0 else 1;
    }
    pub fn isSaturated(self: Tone) bool {
        return self != ._none;
    }
    pub fn isStop(self: Tone) bool {
        return switch (self) {
            .s, .j => true,
            else => false,
        };
    }
    pub fn canBeStop(self: Tone) bool {
        return switch (self) {
            // add ._none to support no-tone vi syllable
            .s, .j, ._none => true,
            else => false,
        };
    }
    pub fn isHarsh(self: Tone) bool {
        return switch (self) {
            .x, .j => true,
            else => false,
        };
    }
};

test "Enum Tone.isHarsh" {
    try expect(Tone.x.isHarsh() == true);
    try expect(Tone.j.isHarsh() == true);
    try expect(Tone.s.isHarsh() == false);
}

pub const Syllable = struct {
    am_dau: AmDau,
    am_giua: AmGiua,
    am_cuoi: AmCuoi,
    tone: Tone,
    can_be_vietnamese: bool,
    normalized: bool = false,

    pub const UniqueId = u15;
    pub const Utf8Buff = [MAXX_BYTES]u8;

    pub const MAXX_BYTES: usize = 9;
    pub const MAXX_AM_DAU: UniqueId = 25;
    pub const MAXX_AM_GIUA: UniqueId = 28;
    pub const MAXX_AM_CUOI_TONE: UniqueId = 42;
    pub const MAXX_ID: UniqueId = MAXX_AM_DAU * MAXX_AM_GIUA * MAXX_AM_CUOI_TONE; // 29400

    pub inline fn hasMark(self: Syllable) bool {
        return self.am_dau == .zd or self.am_giua.hasMark();
    }

    pub inline fn hasTone(self: Syllable) bool {
        return self.tone != ._none;
    }

    pub inline fn hasMarkOrTone(self: Syllable) bool {
        return self.hasMark() or self.hasTone();
    }

    pub fn normalize(self: *Syllable) void {
        // std.debug.print("\n!!!! normalizing !!!!\n", .{});
        if (self.normalized) return;

        switch (self.am_giua) {
            .ui => if (self.am_dau != .q) {
                self.can_be_vietnamese = false;
                return;
            },
            .ue => if (self.am_dau != .q) {
                self.can_be_vietnamese = false;
                return;
            },
            else => {},
        }

        switch (self.am_dau) {
            .q => {
                switch (self.am_giua) {
                    .uoz => {
                        if (self.am_cuoi == ._none) self.can_be_vietnamese = false;
                    },
                    .ua => { // => `oa` với qua => coa,
                        self.am_dau = .c;
                        self.am_giua = .oa;
                    },
                    .ue => { // => `oe` với que => coe
                        self.am_dau = .c;
                        self.am_giua = .oe;
                    },
                    .ui => { // => `uy` với qui => cuy
                        self.am_dau = .c;
                        self.am_giua = .uy;
                    },

                    .u => if (self.am_cuoi == .i) {
                        // q u i =>  c u y
                        self.am_dau = .c;
                        self.am_cuoi = ._none;
                        self.am_giua = .uy;
                    },
                    else => {},
                }
            },
            .gi => {
                if (self.am_giua == .ez and self.am_cuoi != ._none)
                    self.am_giua = .iez;
            },
            .ngh => self.am_dau = .ng, // ngh => ng
            .gh => self.am_dau = .g, // gh => g
            .g => {
                if (self.am_giua == .i and self.am_cuoi == ._none)
                    self.am_dau = .gi;
            },
            // phân biệt gì ghì, gìm ghìm
            // gì => gi+ì (dì), gìm => gi+ìm (dìm), `gi` đọc là `d`
            // ghìm, `gh` đọc là `g`
            // https://vtudien.com/viet-viet/dictionary/nghia-cua-tu-gìm
            // https://vtudien.com/viet-viet/dictionary/nghia-cua-tu-ghìm
            else => {},
        }

        self.normalized = true;
    }

    pub fn toId(self: *Syllable) UniqueId {
        std.debug.assert(self.normalized);

        var am_giua = self.am_giua;
        var am_cuoi = self.am_cuoi;

        switch (am_cuoi) {
            //  a  y =>  aw i
            //  az y =>  az i
            // oa  y => oaw i
            // uaz y => uaz i
            .y => {
                am_cuoi = .i;
                if (am_giua == .a) am_giua = .aw else if (am_giua == .oa) am_giua = .oaw;
            },
            //  a o =>  aw u
            //  e o =>  e  u
            // oa o => oaw u
            // oe o => oe  u
            .o => {
                am_cuoi = .u;
                if (am_giua == .a) am_giua = .aw;
                if (am_giua == .oa) am_giua = .oaw;
            },
            //  ez nh =>  ez ng
            //  i  nh =>  i  ng
            // uez nh => uez ng
            // uy  nh => uy  ng
            //  a  nh =>  ah ng
            // oa  nh => oah ng
            .nh => {
                am_cuoi = .ng;
                if (am_giua == .a) am_giua = .ah else if (am_giua == .oa) am_giua = .oah;
            },
            //  ez ch =>  ez c
            //  i  ch =>  i  c
            // uez ch => uez c
            // uy  ch => uy  c
            //  a  ch =>  ah c
            // oa  ch => oah c
            .ch => {
                am_cuoi = .c;
                if (am_giua == .a) am_giua = .ah else if (am_giua == .oa) am_giua = .oah;
            },
            else => {},
        }

        // Calculate am_cuoi + tone id
        const am_cuoi_id = @intCast(UniqueId, @enumToInt(am_cuoi));
        const tone = @intCast(UniqueId, @enumToInt(self.tone));
        // act: am_cuoi + tone
        // Vì các âm cuối ch, nh đã được chuyển thành c và ng nên
        // am_cuoi_id > 5 thì chắc chắn đó là âm đóng `c, ch, p, t`
        const act = if (am_cuoi_id < 6)
            am_cuoi_id * 6 + tone
        else // am_cuoi `c, ch, p, t` only 2 tone s, j allowed
            36 + (am_cuoi_id - 6) * 2 + (tone - 1);
        // Validate act
        std.debug.assert(act < MAXX_AM_CUOI_TONE);

        const am_dau_id = @enumToInt(self.am_dau);
        const am_giua_id = @enumToInt(am_giua);

        // Validate am_dau and am_giua
        std.debug.assert(@enumToInt(self.am_dau) < MAXX_AM_DAU);
        if (@enumToInt(am_giua) >= MAXX_AM_GIUA) std.debug.print("\n >> {} <<\n", .{self}); // DEBUG
        std.debug.assert(@enumToInt(am_giua) < MAXX_AM_GIUA);

        return (@intCast(UniqueId, am_dau_id) * MAXX_AM_CUOI_TONE * MAXX_AM_GIUA) +
            (@intCast(UniqueId, am_giua_id) * MAXX_AM_CUOI_TONE) + act;
    }

    pub fn newFromId(id: UniqueId) Syllable {
        std.debug.assert(id < Syllable.MAXX_ID);

        var x = id / MAXX_AM_CUOI_TONE; // get rid of am_cuoi+tone
        var syllable = Syllable{
            .am_dau = @intToEnum(AmDau, @truncate(u5, x / MAXX_AM_GIUA)),
            .am_giua = @intToEnum(AmGiua, @truncate(u5, @rem(x, MAXX_AM_GIUA))),
            .can_be_vietnamese = true,
            .am_cuoi = ._none,
            .tone = ._none,
        };
        x = @rem(id, MAXX_AM_CUOI_TONE); // am_cuoi+tone
        if (x < 36) {
            syllable.am_cuoi = @intToEnum(AmCuoi, @truncate(u4, x / 6));
            syllable.tone = @intToEnum(Tone, @truncate(u3, @rem(x, 6)));
        } else { // unpacking
            x -= 36;
            syllable.am_cuoi = @intToEnum(AmCuoi, @truncate(u4, x / 2 + 6));
            syllable.tone = @intToEnum(Tone, @truncate(u3, @rem(x, 2) + 1));
        }

        //  a  y <=  aw i
        //  az y <=  az i
        // oa  y <= oaw i
        // uaz y <= uaz i
        if (syllable.am_cuoi == .i) switch (syllable.am_giua) {
            .aw => {
                syllable.am_cuoi = .y;
                syllable.am_giua = .a;
                return syllable;
            },
            .oaw => {
                syllable.am_cuoi = .y;
                syllable.am_giua = .oa;
                return syllable;
            },
            .az, .uaz => {
                syllable.am_cuoi = .y;
                return syllable;
            },
            else => return syllable,
        };
        //  a o <=  aw u
        //  e o <=   e u
        // oa o <= oaw u
        // oe o <=  oe u
        if (syllable.am_cuoi == .u) switch (syllable.am_giua) {
            .aw => {
                syllable.am_cuoi = .o;
                syllable.am_giua = .a;
                return syllable;
            },
            .oaw => {
                syllable.am_cuoi = .o;
                syllable.am_giua = .oa;
                return syllable;
            },
            .e, .oe => {
                syllable.am_cuoi = .o;
                return syllable;
            },
            else => return syllable,
        };
        //  ez nh <=  ez ng
        //  i  nh <=  i  ng
        // uez nh <= uez ng
        // uy  nh <= uy  ng
        //  a  nh <=  ah ng
        // oa  nh <= oah ng
        if (syllable.am_cuoi == .ng) switch (syllable.am_giua) {
            .ez, .i, .uez, .uy => {
                syllable.am_cuoi = .nh;
                return syllable;
            },
            .ah => {
                syllable.am_giua = .a;
                syllable.am_cuoi = .nh;
                return syllable;
            },
            .oah => {
                syllable.am_giua = .oa;
                syllable.am_cuoi = .nh;
                return syllable;
            },
            else => return syllable,
        };
        //  ez ch <=  ez c
        //  i  ch <=  i  c
        // uez ch <= uez c
        // uy  ch <= uy  c
        //  a  ch <=  ah c
        // oa  ch <= oah c
        if (syllable.am_cuoi == .c) switch (syllable.am_giua) {
            .ez, .i, .uez, .uy => {
                syllable.am_cuoi = .ch;
                return syllable;
            },
            .ah => {
                syllable.am_giua = .a;
                syllable.am_cuoi = .ch;
                return syllable;
            },
            .oah => {
                syllable.am_giua = .oa;
                syllable.am_cuoi = .ch;
                return syllable;
            },
            else => return syllable,
        };
        //
        return syllable;
    }

    pub fn new() Syllable {
        return .{
            .am_dau = ._none,
            .am_giua = ._none,
            .am_cuoi = ._none,
            .tone = ._none,
            .can_be_vietnamese = false,
        };
    }
    pub fn reset(self: *Syllable) void {
        self.am_dau = ._none;
        self.am_giua = ._none;
        self.am_cuoi = ._none;
        self.tone = ._none;
        self.can_be_vietnamese = false;
    }

    pub fn printBuffUtf8(self: *Syllable, buff: []u8) []const u8 {
        const blank = "";
        const dau = switch (self.am_dau) {
            ._none => blank,
            .zd => "đ",
            .c => switch (@tagName(self.am_giua)[0]) {
                'e', 'i', 'y' => "k",
                else => switch (self.am_giua) {
                    .uyez, .oa, .oe, .uy, .uez, .uaz => "q",
                    else => "c",
                },
            },
            .gi => if (@tagName(self.am_giua)[0] == 'i') "g" else "gi",
            .g => switch (@tagName(self.am_giua)[0]) {
                'e', 'i', 'y' => "gh",
                else => "g",
            },
            .ng => switch (@tagName(self.am_giua)[0]) {
                'e', 'i', 'y' => "ngh",
                else => "ng",
            },
            else => @tagName(self.am_dau),
        };
        const giua = switch (self.tone) {
            ._none => switch (self.am_giua) {
                .uo => "uo",
                .u_ow => "uơ",
                ._none => blank,
                .oaw => if (self.am_dau == .q) "uă" else "oă",
                .aw => "ă",
                .uw => "ư",
                .ow => "ơ",
                .uoz => if (self.am_cuoi == ._none) "ua" else "uô",
                .uow => if (self.am_cuoi == ._none) "ưa" else "ươ",
                .uaz => "uâ",
                .uez => "uê",
                .az => "â",
                .ez => "ê",
                .oz => "ô",
                .iez => blk: {
                    if (self.am_cuoi == ._none) break :blk "ia";
                    if (self.am_dau == ._none) break :blk "yê";
                    break :blk "iê";
                },
                .uyez => if (self.am_cuoi == ._none) "uya" else "uyê",
                .oo => "oo",
                .oa => if (self.am_dau == .c) "ua" else "oa",
                .oe => if (self.am_dau == .c) "ue" else "oe",
                else => @tagName(self.am_giua),
            },
            .s => switch (self.am_giua) {
                .uo => "uó",
                .u_ow => "uớ",
                ._none => blank,
                .oaw => if (self.am_dau == .q) "uắ" else "oắ",
                .aw => "ắ",
                .uw => "ứ",
                .ow => "ớ",
                .uoz => if (self.am_cuoi == ._none and self.am_dau != .q) "úa" else "uố",
                .uow => if (self.am_cuoi == ._none) "ứa" else "ướ",
                .uaz => "uấ",
                .uez => "uế",
                .az => "ấ",
                .ez => "ế",
                .oz => "ố",
                .iez => blk: {
                    if (self.am_cuoi == ._none) break :blk "ía";
                    if (self.am_dau == ._none) break :blk "yế";
                    break :blk "iế";
                },
                .uyez => if (self.am_cuoi == ._none) "uýa" else "uyế",
                .a => "á",
                .e => "é",
                .i => "í",
                .u => "ú",
                .y => "ý",
                .o => "ó",
                .ua => "úa",
                .oa => if (self.am_dau == .c) "uá" else "oá",
                .oe => if (self.am_dau == .c) "ué" else "oé",
                .oo => "oó",
                .uy => "uý",
                else => @tagName(self.am_giua),
            },
            .f => switch (self.am_giua) {
                .uo => "uò",
                .u_ow => "uờ",
                ._none => blank,
                .oaw => if (self.am_dau == .q) "uằ" else "oằ",
                .aw => "ằ",
                .uw => "ừ",
                .ow => "ờ",
                .uoz => if (self.am_cuoi == ._none and self.am_dau != .q) "ùa" else "uồ",
                .uow => if (self.am_cuoi == ._none) "ừa" else "ườ",
                .uaz => "uầ",
                .uez => "uề",
                .az => "ầ",
                .ez => "ề",
                .oz => "ồ",
                .iez => blk: {
                    if (self.am_cuoi == ._none) break :blk "ìa";
                    if (self.am_dau == ._none) break :blk "yề";
                    break :blk "iề";
                },
                .uyez => if (self.am_cuoi == ._none) "uỳa" else "uyề",
                .a => "à",
                .e => "è",
                .i => "ì",
                .u => "ù",
                .y => "ỳ",
                .o => "ò",
                .ua => "ùa",
                .oa => if (self.am_dau == .c) "uà" else "oà",
                .oe => if (self.am_dau == .c) "uè" else "oè",
                .oo => "oò",
                .uy => "uỳ",
                else => @tagName(self.am_giua),
            },
            .r => switch (self.am_giua) {
                .uo => "uỏ",
                .u_ow => "uở",
                ._none => blank,
                .oaw => if (self.am_dau == .q) "uẳ" else "oẳ",
                .aw => "ẳ",
                .uw => "ử",
                .ow => "ở",
                .uoz => if (self.am_cuoi == ._none and self.am_dau != .q) "ủa" else "uổ",
                .uow => if (self.am_cuoi == ._none) "ửa" else "ưở",
                .uaz => "uẩ",
                .uez => "uể",
                .az => "ẩ",
                .ez => "ể",
                .oz => "ổ",
                .iez => blk: {
                    if (self.am_cuoi == ._none) break :blk "ỉa";
                    if (self.am_dau == ._none) break :blk "yể";
                    break :blk "iể";
                },
                .uyez => if (self.am_cuoi == ._none) "uỷa" else "uyể",
                .a => "ả",
                .e => "ẻ",
                .i => "ỉ",
                .u => "ủ",
                .y => "ỷ",
                .o => "ỏ",
                .ua => "ủa",
                .oa => if (self.am_dau == .c) "uả" else "oả",
                .oe => if (self.am_dau == .c) "uẻ" else "oẻ",
                .oo => "oỏ",
                .uy => "uỷ",
                else => @tagName(self.am_giua),
            },
            .x => switch (self.am_giua) {
                .uo => "uõ",
                .u_ow => "uỡ",
                ._none => blank,
                .oaw => if (self.am_dau == .q) "uẵ" else "oẵ",
                .aw => "ẵ",
                .uw => "ữ",
                .ow => "ỡ",
                .uoz => if (self.am_cuoi == ._none and self.am_dau != .q) "ũa" else "uỗ",
                .uow => if (self.am_cuoi == ._none) "ữa" else "ưỡ",
                .uaz => "uẫ",
                .uez => "uễ",
                .az => "ẫ",
                .ez => "ễ",
                .oz => "ỗ",
                .iez => blk: {
                    if (self.am_cuoi == ._none) break :blk "ĩa";
                    if (self.am_dau == ._none) break :blk "yễ";
                    break :blk "iễ";
                },
                .uyez => if (self.am_cuoi == ._none) "uỹa" else "uyễ",
                .a => "ã",
                .e => "ẽ",
                .i => "ĩ",
                .u => "ũ",
                .y => "ỹ",
                .o => "õ",
                .ua => "ũa",
                .oa => if (self.am_dau == .c) "uã" else "oã",
                .oe => if (self.am_dau == .c) "uẽ" else "oẽ",
                .oo => "oõ",
                .uy => "uỹ",
                else => @tagName(self.am_giua),
            },
            .j => switch (self.am_giua) {
                .uo => "uọ",
                .u_ow => "uợ",
                ._none => blank,
                .oaw => if (self.am_dau == .q) "uặ" else "oặ",
                .aw => "ặ",
                .uw => "ự",
                .ow => "ợ",
                .uoz => if (self.am_cuoi == ._none and self.am_dau != .q) "ụa" else "uộ",
                .uow => if (self.am_cuoi == ._none) "ựa" else "ượ",
                .uaz => "uậ",
                .uez => "uệ",
                .az => "ậ",
                .ez => "ệ",
                .oz => "ộ",
                .iez => blk: {
                    if (self.am_cuoi == ._none) break :blk "ịa";
                    if (self.am_dau == ._none) break :blk "yệ";
                    break :blk "iệ";
                },
                .uyez => if (self.am_cuoi == ._none) "uỵa" else "uyệ",
                .a => "ạ",
                .e => "ẹ",
                .i => "ị",
                .u => "ụ",
                .y => "ỵ",
                .o => "ọ",
                .ua => "ụa",
                .oa => if (self.am_dau == .c) "uạ" else "oạ",
                .oe => if (self.am_dau == .c) "uẹ" else "oẹ",
                .oo => "oọ",
                .uy => "uỵ",
                else => @tagName(self.am_giua),
            },
        };

        const cuoi = if (self.am_cuoi == ._none) blank else @tagName(self.am_cuoi);

        std.debug.assert(buff.len >= dau.len + giua.len + cuoi.len);

        var n: usize = 0;
        const parts: [3][]const u8 = .{ dau, giua, cuoi };

        for (parts) |s| {
            for (s) |b| {
                buff[n] = b;
                n += 1;
            }
        }
        std.debug.assert(n <= MAXX_BYTES);
        return buff[0..n];
    }

    pub fn len(self: Syllable) u8 {
        return self.am_dau.len() + self.am_giua.len() + self.am_cuoi.len() + self.tone.len();
    }
    pub fn hasAmDem(self: Syllable) bool {
        return self.am_giua.hasAmDem() || self.am_dau == .qu;
    }
    pub fn isSaturated(self: Syllable) bool {
        return self.am_cuoi.isSaturated() and self.tone.isSaturated();
    }
};

test "Syllable's printBuff" {
    var syll = Syllable{
        .am_dau = AmDau.ng,
        .am_giua = AmGiua.uow,
        .am_cuoi = AmCuoi._none,
        .tone = Tone.s,
        .can_be_vietnamese = true,
    };

    var buffer: [12]u8 = undefined;
    const buff = buffer[0..];

    try std.testing.expectEqualStrings(syll.printBuffUtf8(buff), "ngứa");

    syll.am_giua = .o;
    try std.testing.expectEqualStrings(syll.printBuffUtf8(buff), "ngó");

    syll.am_giua = .iez;
    syll.am_cuoi = .n;
    try std.testing.expectEqualStrings(syll.printBuffUtf8(buff), "nghiến");

    syll.tone = ._none;
    syll.am_giua = .oz;
    syll.am_cuoi = .n;
    try std.testing.expectEqualStrings(syll.printBuffUtf8(buff), "ngôn");
}

//
const parseSyllable = @import("am_tiet_parse.zig").parseSyllable;
const cmn = @import("common.zig");

pub fn main() void {
    var buffer: [Syllable.MAXX_BYTES + 5]u8 = undefined;
    const buf1 = buffer[0..];

    var buffer2: [Syllable.MAXX_BYTES + 5]u8 = undefined;
    const buf2 = buffer2[0..];

    var i: Syllable.UniqueId = 0;
    var n: usize = 0;
    while (i < Syllable.MAXX_ID) : (i += 1) {
        var syll = Syllable.newFromId(i);

        if (syll.am_giua == .ah or syll.am_giua == .oah) continue; // bỏ qua 2 âm hỗ trợ
        if (syll.am_giua == .i and syll.am_cuoi == .i) continue;
        if (syll.am_giua == .o and syll.am_cuoi == .o) continue;

        if (syll.am_dau == .q and (syll.am_giua != .uez or syll.am_giua != .uy or syll.am_giua != .uyez or syll.am_giua != .uaz or syll.am_giua != .ua)) continue;

        const a = syll.printBuffUtf8(buf1);
        var reve = parseSyllable(a);
        const b = reve.printBuffUtf8(buf2);

        n += 1;
        if (n < 200) {
            std.debug.print("{s: >9}  ", .{a});
            if ((n + 1) % 8 == 0) std.debug.print("\n", .{});
        }

        if (std.mem.eql(u8, a, b)) continue; // bỏ qua uoz!=ua[bụa bụa] ez!=iez[giệu giệu]

        if ( //syll.am_dau != reve.am_dau or
        syll.am_giua != reve.am_giua or
            syll.am_cuoi != reve.am_cuoi or
            syll.tone != reve.tone)
        {
            if (syll.am_dau != reve.am_dau) std.debug.print(" {s}!={s}", .{ @tagName(syll.am_dau), @tagName(reve.am_dau) });
            if (syll.am_giua != reve.am_giua) std.debug.print(" {s}!={s}", .{ @tagName(syll.am_giua), @tagName(reve.am_giua) });
            if (syll.am_cuoi != reve.am_cuoi) std.debug.print(" {s}!={s}", .{ @tagName(syll.am_cuoi), @tagName(reve.am_cuoi) });
            if (syll.tone != reve.tone) std.debug.print(" {s}!={s}", .{ @tagName(syll.tone), @tagName(reve.tone) });
            std.debug.print("[{s} {s}]   ", .{ a, b });
        }
    }
}
