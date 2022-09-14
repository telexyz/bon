//! [All hash table sizes you will ever need](http://databasearchitects.blogspot.com/2020/01/all-hash-table-sizes-you-will-ever-need.html)
//!
//! Khi chọn kích thước bảng băm ta thường có 2 lựa chọn: số nguyên tố hoặc lũy thừa 2. Lũy thừa bậc 2 dễ sử dụng nhưng 1/ tốn không gian lưu trữ và 2/ đòi hỏi hàm băm phải tốt hơn.
//!
//! Các số nguyên tố dễ dãi hơn với hàm băm (ko yêu cầu nó phải phân bổ đều như lũy thừa của 2) và chúng ta có nhiều lựa chọn hơn liên quan đến kích thước, dẫn đến chi phí thấp hơn. Nhưng việc sử dụng một số nguyên tố cần phải thực hiện phép chia mô đun, điều này rất tốn kém. Và chúng ta phải tìm một số nguyên tố phù hợp trong thời gian chạy, điều này cũng không hề đơn giản.
//!
//! May mắn thay chúng ta có thể giải quyết cả 2 vấn đề trên cùng một lúc. Chúng ta có thể tính toán trước các số nguyên tố cần dùng. Nếu chọn khoảng cách giữa chúng là 5% thì trong khoảng trong khoảng 0 - 2^64 chỉ có 841 số nguyên tố. Với phép chia mô đun, ta có thể tính toán trước magic numbers như trong cuốn Hacker's Delight cho các số nguyên tố để thực hiện phép chia mô đun nhanh (~8x).
//!
//! Chuyển đổi mã nguồn từ https://db.in.tum.de/~neumann/primes.hpp

const std = @import("std");
test "Prime" {
    try std.testing.expectEqual(Prime.pick(5).value, 5);
    const x: u64 = 4494041191586404219;
    const p = Prime.pick(x - 1);
    try std.testing.expectEqual(p.value, x);

    try std.testing.expectEqual(p.mod(3), 3);
    try std.testing.expectEqual(p.mod(p.value + 3), 3);

    var prev: u64 = 0;
    for (Prime.primes) |prime| {
        var i: usize = 0;
        while (i < 10_000) : (i += 1) {
            const n1 = prime.value + i;
            const n2 = std.math.maxInt(u64) - i;
            try std.testing.expectEqual(prime.mod(n1), n1 % prime.value);
            try std.testing.expectEqual(prime.mod(n2), n2 % prime.value);
        }

        i = 0;
        const n = std.math.min(100, (prime.value - prev) / 2);
        // std.debug.print("\nn={d}, prime={d}", .{ n, prime.value });
        while (i <= n) : (i += 1) {
            const lower = Prime.pick(prev + i);
            const upper = Prime.pick(prime.value - i);
            // std.debug.print(", [{d}, {d}]", .{ prev + i, prime.value - i });
            try std.testing.expectEqual(lower, prime);
            try std.testing.expectEqual(upper, prime);
        }
        prev = prime.value + 1;
    }
}

pub const Prime = struct {
    pub const Number = struct {
        value: u64, // Giá trị của số nguyên tố
        magic: u64, // The magic multiplication number
        shift: u6, //  The shift after multiplication

        /// Divide the argument by the prime number
        pub inline fn div(self: Number, x: u64) u64 {
            return @intCast(u64, (@intCast(u128, x) * self.magic) >> 64) >> self.shift;
        }

        /// Return the remainder after division
        pub inline fn mod(self: Number, x: u64) u64 {
            // return x % self.value;
            return x - self.div(x) * self.value;
        }
    };

    /// Pick a suitable prime number larger than the argument
    pub fn pick(desired_size: u64) Number {
        var lower: u64 = 0;
        var upper: u64 = prime_count - 1;

        // Kiểm tra cận trên. Tiệm cận với 2^64 là một số rất lớn nên
        // trong thực tế hầu như không dùng số lớn như vậy
        if (desired_size >= primes[prime_count - 1].value) {
            return primes[upper];
        }

        // Vì primes là mảng tăng dần nên ta có thể sử dụng chia để trị
        while (lower != upper) {
            const middle = lower / 2 + upper / 2;
            const midval = primes[middle].value;

            if (midval == desired_size) {
                return primes[middle];
            } else {
                if (midval < desired_size) {
                    lower = middle + 1;
                } else {
                    upper = middle;
                }
            }
        }

        return primes[lower];
    }

    /// Tính toán trước dãy 814 số nguyên tố lấp đầy khoảng từ 0 - 2^64
    /// Mảng này bỏ qua các số nguyên tố mà magic number của nó không thuận tiện
    /// cho phép chia mô đun.
    pub const prime_count = 814;
    pub const primes = [prime_count]Number{ .{
        .value = 3,
        .magic = 12297829382473034411,
        .shift = 1,
    }, .{
        .value = 5,
        .magic = 14757395258967641293,
        .shift = 2,
    }, .{
        .value = 11,
        .magic = 3353953467947191203,
        .shift = 1,
    }, .{
        .value = 13,
        .magic = 5675921253449092805,
        .shift = 2,
    }, .{
        .value = 17,
        .magic = 17361641481138401521,
        .shift = 4,
    }, .{
        .value = 19,
        .magic = 15534100272597517151,
        .shift = 4,
    }, .{
        .value = 37,
        .magic = 15953940820505558155,
        .shift = 5,
    }, .{
        .value = 41,
        .magic = 14397458789236723213,
        .shift = 5,
    }, .{
        .value = 43,
        .magic = 13727809543225712831,
        .shift = 5,
    }, .{
        .value = 59,
        .magic = 10005013734893316131,
        .shift = 5,
    }, .{
        .value = 67,
        .magic = 17620770458468825425,
        .shift = 6,
    }, .{
        .value = 73,
        .magic = 8086243977516515777,
        .shift = 5,
    }, .{
        .value = 79,
        .magic = 7472098865300071541,
        .shift = 5,
    }, .{
        .value = 83,
        .magic = 3555998857582564167,
        .shift = 4,
    }, .{
        .value = 109,
        .magic = 10831115786398268839,
        .shift = 6,
    }, .{
        .value = 113,
        .magic = 10447713457676206225,
        .shift = 6,
    }, .{
        .value = 131,
        .magic = 281629680514649643,
        .shift = 1,
    }, .{
        .value = 139,
        .magic = 4246732448623781667,
        .shift = 5,
    }, .{
        .value = 149,
        .magic = 1980858424022502187,
        .shift = 4,
    }, .{
        .value = 157,
        .magic = 3759845925851628355,
        .shift = 5,
    }, .{
        .value = 163,
        .magic = 14485786757268850349,
        .shift = 7,
    }, .{
        .value = 173,
        .magic = 13648458042975853219,
        .shift = 7,
    }, .{
        .value = 191,
        .magic = 6181107961871263369,
        .shift = 6,
    }, .{
        .value = 211,
        .magic = 5595220951267352149,
        .shift = 6,
    }, .{
        .value = 227,
        .magic = 10401688288259130427,
        .shift = 7,
    }, .{
        .value = 241,
        .magic = 1224680104478642431,
        .shift = 4,
    }, .{
        .value = 257,
        .magic = 18374966859414961921,
        .shift = 8,
    }, .{
        .value = 269,
        .magic = 17555265735574889271,
        .shift = 8,
    }, .{
        .value = 283,
        .magic = 8343403679981705325,
        .shift = 7,
    }, .{
        .value = 307,
        .magic = 15382301247132394833,
        .shift = 8,
    }, .{
        .value = 331,
        .magic = 14266968226192281613,
        .shift = 8,
    }, .{
        .value = 349,
        .magic = 13531136054067751329,
        .shift = 8,
    }, .{
        .value = 373,
        .magic = 12660499954074115855,
        .shift = 8,
    }, .{
        .value = 397,
        .magic = 185861401246443845,
        .shift = 2,
    }, .{
        .value = 419,
        .magic = 5635282199128454909,
        .shift = 7,
    }, .{
        .value = 439,
        .magic = 10757099049816959485,
        .shift = 8,
    }, .{
        .value = 461,
        .magic = 5121872541073367911,
        .shift = 7,
    }, .{
        .value = 499,
        .magic = 591478767894494641,
        .shift = 4,
    }, .{
        .value = 523,
        .magic = 18058762840801702539,
        .shift = 9,
    }, .{
        .value = 557,
        .magic = 16956432613535530391,
        .shift = 9,
    }, .{
        .value = 587,
        .magic = 2011229336826935781,
        .shift = 6,
    }, .{
        .value = 617,
        .magic = 7653754429286296943,
        .shift = 8,
    }, .{
        .value = 647,
        .magic = 14597732559102458157,
        .shift = 9,
    }, .{
        .value = 691,
        .magic = 13668209791229074425,
        .shift = 9,
    }, .{
        .value = 727,
        .magic = 1623922449404967405,
        .shift = 6,
    }, .{
        .value = 769,
        .magic = 12281837406683082481,
        .shift = 9,
    }, .{
        .value = 809,
        .magic = 729661075845124415,
        .shift = 5,
    }, .{
        .value = 877,
        .magic = 673085302575491051,
        .shift = 5,
    }, .{
        .value = 941,
        .magic = 2509227674213414035,
        .shift = 7,
    }, .{
        .value = 997,
        .magic = 4736576211504157687,
        .shift = 8,
    }, .{
        .value = 1049,
        .magic = 18007117189207417403,
        .shift = 10,
    }, .{
        .value = 1103,
        .magic = 4281383937325154319,
        .shift = 8,
    }, .{
        .value = 1163,
        .magic = 8121008568993370961,
        .shift = 9,
    }, .{
        .value = 1223,
        .magic = 15445188823776435695,
        .shift = 10,
    }, .{
        .value = 1283,
        .magic = 7361444244535690123,
        .shift = 9,
    }, .{
        .value = 1367,
        .magic = 6909095073693701849,
        .shift = 9,
    }, .{
        .value = 1439,
        .magic = 13126800508324239649,
        .shift = 10,
    }, .{
        .value = 1523,
        .magic = 12402801005567026169,
        .shift = 10,
    }, .{
        .value = 1609,
        .magic = 2934969846407486149,
        .shift = 8,
    }, .{
        .value = 1693,
        .magic = 5578696376691843135,
        .shift = 9,
    }, .{
        .value = 1783,
        .magic = 5297102055939029965,
        .shift = 9,
    }, .{
        .value = 1871,
        .magic = 10095919792345580361,
        .shift = 10,
    }, .{
        .value = 1987,
        .magic = 9506525380713930979,
        .shift = 10,
    }, .{
        .value = 2087,
        .magic = 1131376732838918355,
        .shift = 7,
    }, .{
        .value = 2203,
        .magic = 1071803559434781029,
        .shift = 7,
    }, .{
        .value = 2333,
        .magic = 2024160515589217837,
        .shift = 8,
    }, .{
        .value = 2459,
        .magic = 15363534714500675767,
        .shift = 11,
    }, .{
        .value = 2591,
        .magic = 14580830514456642883,
        .shift = 11,
    }, .{
        .value = 2719,
        .magic = 6947210714041405243,
        .shift = 10,
    }, .{
        .value = 2857,
        .magic = 826455457275051665,
        .shift = 7,
    }, .{
        .value = 2999,
        .magic = 12597176346434532081,
        .shift = 11,
    }, .{
        .value = 3163,
        .magic = 11944018926006058081,
        .shift = 11,
    }, .{
        .value = 3323,
        .magic = 2842230805217962813,
        .shift = 9,
    }, .{
        .value = 3491,
        .magic = 10821808038658596881,
        .shift = 11,
    }, .{
        .value = 3671,
        .magic = 10291182746651365217,
        .shift = 11,
    }, .{
        .value = 3863,
        .magic = 9779687254195485817,
        .shift = 11,
    }, .{
        .value = 4091,
        .magic = 9234644796616270279,
        .shift = 11,
    }, .{
        .value = 4297,
        .magic = 17583864027441080619,
        .shift = 12,
    }, .{
        .value = 4513,
        .magic = 16742269826260652209,
        .shift = 12,
    }, .{
        .value = 4751,
        .magic = 15903570559022168685,
        .shift = 12,
    }, .{
        .value = 4987,
        .magic = 1893870656855682861,
        .shift = 9,
    }, .{
        .value = 5237,
        .magic = 7213849887904747319,
        .shift = 11,
    }, .{
        .value = 5501,
        .magic = 6867648039076015581,
        .shift = 11,
    }, .{
        .value = 5791,
        .magic = 3261865987131511113,
        .shift = 10,
    }, .{
        .value = 6079,
        .magic = 3107331128718305783,
        .shift = 10,
    }, .{
        .value = 6397,
        .magic = 11811452825686153419,
        .shift = 12,
    }, .{
        .value = 6733,
        .magic = 11222020455356352803,
        .shift = 12,
    }, .{
        .value = 7079,
        .magic = 5336761105093538877,
        .shift = 11,
    }, .{
        .value = 7433,
        .magic = 5082595434273800849,
        .shift = 11,
    }, .{
        .value = 7877,
        .magic = 9592213244371502275,
        .shift = 12,
    }, .{
        .value = 8269,
        .magic = 18274970063106620733,
        .shift = 13,
    }, .{
        .value = 8681,
        .magic = 17407640531255459837,
        .shift = 13,
    }, .{
        .value = 9127,
        .magic = 16556998734724295699,
        .shift = 13,
    }, .{
        .value = 9587,
        .magic = 15762566752042207869,
        .shift = 13,
    }, .{
        .value = 10067,
        .magic = 3752749762884390753,
        .shift = 11,
    }, .{
        .value = 10589,
        .magic = 14271010241933010373,
        .shift = 13,
    }, .{
        .value = 11117,
        .magic = 13593211068798115215,
        .shift = 13,
    }, .{
        .value = 11677,
        .magic = 12941314331748620951,
        .shift = 13,
    }, .{
        .value = 12263,
        .magic = 12322900387493162101,
        .shift = 13,
    }, .{
        .value = 12893,
        .magic = 732547348618575229,
        .shift = 9,
    }, .{
        .value = 13537,
        .magic = 2790790563858843297,
        .shift = 11,
    }, .{
        .value = 14221,
        .magic = 5313118889382907209,
        .shift = 12,
    }, .{
        .value = 14947,
        .magic = 5055052099144599145,
        .shift = 12,
    }, .{
        .value = 15727,
        .magic = 4804340543391258563,
        .shift = 12,
    }, .{
        .value = 16519,
        .magic = 4573997440881065647,
        .shift = 12,
    }, .{
        .value = 17351,
        .magic = 17418676439609088449,
        .shift = 14,
    }, .{
        .value = 18217,
        .magic = 2073828394519249147,
        .shift = 11,
    }, .{
        .value = 19139,
        .magic = 3947848044616454539,
        .shift = 12,
    }, .{
        .value = 20101,
        .magic = 15035642749298905213,
        .shift = 14,
    }, .{
        .value = 21107,
        .magic = 111867306648733719,
        .shift = 7,
    }, .{
        .value = 22189,
        .magic = 3405194633643441499,
        .shift = 12,
    }, .{
        .value = 23297,
        .magic = 6486488708925125417,
        .shift = 13,
    }, .{
        .value = 24473,
        .magic = 1543698437582526119,
        .shift = 11,
    }, .{
        .value = 25717,
        .magic = 2938051239488055505,
        .shift = 12,
    }, .{
        .value = 27011,
        .magic = 5594599513229004733,
        .shift = 13,
    }, .{
        .value = 28387,
        .magic = 2661706546162480129,
        .shift = 12,
    }, .{
        .value = 29819,
        .magic = 10135532878488792169,
        .shift = 14,
    }, .{
        .value = 31321,
        .magic = 9649482931696219587,
        .shift = 14,
    }, .{
        .value = 32887,
        .magic = 9189997716534110551,
        .shift = 14,
    }, .{
        .value = 34537,
        .magic = 17501893905299087569,
        .shift = 15,
    }, .{
        .value = 36263,
        .magic = 4167215273193851773,
        .shift = 13,
    }, .{
        .value = 38083,
        .magic = 3968062585716163297,
        .shift = 13,
    }, .{
        .value = 39989,
        .magic = 15115729570814838765,
        .shift = 15,
    }, .{
        .value = 41999,
        .magic = 14392316717238853005,
        .shift = 15,
    }, .{
        .value = 44101,
        .magic = 6853165572292176905,
        .shift = 14,
    }, .{
        .value = 46307,
        .magic = 6526690455085781711,
        .shift = 14,
    }, .{
        .value = 48623,
        .magic = 6215812576427972229,
        .shift = 14,
    }, .{
        .value = 51059,
        .magic = 11838518376923061309,
        .shift = 15,
    }, .{
        .value = 53611,
        .magic = 1409372399804411845,
        .shift = 12,
    }, .{
        .value = 56333,
        .magic = 2682543579284409615,
        .shift = 13,
    }, .{
        .value = 59149,
        .magic = 10219325936318696637,
        .shift = 15,
    }, .{
        .value = 62119,
        .magic = 9730725056863674357,
        .shift = 15,
    }, .{
        .value = 65239,
        .magic = 9265361360647995637,
        .shift = 15,
    }, .{
        .value = 68501,
        .magic = 4412073617956778641,
        .shift = 14,
    }, .{
        .value = 71933,
        .magic = 16806275556623930251,
        .shift = 16,
    }, .{
        .value = 75533,
        .magic = 8002633415954808989,
        .shift = 15,
    }, .{
        .value = 79309,
        .magic = 15243236197841722563,
        .shift = 16,
    }, .{
        .value = 83273,
        .magic = 7258810296342326893,
        .shift = 15,
    }, .{
        .value = 87481,
        .magic = 3454823960673258121,
        .shift = 14,
    }, .{
        .value = 91867,
        .magic = 13159522131065879747,
        .shift = 16,
    }, .{
        .value = 96461,
        .magic = 6266396883790491363,
        .shift = 15,
    }, .{
        .value = 101287,
        .magic = 11935646426635492953,
        .shift = 16,
    }, .{
        .value = 106357,
        .magic = 11366678447254333751,
        .shift = 16,
    }, .{
        .value = 111697,
        .magic = 5411630659796723165,
        .shift = 15,
    }, .{
        .value = 117281,
        .magic = 10307942630218272139,
        .shift = 16,
    }, .{
        .value = 123191,
        .magic = 76667394255581093,
        .shift = 9,
    }, .{
        .value = 129379,
        .magic = 9344065262636356555,
        .shift = 16,
    }, .{
        .value = 135851,
        .magic = 556181873713953695,
        .shift = 12,
    }, .{
        .value = 142657,
        .magic = 2118588326571127205,
        .shift = 14,
    }, .{
        .value = 149791,
        .magic = 16141501420173831201,
        .shift = 17,
    }, .{
        .value = 157279,
        .magic = 3843252499108683215,
        .shift = 15,
    }, .{
        .value = 165161,
        .magic = 7319680915074558611,
        .shift = 16,
    }, .{
        .value = 173431,
        .magic = 13941288692501677033,
        .shift = 17,
    }, .{
        .value = 182101,
        .magic = 13277530816575737363,
        .shift = 17,
    }, .{
        .value = 191227,
        .magic = 197560657558593513,
        .shift = 11,
    }, .{
        .value = 200789,
        .magic = 6020876739336463525,
        .shift = 16,
    }, .{
        .value = 210827,
        .magic = 11468415521869866523,
        .shift = 17,
    }, .{
        .value = 221399,
        .magic = 10920788437297631649,
        .shift = 17,
    }, .{
        .value = 232499,
        .magic = 10399406617788714573,
        .shift = 17,
    }, .{
        .value = 244157,
        .magic = 9902856109918037777,
        .shift = 17,
    }, .{
        .value = 256369,
        .magic = 9431138863237202429,
        .shift = 17,
    }, .{
        .value = 269189,
        .magic = 8981985293712812743,
        .shift = 17,
    }, .{
        .value = 282661,
        .magic = 8553891903125151151,
        .shift = 17,
    }, .{
        .value = 296797,
        .magic = 2036620686217564825,
        .shift = 15,
    }, .{
        .value = 311677,
        .magic = 7757555543813814781,
        .shift = 17,
    }, .{
        .value = 327263,
        .magic = 14776199198988326511,
        .shift = 18,
    }, .{
        .value = 343627,
        .magic = 14072535855618204329,
        .shift = 18,
    }, .{
        .value = 360817,
        .magic = 13402093799511987237,
        .shift = 18,
    }, .{
        .value = 378869,
        .magic = 6381761609498951747,
        .shift = 17,
    }, .{
        .value = 397811,
        .magic = 6077890353030103113,
        .shift = 17,
    }, .{
        .value = 417719,
        .magic = 1447056298150944983,
        .shift = 15,
    }, .{
        .value = 438611,
        .magic = 5512519383301509423,
        .shift = 17,
    }, .{
        .value = 460543,
        .magic = 5250001930827866995,
        .shift = 17,
    }, .{
        .value = 483611,
        .magic = 2499789747575280907,
        .shift = 16,
    }, .{
        .value = 507803,
        .magic = 9522793836307616731,
        .shift = 18,
    }, .{
        .value = 533213,
        .magic = 18137979675883808905,
        .shift = 19,
    }, .{
        .value = 559877,
        .magic = 17274162998153225437,
        .shift = 19,
    }, .{
        .value = 587891,
        .magic = 2056377491090404811,
        .shift = 16,
    }, .{
        .value = 617311,
        .magic = 7833496047306004103,
        .shift = 18,
    }, .{
        .value = 648181,
        .magic = 3730210603564835053,
        .shift = 17,
    }, .{
        .value = 680597,
        .magic = 14210180998325049035,
        .shift = 19,
    }, .{
        .value = 714673,
        .magic = 13532631786729082249,
        .shift = 19,
    }, .{
        .value = 750413,
        .magic = 12888111689052606229,
        .shift = 19,
    }, .{
        .value = 787981,
        .magic = 12273654513138049519,
        .shift = 19,
    }, .{
        .value = 827389,
        .magic = 11689068330515674487,
        .shift = 19,
    }, .{
        .value = 868771,
        .magic = 5566142606577011317,
        .shift = 18,
    }, .{
        .value = 912211,
        .magic = 10602159540848590291,
        .shift = 19,
    }, .{
        .value = 957821,
        .magic = 1262162574859633663,
        .shift = 16,
    }, .{
        .value = 1005761,
        .magic = 4808004365309965985,
        .shift = 18,
    }, .{
        .value = 1056049,
        .magic = 2289525996643392825,
        .shift = 17,
    }, .{
        .value = 1108867,
        .magic = 4360940742630555963,
        .shift = 18,
    }, .{
        .value = 1164323,
        .magic = 16612927094830272009,
        .shift = 20,
    }, .{
        .value = 1222561,
        .magic = 7910776277762036739,
        .shift = 19,
    }, .{
        .value = 1283701,
        .magic = 3767001255322319371,
        .shift = 18,
    }, .{
        .value = 1347893,
        .magic = 7175203489384567913,
        .shift = 19,
    }, .{
        .value = 1415303,
        .magic = 13666906036258007505,
        .shift = 20,
    }, .{
        .value = 1486081,
        .magic = 6507994218967225473,
        .shift = 19,
    }, .{
        .value = 1560407,
        .magic = 6198002544795706119,
        .shift = 19,
    }, .{
        .value = 1638431,
        .magic = 11805692832859038187,
        .shift = 20,
    }, .{
        .value = 1720361,
        .magic = 11243461758220551847,
        .shift = 20,
    }, .{
        .value = 1806379,
        .magic = 5354029556874295703,
        .shift = 19,
    }, .{
        .value = 1896761,
        .magic = 10197812541397712625,
        .shift = 20,
    }, .{
        .value = 1991603,
        .magic = 4856091578952749819,
        .shift = 19,
    }, .{
        .value = 2091191,
        .magic = 4624831761860601637,
        .shift = 19,
    }, .{
        .value = 2195749,
        .magic = 8809209574424976077,
        .shift = 20,
    }, .{
        .value = 2305549,
        .magic = 16779355471372819919,
        .shift = 21,
    }, .{
        .value = 2420827,
        .magic = 15980334913510190357,
        .shift = 21,
    }, .{
        .value = 2541899,
        .magic = 3715620866816223,
        .shift = 9,
    }, .{
        .value = 2668999,
        .magic = 14494432642225843319,
        .shift = 21,
    }, .{
        .value = 2802451,
        .magic = 6902105733100798835,
        .shift = 20,
    }, .{
        .value = 2942609,
        .magic = 3286677420247485615,
        .shift = 19,
    }, .{
        .value = 3089753,
        .magic = 3130155244421490455,
        .shift = 19,
    }, .{
        .value = 3244247,
        .magic = 11924377591369625553,
        .shift = 21,
    }, .{
        .value = 3406489,
        .magic = 354889101246071593,
        .shift = 16,
    }, .{
        .value = 3576847,
        .magic = 1351945799878640797,
        .shift = 18,
    }, .{
        .value = 3755729,
        .magic = 643776917671444971,
        .shift = 17,
    }, .{
        .value = 3943523,
        .magic = 9809915202134774817,
        .shift = 21,
    }, .{
        .value = 4140757,
        .magic = 4671322928110504141,
        .shift = 20,
    }, .{
        .value = 4347799,
        .magic = 2224437366335709953,
        .shift = 19,
    }, .{
        .value = 4565189,
        .magic = 16948094034077508551,
        .shift = 22,
    }, .{
        .value = 4793471,
        .magic = 4035241501165661959,
        .shift = 20,
    }, .{
        .value = 5033143,
        .magic = 240193020467455261,
        .shift = 16,
    }, .{
        .value = 5284819,
        .magic = 14640284266185136555,
        .shift = 22,
    }, .{
        .value = 5549087,
        .magic = 1742882488041191893,
        .shift = 19,
    }, .{
        .value = 5826577,
        .magic = 13279023422386122621,
        .shift = 22,
    }, .{
        .value = 6117919,
        .magic = 6323330895304127693,
        .shift = 21,
    }, .{
        .value = 6423821,
        .magic = 3011107114260199155,
        .shift = 20,
    }, .{
        .value = 6745021,
        .magic = 5735434512015327097,
        .shift = 21,
    }, .{
        .value = 7082311,
        .magic = 2731144271105020211,
        .shift = 20,
    }, .{
        .value = 7436459,
        .magic = 5202156863591681685,
        .shift = 21,
    }, .{
        .value = 7808329,
        .magic = 9908810509308235755,
        .shift = 22,
    }, .{
        .value = 8198783,
        .magic = 4718459584510058821,
        .shift = 21,
    }, .{
        .value = 8608727,
        .magic = 17975074004631873489,
        .shift = 23,
    }, .{
        .value = 9039167,
        .magic = 2139888898372390597,
        .shift = 20,
    }, .{
        .value = 9491137,
        .magic = 2037986925468894485,
        .shift = 20,
    }, .{
        .value = 9965699,
        .magic = 15527511407947654687,
        .shift = 23,
    }, .{
        .value = 10463987,
        .magic = 7394050896215397361,
        .shift = 22,
    }, .{
        .value = 10987189,
        .magic = 7041951536042227651,
        .shift = 22,
    }, .{
        .value = 11536549,
        .magic = 3353310095390582885,
        .shift = 21,
    }, .{
        .value = 12113417,
        .magic = 6387235943032116139,
        .shift = 22,
    }, .{
        .value = 12719107,
        .magic = 12166145383529876301,
        .shift = 23,
    }, .{
        .value = 13355101,
        .magic = 11586771594664281039,
        .shift = 23,
    }, .{
        .value = 14022871,
        .magic = 5517504400870283067,
        .shift = 22,
    }, .{
        .value = 14724029,
        .magic = 10509521878194652725,
        .shift = 23,
    }, .{
        .value = 15460229,
        .magic = 10009069394164377149,
        .shift = 23,
    }, .{
        .value = 16233247,
        .magic = 9532443195786556711,
        .shift = 23,
    }, .{
        .value = 17044913,
        .magic = 283703605788924631,
        .shift = 18,
    }, .{
        .value = 17897161,
        .magic = 2161550998377236121,
        .shift = 21,
    }, .{
        .value = 18792019,
        .magic = 4117240007863778085,
        .shift = 22,
    }, .{
        .value = 19731653,
        .magic = 1960587195997625419,
        .shift = 21,
    }, .{
        .value = 20718241,
        .magic = 3734450837565615111,
        .shift = 22,
    }, .{
        .value = 21754153,
        .magic = 3556619853475162521,
        .shift = 22,
    }, .{
        .value = 22841893,
        .magic = 211703262880117541,
        .shift = 18,
    }, .{
        .value = 23984003,
        .magic = 403244052167481525,
        .shift = 19,
    }, .{
        .value = 25183231,
        .magic = 6144664475764548813,
        .shift = 23,
    }, .{
        .value = 26442397,
        .magic = 11704120841289277547,
        .shift = 24,
    }, .{
        .value = 27764563,
        .magic = 5573381612765615449,
        .shift = 23,
    }, .{
        .value = 29152847,
        .magic = 5307972319501849489,
        .shift = 23,
    }, .{
        .value = 30610513,
        .magic = 5055207827149859735,
        .shift = 23,
    }, .{
        .value = 32141063,
        .magic = 9628959994924407719,
        .shift = 24,
    }, .{
        .value = 33748133,
        .magic = 18340867023449567935,
        .shift = 25,
    }, .{
        .value = 35435539,
        .magic = 8733746361847214141,
        .shift = 24,
    }, .{
        .value = 37207351,
        .magic = 16635691684761168229,
        .shift = 25,
    }, .{
        .value = 39067739,
        .magic = 1980438449620446865,
        .shift = 22,
    }, .{
        .value = 41021129,
        .magic = 15089053732350714615,
        .shift = 25,
    }, .{
        .value = 43072187,
        .magic = 3592631711751078123,
        .shift = 23,
    }, .{
        .value = 45225799,
        .magic = 3421553810705976347,
        .shift = 23,
    }, .{
        .value = 47487101,
        .magic = 13034487399908664407,
        .shift = 25,
    }, .{
        .value = 49861457,
        .magic = 1551724660900628459,
        .shift = 22,
    }, .{
        .value = 52354573,
        .magic = 5911327169478491759,
        .shift = 24,
    }, .{
        .value = 54972419,
        .magic = 11259646762910144767,
        .shift = 25,
    }, .{
        .value = 57721051,
        .magic = 5361735527326851147,
        .shift = 24,
    }, .{
        .value = 60607117,
        .magic = 5106413654708985229,
        .shift = 24,
    }, .{
        .value = 63637523,
        .magic = 1215811816800856111,
        .shift = 22,
    }, .{
        .value = 66819437,
        .magic = 2315830720194073685,
        .shift = 23,
    }, .{
        .value = 70160413,
        .magic = 17644423491141368779,
        .shift = 26,
    }, .{
        .value = 73668433,
        .magic = 16804212996974976717,
        .shift = 26,
    }, .{
        .value = 77351861,
        .magic = 16004011064263602849,
        .shift = 26,
    }, .{
        .value = 81219493,
        .magic = 15241907989814468245,
        .shift = 26,
    }, .{
        .value = 85280491,
        .magic = 14516098872899081631,
        .shift = 26,
    }, .{
        .value = 89544529,
        .magic = 6912426996435372813,
        .shift = 25,
    }, .{
        .value = 94021813,
        .magic = 6583259776565786255,
        .shift = 25,
    }, .{
        .value = 98722909,
        .magic = 12539541752009964323,
        .shift = 26,
    }, .{
        .value = 103659103,
        .magic = 1492801890352770411,
        .shift = 23,
    }, .{
        .value = 108842081,
        .magic = 11373726300633486371,
        .shift = 26,
    }, .{
        .value = 114284237,
        .magic = 2708028840594570087,
        .shift = 24,
    }, .{
        .value = 119998469,
        .magic = 10316298612821304203,
        .shift = 26,
    }, .{
        .value = 125998403,
        .magic = 9825045475261938637,
        .shift = 26,
    }, .{
        .value = 132298343,
        .magic = 9357184762966987991,
        .shift = 26,
    }, .{
        .value = 138913259,
        .magic = 8911604609934176801,
        .shift = 26,
    }, .{
        .value = 145858943,
        .magic = 8487241260793863527,
        .shift = 26,
    }, .{
        .value = 153151891,
        .magic = 2020771717545068175,
        .shift = 24,
    }, .{
        .value = 160809487,
        .magic = 15396355804373410817,
        .shift = 27,
    }, .{
        .value = 168849973,
        .magic = 14663194992460914103,
        .shift = 27,
    }, .{
        .value = 177292481,
        .magic = 6982473437694068227,
        .shift = 26,
    }, .{
        .value = 186157109,
        .magic = 13299949122924768615,
        .shift = 27,
    }, .{
        .value = 195464981,
        .magic = 12666617139828031651,
        .shift = 27,
    }, .{
        .value = 205238239,
        .magic = 12063444369013322853,
        .shift = 27,
    }, .{
        .value = 215500157,
        .magic = 11488994314610919517,
        .shift = 27,
    }, .{
        .value = 226275163,
        .magic = 1367737429588527437,
        .shift = 24,
    }, .{
        .value = 237588937,
        .magic = 10420855911194049199,
        .shift = 27,
    }, .{
        .value = 249468431,
        .magic = 9924622801555041447,
        .shift = 27,
    }, .{
        .value = 261941873,
        .magic = 2363005244460056745,
        .shift = 25,
    }, .{
        .value = 275038969,
        .magic = 9001924663885576701,
        .shift = 27,
    }, .{
        .value = 288790927,
        .magic = 1071657662643068661,
        .shift = 24,
    }, .{
        .value = 303230491,
        .magic = 16330020575475442869,
        .shift = 28,
    }, .{
        .value = 318392033,
        .magic = 1944049961962113975,
        .shift = 25,
    }, .{
        .value = 334311667,
        .magic = 7405903900358824599,
        .shift = 27,
    }, .{
        .value = 351027263,
        .magic = 14106483111374517653,
        .shift = 28,
    }, .{
        .value = 368578633,
        .magic = 3358686392668291965,
        .shift = 26,
    }, .{
        .value = 387007589,
        .magic = 6397497488274733935,
        .shift = 27,
    }, .{
        .value = 406357967,
        .magic = 12185709544957736979,
        .shift = 28,
    }, .{
        .value = 426675871,
        .magic = 11605437508186445115,
        .shift = 28,
    }, .{
        .value = 448009669,
        .magic = 11052797517058769327,
        .shift = 28,
    }, .{
        .value = 470410163,
        .magic = 10526473589690537999,
        .shift = 28,
    }, .{
        .value = 493930721,
        .magic = 1253151491345868599,
        .shift = 25,
    }, .{
        .value = 518627269,
        .magic = 2386955166611920429,
        .shift = 26,
    }, .{
        .value = 544558643,
        .magic = 18186324726615425695,
        .shift = 29,
    }, .{
        .value = 571786583,
        .magic = 17320309025654493539,
        .shift = 29,
    }, .{
        .value = 600375911,
        .magic = 8247766218490936589,
        .shift = 28,
    }, .{
        .value = 630394717,
        .magic = 15710030631939833023,
        .shift = 29,
    }, .{
        .value = 661914481,
        .magic = 14961933298877385037,
        .shift = 29,
    }, .{
        .value = 695010221,
        .magic = 3562364989407487505,
        .shift = 27,
    }, .{
        .value = 729760741,
        .magic = 3392728519731045041,
        .shift = 27,
    }, .{
        .value = 766248787,
        .magic = 12924679924202010123,
        .shift = 29,
    }, .{
        .value = 804561257,
        .magic = 6154609253253566869,
        .shift = 28,
    }, .{
        .value = 844789403,
        .magic = 11723064090427566833,
        .shift = 29,
    }, .{
        .value = 887028911,
        .magic = 11164822466855358449,
        .shift = 29,
    }, .{
        .value = 931380407,
        .magic = 166143182471598347,
        .shift = 23,
    }, .{
        .value = 977949439,
        .magic = 10126822430012194321,
        .shift = 29,
    }, .{
        .value = 1026846941,
        .magic = 2411148127061285709,
        .shift = 27,
    }, .{
        .value = 1078189297,
        .magic = 18370652244163470303,
        .shift = 30,
    }, .{
        .value = 1132098761,
        .magic = 17495859293291890105,
        .shift = 30,
    }, .{
        .value = 1188703709,
        .magic = 16662722996993765079,
        .shift = 30,
    }, .{
        .value = 1248138943,
        .magic = 991828711240989037,
        .shift = 26,
    }, .{
        .value = 1310545897,
        .magic = 7556790141385671897,
        .shift = 29,
    }, .{
        .value = 1376073217,
        .magic = 14393885720519829287,
        .shift = 30,
    }, .{
        .value = 1444876883,
        .magic = 13708462542109952491,
        .shift = 30,
    }, .{
        .value = 1517120861,
        .magic = 13055677459678727863,
        .shift = 30,
    }, .{
        .value = 1592977037,
        .magic = 12433977495286446115,
        .shift = 30,
    }, .{
        .value = 1672625909,
        .magic = 1480235398273243267,
        .shift = 27,
    }, .{
        .value = 1756257211,
        .magic = 11277983944782268227,
        .shift = 30,
    }, .{
        .value = 1844070071,
        .magic = 2685234273368086727,
        .shift = 28,
    }, .{
        .value = 1936273601,
        .magic = 10229463758807960115,
        .shift = 30,
    }, .{
        .value = 2033087339,
        .magic = 2435586539817373335,
        .shift = 28,
    }, .{
        .value = 2134741709,
        .magic = 9278424900333497161,
        .shift = 30,
    }, .{
        .value = 2241478829,
        .magic = 8836595006968091421,
        .shift = 30,
    }, .{
        .value = 2353552771,
        .magic = 16831609533148712559,
        .shift = 31,
    }, .{
        .value = 2471230409,
        .magic = 8015052160426083685,
        .shift = 30,
    }, .{
        .value = 2594791931,
        .magic = 7633383005369799109,
        .shift = 30,
    }, .{
        .value = 2724531541,
        .magic = 14539777081307853649,
        .shift = 31,
    }, .{
        .value = 2860758139,
        .magic = 13847406642694924025,
        .shift = 31,
    }, .{
        .value = 3003796087,
        .magic = 1648500768268535633,
        .shift = 28,
    }, .{
        .value = 3153985903,
        .magic = 12560005807081176671,
        .shift = 31,
    }, .{
        .value = 3311685211,
        .magic = 1495238780755457829,
        .shift = 28,
    }, .{
        .value = 3477269557,
        .magic = 2848073798117412443,
        .shift = 29,
    }, .{
        .value = 3651133121,
        .magic = 678112793075221469,
        .shift = 27,
    }, .{
        .value = 3833689799,
        .magic = 1291643407985999417,
        .shift = 28,
    }, .{
        .value = 4025374307,
        .magic = 9841092588146280131,
        .shift = 31,
    }, .{
        .value = 4226643191,
        .magic = 2343117189397746397,
        .shift = 29,
    }, .{
        .value = 4437975361,
        .magic = 17852321400993992043,
        .shift = 32,
    }, .{
        .value = 4659874133,
        .magic = 17002210843677381703,
        .shift = 32,
    }, .{
        .value = 4892867927,
        .magic = 16192581466804905563,
        .shift = 32,
    }, .{
        .value = 5137511359,
        .magic = 7710753025924778067,
        .shift = 31,
    }, .{
        .value = 5394386939,
        .magic = 7343574294000449121,
        .shift = 31,
    }, .{
        .value = 5664106297,
        .magic = 1748470066589049079,
        .shift = 29,
    }, .{
        .value = 5947311613,
        .magic = 3330419173811346145,
        .shift = 30,
    }, .{
        .value = 6244677209,
        .magic = 6343655553571170791,
        .shift = 31,
    }, .{
        .value = 6556911073,
        .magic = 377598544650989893,
        .shift = 27,
    }, .{
        .value = 6884756651,
        .magic = 1438470641201903855,
        .shift = 29,
    }, .{
        .value = 7228994671,
        .magic = 5479888014864490249,
        .shift = 31,
    }, .{
        .value = 7590444419,
        .magic = 10437881913204526107,
        .shift = 32,
    }, .{
        .value = 7969966657,
        .magic = 9940839896071391757,
        .shift = 32,
    }, .{
        .value = 8368465003,
        .magic = 9467466552810095751,
        .shift = 32,
    }, .{
        .value = 8786888267,
        .magic = 18033269595975923793,
        .shift = 33,
    }, .{
        .value = 9226232699,
        .magic = 8587271218820614487,
        .shift = 32,
    }, .{
        .value = 9687544343,
        .magic = 16356707068187576831,
        .shift = 33,
    }, .{
        .value = 10171921577,
        .magic = 15577816229611762685,
        .shift = 33,
    }, .{
        .value = 10680517669,
        .magic = 14836015438506801387,
        .shift = 33,
    }, .{
        .value = 11214543667,
        .magic = 14129538368538654083,
        .shift = 33,
    }, .{
        .value = 11775270853,
        .magic = 3364175801275912171,
        .shift = 31,
    }, .{
        .value = 12364034467,
        .magic = 12815907740426770131,
        .shift = 33,
    }, .{
        .value = 12982236217,
        .magic = 6102813197199147651,
        .shift = 32,
    }, .{
        .value = 13631348041,
        .magic = 1453050759836151439,
        .shift = 30,
    }, .{
        .value = 14312915467,
        .magic = 11070862913559934825,
        .shift = 33,
    }, .{
        .value = 15028561283,
        .magic = 10543678935372956631,
        .shift = 33,
    }, .{
        .value = 15779989387,
        .magic = 10041598960710928087,
        .shift = 33,
    }, .{
        .value = 16568988859,
        .magic = 9563427580099906155,
        .shift = 33,
    }, .{
        .value = 17397438323,
        .magic = 18216052511483149943,
        .shift = 34,
    }, .{
        .value = 18267310249,
        .magic = 8674310715076566125,
        .shift = 33,
    }, .{
        .value = 19180675771,
        .magic = 2065312073989917443,
        .shift = 31,
    }, .{
        .value = 20139709561,
        .magic = 15735711038790255491,
        .shift = 34,
    }, .{
        .value = 21146695051,
        .magic = 936649466065357335,
        .shift = 30,
    }, .{
        .value = 22204029811,
        .magic = 3568188440956526943,
        .shift = 32,
    }, .{
        .value = 23314231351,
        .magic = 6796549396930134083,
        .shift = 33,
    }, .{
        .value = 24479942941,
        .magic = 12945808363232710297,
        .shift = 34,
    }, .{
        .value = 25703940113,
        .magic = 12329341286349166121,
        .shift = 34,
    }, .{
        .value = 26989137127,
        .magic = 11742229792890160463,
        .shift = 34,
    }, .{
        .value = 28338593999,
        .magic = 11183075987052866009,
        .shift = 34,
    }, .{
        .value = 29755523717,
        .magic = 10650548552637237737,
        .shift = 34,
    }, .{
        .value = 31243299917,
        .magic = 10143379569346319199,
        .shift = 34,
    }, .{
        .value = 32805464957,
        .magic = 301886296300453383,
        .shift = 29,
    }, .{
        .value = 34445738207,
        .magic = 18400688535260071187,
        .shift = 35,
    }, .{
        .value = 36168025123,
        .magic = 8762232634469334069,
        .shift = 34,
    }, .{
        .value = 37976426413,
        .magic = 16689966907922255975,
        .shift = 35,
    }, .{
        .value = 39875247739,
        .magic = 15895206576840941963,
        .shift = 35,
    }, .{
        .value = 41869010171,
        .magic = 15138291961655333511,
        .shift = 35,
    }, .{
        .value = 43962460741,
        .magic = 7208710447854895029,
        .shift = 34,
    }, .{
        .value = 46160583811,
        .magic = 6865438516865931117,
        .shift = 34,
    }, .{
        .value = 48468613051,
        .magic = 6538512866534744747,
        .shift = 34,
    }, .{
        .value = 50892043747,
        .magic = 12454310211337850455,
        .shift = 35,
    }, .{
        .value = 53436645961,
        .magic = 2965311953601575993,
        .shift = 33,
    }, .{
        .value = 56108478299,
        .magic = 353013327558361135,
        .shift = 30,
    }, .{
        .value = 58913902231,
        .magic = 10758501408188866449,
        .shift = 35,
    }, .{
        .value = 61859597357,
        .magic = 10246191814929286119,
        .shift = 35,
    }, .{
        .value = 64952577353,
        .magic = 1219784737465925721,
        .shift = 32,
    }, .{
        .value = 68200206227,
        .magic = 2323399499718769013,
        .shift = 33,
    }, .{
        .value = 71610216569,
        .magic = 2212761427356502081,
        .shift = 33,
    }, .{
        .value = 75190727407,
        .magic = 16859134682479683775,
        .shift = 36,
    }, .{
        .value = 78950263811,
        .magic = 16056318738375259177,
        .shift = 36,
    }, .{
        .value = 82897777007,
        .magic = 15291732130780627285,
        .shift = 36,
    }, .{
        .value = 87042665867,
        .magic = 14563554408652673137,
        .shift = 36,
    }, .{
        .value = 91394799161,
        .magic = 6935025908832903385,
        .shift = 35,
    }, .{
        .value = 95964539119,
        .magic = 13209573159688603261,
        .shift = 36,
    }, .{
        .value = 100762766171,
        .magic = 3145136463594489011,
        .shift = 34,
    }, .{
        .value = 105800904527,
        .magic = 5990736118445611451,
        .shift = 35,
    }, .{
        .value = 111090949819,
        .magic = 11410925933153033577,
        .shift = 36,
    }, .{
        .value = 116645497313,
        .magic = 10867548507480633553,
        .shift = 36,
    }, .{
        .value = 122477772247,
        .magic = 2587511547956163001,
        .shift = 34,
    }, .{
        .value = 128601660959,
        .magic = 9857186841718740025,
        .shift = 36,
    }, .{
        .value = 135031744009,
        .magic = 9387796991970563815,
        .shift = 36,
    }, .{
        .value = 141783331211,
        .magic = 17881518079748447215,
        .shift = 37,
    }, .{
        .value = 148872497797,
        .magic = 17030017215896735325,
        .shift = 37,
    }, .{
        .value = 156316122691,
        .magic = 8109532007354575905,
        .shift = 36,
    }, .{
        .value = 164131928839,
        .magic = 3861681907947633321,
        .shift = 35,
    }, .{
        .value = 172338525313,
        .magic = 14711169170397987639,
        .shift = 37,
    }, .{
        .value = 180955451639,
        .magic = 7005318650234144005,
        .shift = 36,
    }, .{
        .value = 190003224311,
        .magic = 3335866022340022861,
        .shift = 35,
    }, .{
        .value = 199503385547,
        .magic = 794253814761447975,
        .shift = 33,
    }, .{
        .value = 209478554867,
        .magic = 12102915270091234561,
        .shift = 37,
    }, .{
        .value = 219952482619,
        .magic = 1440823246382769897,
        .shift = 34,
    }, .{
        .value = 230950106813,
        .magic = 5488850460912081057,
        .shift = 36,
    }, .{
        .value = 242497612171,
        .magic = 10454953258132132847,
        .shift = 37,
    }, .{
        .value = 254622492793,
        .magic = 9957098340552254979,
        .shift = 37,
    }, .{
        .value = 267353617439,
        .magic = 9482950800300724571,
        .shift = 37,
    }, .{
        .value = 280721298331,
        .magic = 18062763427854137777,
        .shift = 38,
    }, .{
        .value = 294757363253,
        .magic = 2150328979466685855,
        .shift = 35,
    }, .{
        .value = 309495231443,
        .magic = 511983090303967127,
        .shift = 33,
    }, .{
        .value = 324969993053,
        .magic = 7801647089437490025,
        .shift = 37,
    }, .{
        .value = 341218492723,
        .magic = 7430140084800760217,
        .shift = 37,
    }, .{
        .value = 358279417381,
        .magic = 7076323889854882177,
        .shift = 37,
    }, .{
        .value = 376193388269,
        .magic = 13478712170473192985,
        .shift = 38,
    }, .{
        .value = 395003057699,
        .magic = 3209217183311537233,
        .shift = 36,
    }, .{
        .value = 414753210583,
        .magic = 12225589269786240019,
        .shift = 38,
    }, .{
        .value = 435490871201,
        .magic = 5821709174900925211,
        .shift = 37,
    }, .{
        .value = 457265414773,
        .magic = 11088969856664348349,
        .shift = 38,
    }, .{
        .value = 480128685587,
        .magic = 5280461835678132219,
        .shift = 37,
    }, .{
        .value = 504135119923,
        .magic = 5029011271509298283,
        .shift = 37,
    }, .{
        .value = 529341875947,
        .magic = 2394767272021290201,
        .shift = 36,
    }, .{
        .value = 555808969759,
        .magic = 18245845881586049375,
        .shift = 39,
    }, .{
        .value = 583599418277,
        .magic = 17376996076806244003,
        .shift = 39,
    }, .{
        .value = 612779389213,
        .magic = 16549520072550591999,
        .shift = 39,
    }, .{
        .value = 643418358719,
        .magic = 7880723843516254105,
        .shift = 38,
    }, .{
        .value = 675589276709,
        .magic = 1876362819734705443,
        .shift = 36,
    }, .{
        .value = 709368740617,
        .magic = 14296097672707064803,
        .shift = 39,
    }, .{
        .value = 744837177653,
        .magic = 13615331116769731263,
        .shift = 39,
    }, .{
        .value = 782079036559,
        .magic = 3241745503896006575,
        .shift = 37,
    }, .{
        .value = 821182988387,
        .magic = 6174753340753922271,
        .shift = 38,
    }, .{
        .value = 862242137849,
        .magic = 2940358733546901847,
        .shift = 37,
    }, .{
        .value = 905354244917,
        .magic = 5600683300908115055,
        .shift = 38,
    }, .{
        .value = 950621957303,
        .magic = 5333984095316578539,
        .shift = 38,
    }, .{
        .value = 998153055223,
        .magic = 10159969704806606005,
        .shift = 39,
    }, .{
        .value = 1048060707989,
        .magic = 2419040405895140425,
        .shift = 37,
    }, .{
        .value = 1100463743389,
        .magic = 9215392022453072055,
        .shift = 39,
    }, .{
        .value = 1155486930613,
        .magic = 17553127660986700359,
        .shift = 40,
    }, .{
        .value = 1213261277161,
        .magic = 16717264438795890829,
        .shift = 40,
    }, .{
        .value = 1273924341023,
        .magic = 7960602113687645885,
        .shift = 39,
    }, .{
        .value = 1337620558103,
        .magic = 3790762911198071633,
        .shift = 38,
    }, .{
        .value = 1404501586093,
        .magic = 14441001565596421675,
        .shift = 40,
    }, .{
        .value = 1474726665421,
        .magic = 13753334824159781815,
        .shift = 40,
    }, .{
        .value = 1548462998851,
        .magic = 13098414116902856733,
        .shift = 40,
    }, .{
        .value = 1625886148903,
        .magic = 6237340055248147143,
        .shift = 39,
    }, .{
        .value = 1707180456391,
        .magic = 11880647723983982373,
        .shift = 40,
    }, .{
        .value = 1792539479293,
        .magic = 2828725648437504227,
        .shift = 38,
    }, .{
        .value = 1882166453477,
        .magic = 5388048853538744859,
        .shift = 39,
    }, .{
        .value = 1976274776167,
        .magic = 10262950197132788655,
        .shift = 40,
    }, .{
        .value = 2075088514987,
        .magic = 9774238282928733535,
        .shift = 40,
    }, .{
        .value = 2178842940751,
        .magic = 9308798364631441885,
        .shift = 40,
    }, .{
        .value = 2287785087839,
        .magic = 8865522251834443073,
        .shift = 40,
    }, .{
        .value = 2402174342237,
        .magic = 16886709051070694853,
        .shift = 41,
    }, .{
        .value = 2522283059347,
        .magic = 4020645012162638243,
        .shift = 39,
    }, .{
        .value = 2648397212317,
        .magic = 59831026966646059,
        .shift = 33,
    }, .{
        .value = 2780817072931,
        .magic = 14587374193782458005,
        .shift = 41,
    }, .{
        .value = 2919857926577,
        .magic = 13892737327414481677,
        .shift = 41,
    }, .{
        .value = 3065850822911,
        .magic = 13231178407039185457,
        .shift = 41,
    }, .{
        .value = 3219143364077,
        .magic = 12601122292338221701,
        .shift = 41,
    }, .{
        .value = 3380100532351,
        .magic = 1500133606199607175,
        .shift = 38,
    }, .{
        .value = 3549105559033,
        .magic = 5714794690180439967,
        .shift = 40,
    }, .{
        .value = 3726560837047,
        .magic = 2721330804802297305,
        .shift = 39,
    }, .{
        .value = 3912888879007,
        .magic = 5183487247099864809,
        .shift = 40,
    }, .{
        .value = 4108533323047,
        .magic = 9873309041879540653,
        .shift = 41,
    }, .{
        .value = 4313959989413,
        .magic = 9403151467991011841,
        .shift = 41,
    }, .{
        .value = 4529657988913,
        .magic = 17910764700819207529,
        .shift = 42,
    }, .{
        .value = 4756140888377,
        .magic = 17057871143571528337,
        .shift = 42,
    }, .{
        .value = 4993947932801,
        .magic = 8122795782644732113,
        .shift = 41,
    }, .{
        .value = 5243645329459,
        .magic = 15471991966889383297,
        .shift = 42,
    }, .{
        .value = 5505827595941,
        .magic = 1841903805579041879,
        .shift = 39,
    }, .{
        .value = 5781118975739,
        .magic = 14033552804409441543,
        .shift = 42,
    }, .{
        .value = 6070174924579,
        .magic = 6682644192517521899,
        .shift = 41,
    }, .{
        .value = 6373683670811,
        .magic = 12728846080979664861,
        .shift = 42,
    }, .{
        .value = 6692367854377,
        .magic = 12122710553267865813,
        .shift = 42,
    }, .{
        .value = 7026986247119,
        .magic = 11545438622121836423,
        .shift = 42,
    }, .{
        .value = 7378335559501,
        .magic = 5497827915276701915,
        .shift = 41,
    }, .{
        .value = 7747252337609,
        .magic = 5236026585887956299,
        .shift = 41,
    }, .{
        .value = 8134614954497,
        .magic = 9973383973110660139,
        .shift = 42,
    }, .{
        .value = 8541345702271,
        .magic = 9498460926717399687,
        .shift = 42,
    }, .{
        .value = 8968412987389,
        .magic = 9046153263535892081,
        .shift = 42,
    }, .{
        .value = 9416833636757,
        .magic = 17230768121023400007,
        .shift = 43,
    }, .{
        .value = 9887675318611,
        .magic = 16410255353328815421,
        .shift = 43,
    }, .{
        .value = 10382059084633,
        .magic = 3907203655520063397,
        .shift = 41,
    }, .{
        .value = 10901162038883,
        .magic = 14884585354337090951,
        .shift = 43,
    }, .{
        .value = 11446220140841,
        .magic = 14175795575541981435,
        .shift = 43,
    }, .{
        .value = 12018531147923,
        .magic = 13500757690947486301,
        .shift = 43,
    }, .{
        .value = 12619457705359,
        .magic = 6428932233764215863,
        .shift = 42,
    }, .{
        .value = 13250430590651,
        .magic = 12245585207147708807,
        .shift = 43,
    }, .{
        .value = 13912952120191,
        .magic = 5831231051019596017,
        .shift = 42,
    }, .{
        .value = 14608599726313,
        .magic = 11107106763761352371,
        .shift = 43,
    }, .{
        .value = 15339029712647,
        .magic = 5289098458927649999,
        .shift = 42,
    }, .{
        .value = 16105981198301,
        .magic = 10074473255086743393,
        .shift = 43,
    }, .{
        .value = 16911280258291,
        .magic = 9594736433373422667,
        .shift = 43,
    }, .{
        .value = 17756844271213,
        .magic = 4568922111128284349,
        .shift = 42,
    }, .{
        .value = 18644686484807,
        .magic = 17405417566171854693,
        .shift = 44,
    }, .{
        .value = 19576920809087,
        .magic = 16576588158225335937,
        .shift = 44,
    }, .{
        .value = 20555766849589,
        .magic = 15787226817320866675,
        .shift = 44,
    }, .{
        .value = 21583555192079,
        .magic = 15035454111726809437,
        .shift = 44,
    }, .{
        .value = 22662732951713,
        .magic = 14319480106387498043,
        .shift = 44,
    }, .{
        .value = 23795869599331,
        .magic = 3409400025325721667,
        .shift = 42,
    }, .{
        .value = 24985663079317,
        .magic = 811761910791206579,
        .shift = 40,
    }, .{
        .value = 26234946233311,
        .magic = 6184852653640651897,
        .shift = 43,
    }, .{
        .value = 27546693545051,
        .magic = 5890335860594224949,
        .shift = 43,
    }, .{
        .value = 28924028222329,
        .magic = 5609843676751468661,
        .shift = 43,
    }, .{
        .value = 30370229633461,
        .magic = 10685416527140183503,
        .shift = 44,
    }, .{
        .value = 31888741115167,
        .magic = 10176587168694421405,
        .shift = 44,
    }, .{
        .value = 33483178170971,
        .magic = 4845993889847879495,
        .shift = 43,
    }, .{
        .value = 35157337079519,
        .magic = 9230464552091343439,
        .shift = 44,
    }, .{
        .value = 36915203933497,
        .magic = 8790918621038886521,
        .shift = 44,
    }, .{
        .value = 38760964130257,
        .magic = 16744606897180142191,
        .shift = 45,
    }, .{
        .value = 40699012336781,
        .magic = 15947244663976718855,
        .shift = 45,
    }, .{
        .value = 42733962953639,
        .magic = 7593926030461736757,
        .shift = 44,
    }, .{
        .value = 44870661101341,
        .magic = 14464621010396844739,
        .shift = 45,
    }, .{
        .value = 47114194156493,
        .magic = 13775829533686441975,
        .shift = 45,
    }, .{
        .value = 49469903864351,
        .magic = 13119837651121100035,
        .shift = 45,
    }, .{
        .value = 51943399057603,
        .magic = 12495083477249903497,
        .shift = 45,
    }, .{
        .value = 54540569010611,
        .magic = 5950039751057434971,
        .shift = 44,
    }, .{
        .value = 57267597461141,
        .magic = 11333409049633318315,
        .shift = 45,
    }, .{
        .value = 60130977334199,
        .magic = 10793722904412513581,
        .shift = 45,
    }, .{
        .value = 63137526200921,
        .magic = 2569934024859631801,
        .shift = 43,
    }, .{
        .value = 66294402511313,
        .magic = 4895112428278515971,
        .shift = 44,
    }, .{
        .value = 69609122636917,
        .magic = 9324023672906322075,
        .shift = 45,
    }, .{
        .value = 73089578768803,
        .magic = 17760045091240381233,
        .shift = 46,
    }, .{
        .value = 76744057707277,
        .magic = 8457164329158356045,
        .shift = 45,
    }, .{
        .value = 80581260592649,
        .magic = 8054442218245238749,
        .shift = 45,
    }, .{
        .value = 84610323622289,
        .magic = 7670897350709066695,
        .shift = 45,
    }, .{
        .value = 88840839803449,
        .magic = 14611233048962159455,
        .shift = 46,
    }, .{
        .value = 93282881793631,
        .magic = 1739432505828650429,
        .shift = 43,
    }, .{
        .value = 97947025883323,
        .magic = 13252819092026398845,
        .shift = 46,
    }, .{
        .value = 102844377177559,
        .magic = 12621732468587997881,
        .shift = 46,
    }, .{
        .value = 107986596036437,
        .magic = 3005174397282855247,
        .shift = 44,
    }, .{
        .value = 113385925838287,
        .magic = 2862070854554389677,
        .shift = 44,
    }, .{
        .value = 119055222130219,
        .magic = 10903127064967487137,
        .shift = 46,
    }, .{
        .value = 125007983236757,
        .magic = 10383930538062026525,
        .shift = 46,
    }, .{
        .value = 131258382398683,
        .magic = 9889457655290526595,
        .shift = 46,
    }, .{
        .value = 137821301518801,
        .magic = 4709265550132063961,
        .shift = 45,
    }, .{
        .value = 144712366594753,
        .magic = 4485014809649214363,
        .shift = 45,
    }, .{
        .value = 151947984924497,
        .magic = 17085770703424864501,
        .shift = 47,
    }, .{
        .value = 159545384170751,
        .magic = 16272162574687374111,
        .shift = 47,
    }, .{
        .value = 167522653379297,
        .magic = 3874324422544417459,
        .shift = 45,
    }, .{
        .value = 175898786048299,
        .magic = 3689832783374856379,
        .shift = 45,
    }, .{
        .value = 184693725350723,
        .magic = 14056505841427335531,
        .shift = 47,
    }, .{
        .value = 193928411618287,
        .magic = 836696776275316481,
        .shift = 43,
    }, .{
        .value = 203624832199223,
        .magic = 12749665162289181271,
        .shift = 47,
    }, .{
        .value = 213806073809197,
        .magic = 12142538249798490477,
        .shift = 47,
    }, .{
        .value = 224496377499701,
        .magic = 5782161071331477379,
        .shift = 46,
    }, .{
        .value = 235721196374689,
        .magic = 11013640135869342889,
        .shift = 47,
    }, .{
        .value = 247507256193427,
        .magic = 5244590540890088057,
        .shift = 46,
    }, .{
        .value = 259882619003297,
        .magic = 4994848134177218265,
        .shift = 46,
    }, .{
        .value = 272876749953557,
        .magic = 4756998223024263429,
        .shift = 46,
    }, .{
        .value = 286520587451237,
        .magic = 4530474498118312127,
        .shift = 46,
    }, .{
        .value = 300846616823833,
        .magic = 17258950469020182321,
        .shift = 48,
    }, .{
        .value = 315888947665051,
        .magic = 16437095684779754913,
        .shift = 48,
    }, .{
        .value = 331683395048363,
        .magic = 15654376842644579785,
        .shift = 48,
    }, .{
        .value = 348267564800807,
        .magic = 14908930326327064615,
        .shift = 48,
    }, .{
        .value = 365680943040869,
        .magic = 7099490631583896161,
        .shift = 47,
    }, .{
        .value = 383964990193007,
        .magic = 3380709824562927589,
        .shift = 46,
    }, .{
        .value = 403163239702661,
        .magic = 6439447284881708537,
        .shift = 47,
    }, .{
        .value = 423321401687831,
        .magic = 12265613875964088503,
        .shift = 48,
    }, .{
        .value = 444487471772237,
        .magic = 11681537024727323577,
        .shift = 48,
    }, .{
        .value = 466711845360847,
        .magic = 11125273356883209411,
        .shift = 48,
    }, .{
        .value = 490047437628913,
        .magic = 1324437304390794345,
        .shift = 45,
    }, .{
        .value = 514549809510377,
        .magic = 10090950890596168477,
        .shift = 48,
    }, .{
        .value = 540277299986003,
        .magic = 4805214709806746285,
        .shift = 47,
    }, .{
        .value = 567291164985341,
        .magic = 18305579846881621631,
        .shift = 49,
    }, .{
        .value = 595655723234653,
        .magic = 8716942784228685827,
        .shift = 48,
    }, .{
        .value = 625438509396409,
        .magic = 4150925135346838281,
        .shift = 47,
    }, .{
        .value = 656710434866231,
        .magic = 3953262033663646175,
        .shift = 47,
    }, .{
        .value = 689545956609611,
        .magic = 15060045842526680921,
        .shift = 49,
    }, .{
        .value = 724023254440627,
        .magic = 14342900802395755517,
        .shift = 49,
    }, .{
        .value = 760224417162697,
        .magic = 6829952763045250629,
        .shift = 48,
    }, .{
        .value = 798235638020831,
        .magic = 13009433834371919813,
        .shift = 49,
    }, .{
        .value = 838147419921883,
        .magic = 6194968492557979815,
        .shift = 48,
    }, .{
        .value = 880054790918011,
        .magic = 5899969992912134795,
        .shift = 48,
    }, .{
        .value = 924057530463983,
        .magic = 5619019040868265331,
        .shift = 48,
    }, .{
        .value = 970260406987181,
        .magic = 10702893411177660935,
        .shift = 49,
    }, .{
        .value = 1018773427336681,
        .magic = 5096615910083895315,
        .shift = 48,
    }, .{
        .value = 1069712098703531,
        .magic = 4853919914365542211,
        .shift = 48,
    }, .{
        .value = 1123197703638737,
        .magic = 4622780870824204707,
        .shift = 48,
    }, .{
        .value = 1179357588820721,
        .magic = 8805296896807656935,
        .shift = 49,
    }, .{
        .value = 1238325468261769,
        .magic = 16771994089157279929,
        .shift = 50,
    }, .{
        .value = 1300241741674879,
        .magic = 15973327703959049479,
        .shift = 50,
    }, .{
        .value = 1365253828758623,
        .magic = 15212693051389570375,
        .shift = 50,
    }, .{
        .value = 1433516520196571,
        .magic = 905517443535082831,
        .shift = 46,
    }, .{
        .value = 1505192346206447,
        .magic = 13798361044343684347,
        .shift = 50,
    }, .{
        .value = 1580451963516779,
        .magic = 1642662029088523821,
        .shift = 47,
    }, .{
        .value = 1659474561692683,
        .magic = 6257760110813178781,
        .shift = 49,
    }, .{
        .value = 1742448289777331,
        .magic = 11919543068215483887,
        .shift = 50,
    }, .{
        .value = 1829570704266313,
        .magic = 1418993222406515683,
        .shift = 47,
    }, .{
        .value = 1921049239479793,
        .magic = 10811376932620146933,
        .shift = 50,
    }, .{
        .value = 2017101701453837,
        .magic = 5148274729818978869,
        .shift = 49,
    }, .{
        .value = 2117956786526611,
        .magic = 1225779697575899805,
        .shift = 47,
    }, .{
        .value = 2223854625852991,
        .magic = 9339273886292362273,
        .shift = 50,
    }, .{
        .value = 2335047357145673,
        .magic = 17789093116747109497,
        .shift = 51,
    }, .{
        .value = 2451799725002977,
        .magic = 16941993444520916045,
        .shift = 51,
    }, .{
        .value = 2574389711253163,
        .magic = 8067615925962224553,
        .shift = 50,
    }, .{
        .value = 2703109196815823,
        .magic = 7683443739011637173,
        .shift = 50,
    }, .{
        .value = 2838264656656643,
        .magic = 14635130931450588711,
        .shift = 51,
    }, .{
        .value = 2980177889489539,
        .magic = 13938219934714547767,
        .shift = 51,
    }, .{
        .value = 3129186783964027,
        .magic = 13274495175918570045,
        .shift = 51,
    }, .{
        .value = 3285646123162259,
        .magic = 12642376358017567823,
        .shift = 51,
    }, .{
        .value = 3449928429320413,
        .magic = 12040358436207064185,
        .shift = 51,
    }, .{
        .value = 3622424850786461,
        .magic = 11467008034482831693,
        .shift = 51,
    }, .{
        .value = 3803546093325871,
        .magic = 10920960032840542433,
        .shift = 51,
    }, .{
        .value = 3993723397992173,
        .magic = 10400914316990970787,
        .shift = 51,
    }, .{
        .value = 4193409567891821,
        .magic = 4952816341424225327,
        .shift = 50,
    }, .{
        .value = 4403080046286421,
        .magic = 9433935888427076685,
        .shift = 51,
    }, .{
        .value = 4623234048600743,
        .magic = 561543802882563973,
        .shift = 47,
    }, .{
        .value = 4854395751030779,
        .magic = 17113715897373382279,
        .shift = 52,
    }, .{
        .value = 5097115538582321,
        .magic = 4074694261279374295,
        .shift = 50,
    }, .{
        .value = 5351971315511461,
        .magic = 7761322402436868687,
        .shift = 51,
    }, .{
        .value = 5619569881287097,
        .magic = 7391735621368363567,
        .shift = 51,
    }, .{
        .value = 5900548375351481,
        .magic = 7039748210826978143,
        .shift = 51,
    }, .{
        .value = 6195575794119307,
        .magic = 13409044211098460693,
        .shift = 52,
    }, .{
        .value = 6505354583825287,
        .magic = 99769674189720465,
        .shift = 45,
    }, .{
        .value = 6830622313016639,
        .magic = 12162398377413386333,
        .shift = 52,
    }, .{
        .value = 7172153428667531,
        .magic = 11583236549917413811,
        .shift = 52,
    }, .{
        .value = 7530761100100921,
        .magic = 11031653857064183927,
        .shift = 52,
    }, .{
        .value = 7907299155105991,
        .magic = 5253168503363881197,
        .shift = 51,
    }, .{
        .value = 8302664112861337,
        .magic = 1250754405562821859,
        .shift = 49,
    }, .{
        .value = 8717797318504493,
        .magic = 4764778687858320261,
        .shift = 51,
    }, .{
        .value = 9153687184429741,
        .magic = 9075768929253920203,
        .shift = 52,
    }, .{
        .value = 9611371543651247,
        .magic = 17287178912864575827,
        .shift = 53,
    }, .{
        .value = 10091940120833861,
        .magic = 8231989958506898739,
        .shift = 52,
    }, .{
        .value = 10596537126875629,
        .magic = 15679980873346362883,
        .shift = 53,
    }, .{
        .value = 11126363983219531,
        .magic = 7466657558736282379,
        .shift = 52,
    }, .{
        .value = 11682682182380519,
        .magic = 14222204873783381069,
        .shift = 53,
    }, .{
        .value = 12266816291499617,
        .magic = 3386239255662689889,
        .shift = 51,
    }, .{
        .value = 12880157106074683,
        .magic = 1612494883648889287,
        .shift = 50,
    }, .{
        .value = 13524164961378517,
        .magic = 12285675303991446719,
        .shift = 53,
    }, .{
        .value = 14200373209447571,
        .magic = 11700643146658415093,
        .shift = 53,
    }, .{
        .value = 14910391869919981,
        .magic = 5571734831742090673,
        .shift = 52,
    }, .{
        .value = 15655911463415981,
        .magic = 2653207062734328731,
        .shift = 51,
    }, .{
        .value = 16438707036586829,
        .magic = 10107455477083126973,
        .shift = 53,
    }, .{
        .value = 17260642388416249,
        .magic = 1203268509176557259,
        .shift = 50,
    }, .{
        .value = 18123674507837099,
        .magic = 9167760069916607741,
        .shift = 53,
    }, .{
        .value = 19029858233228981,
        .magic = 17462400133174466113,
        .shift = 54,
    }, .{
        .value = 19981351144890479,
        .magic = 16630857269689926985,
        .shift = 54,
    }, .{
        .value = 20980418702135003,
        .magic = 15838911685418978043,
        .shift = 54,
    }, .{
        .value = 22029439637241899,
        .magic = 15084677795637022075,
        .shift = 54,
    }, .{
        .value = 23130911619104053,
        .magic = 14366359805368555777,
        .shift = 54,
    }, .{
        .value = 24287457200059267,
        .magic = 13682247433684332441,
        .shift = 54,
    }, .{
        .value = 25501830060062243,
        .magic = 13030711841604119671,
        .shift = 54,
    }, .{
        .value = 26776921563065419,
        .magic = 193909402404822747,
        .shift = 48,
    }, .{
        .value = 28115767641218743,
        .magic = 11819239765627268945,
        .shift = 54,
    }, .{
        .value = 29521556023279703,
        .magic = 2814104706101728523,
        .shift = 52,
    }, .{
        .value = 30997633824443711,
        .magic = 670024930024220583,
        .shift = 50,
    }, .{
        .value = 32547515515665947,
        .magic = 10209903695607154963,
        .shift = 54,
    }, .{
        .value = 34174891291449269,
        .magic = 4861858902670070285,
        .shift = 53,
    }, .{
        .value = 35883635856021739,
        .magic = 9260683624133465519,
        .shift = 54,
    }, .{
        .value = 37677817648822853,
        .magic = 4409849344825456605,
        .shift = 53,
    }, .{
        .value = 39561708531264013,
        .magic = 4199856518881385401,
        .shift = 53,
    }, .{
        .value = 41539793957827267,
        .magic = 15999453405262400027,
        .shift = 55,
    }, .{
        .value = 43616783655718643,
        .magic = 15237574671678471797,
        .shift = 55,
    }, .{
        .value = 45797622838504627,
        .magic = 14511975877789004329,
        .shift = 55,
    }, .{
        .value = 48087503980429867,
        .magic = 13820929407418096875,
        .shift = 55,
    }, .{
        .value = 50491879179451373,
        .magic = 13162789911826755631,
        .shift = 55,
    }, .{
        .value = 53016473138423957,
        .magic = 6267995196107977057,
        .shift = 54,
    }, .{
        .value = 55667296795345217,
        .magic = 11939038468777085827,
        .shift = 55,
    }, .{
        .value = 58450661635112503,
        .magic = 5685256413703371757,
        .shift = 54,
    }, .{
        .value = 61373194716868207,
        .magic = 10829059835625456101,
        .shift = 55,
    }, .{
        .value = 64441854452711651,
        .magic = 10313390319643286139,
        .shift = 55,
    }, .{
        .value = 67663947175347401,
        .magic = 2455569123724585861,
        .shift = 53,
    }, .{
        .value = 71047144534114849,
        .magic = 4677274521380158413,
        .shift = 54,
    }, .{
        .value = 74599501760820593,
        .magic = 1113636790804799599,
        .shift = 52,
    }, .{
        .value = 78329476848861697,
        .magic = 16969703478930263497,
        .shift = 56,
    }, .{
        .value = 82245950691304817,
        .magic = 2020202795110744791,
        .shift = 53,
    }, .{
        .value = 86358248225870107,
        .magic = 7696010648040928157,
        .shift = 55,
    }, .{
        .value = 90676160637163627,
        .magic = 7329533950515168489,
        .shift = 55,
    }, .{
        .value = 95209968669021809,
        .magic = 3490254262150080209,
        .shift = 54,
    }, .{
        .value = 99970467102473027,
        .magic = 6648103356476334773,
        .shift = 55,
    }, .{
        .value = 104968990457596879,
        .magic = 12663054012335851553,
        .shift = 56,
    }, .{
        .value = 110217439980476921,
        .magic = 12060051440319836951,
        .shift = 56,
    }, .{
        .value = 115728311979501007,
        .magic = 2871440819123764749,
        .shift = 54,
    }, .{
        .value = 121514727578476087,
        .magic = 2734705542022632427,
        .shift = 54,
    }, .{
        .value = 127590463957399943,
        .magic = 5208962937185964419,
        .shift = 55,
    }, .{
        .value = 133969987155270011,
        .magic = 1240229270758562301,
        .shift = 53,
    }, .{
        .value = 140668486513033511,
        .magic = 9449365872446188997,
        .shift = 56,
    }, .{
        .value = 147701910838685293,
        .magic = 17998792137992727975,
        .shift = 57,
    }, .{
        .value = 155087006380619567,
        .magic = 17141706798088311323,
        .shift = 57,
    }, .{
        .value = 162841356699650569,
        .magic = 8162717522899194683,
        .shift = 56,
    }, .{
        .value = 170983424534633129,
        .magic = 7774016688475422073,
        .shift = 56,
    }, .{
        .value = 179532595761364817,
        .magic = 14807650835191277537,
        .shift = 57,
    }, .{
        .value = 188509225549433093,
        .magic = 14102524604944071215,
        .shift = 57,
    }, .{
        .value = 197934686826904793,
        .magic = 13430975814232445699,
        .shift = 57,
    }, .{
        .value = 207831421168250129,
        .magic = 12791405537364228069,
        .shift = 57,
    }, .{
        .value = 218222992226662673,
        .magic = 6091145493982964699,
        .shift = 56,
    }, .{
        .value = 229134141837995873,
        .magic = 11602181893300881781,
        .shift = 57,
    }, .{
        .value = 240590848929895999,
        .magic = 5524848520619459883,
        .shift = 56,
    }, .{
        .value = 252620391376390847,
        .magic = 10523520991656112061,
        .shift = 57,
    }, .{
        .value = 265251410945210549,
        .magic = 10022400944434386407,
        .shift = 57,
    }, .{
        .value = 278513981492471381,
        .magic = 9545143756604167093,
        .shift = 57,
    }, .{
        .value = 292439680567094981,
        .magic = 18181226203055554443,
        .shift = 58,
    }, .{
        .value = 307061664595449749,
        .magic = 270553961354993353,
        .shift = 52,
    }, .{
        .value = 322414747825222259,
        .magic = 16490908120685307981,
        .shift = 58,
    }, .{
        .value = 338535485216483417,
        .magic = 7852813390802526565,
        .shift = 57,
    }, .{
        .value = 355462259477307673,
        .magic = 7478869896002404461,
        .shift = 57,
    }, .{
        .value = 373235372451173171,
        .magic = 14245466468576004133,
        .shift = 58,
    }, .{
        .value = 391897141073731841,
        .magic = 13567110922453336873,
        .shift = 58,
    }, .{
        .value = 411491998127418553,
        .magic = 12921058021384126589,
        .shift = 58,
    }, .{
        .value = 432066598033789489,
        .magic = 6152884772087679209,
        .shift = 57,
    }, .{
        .value = 453669927935478967,
        .magic = 11719780518262246021,
        .shift = 58,
    }, .{
        .value = 476353424332252979,
        .magic = 2790423932919582013,
        .shift = 56,
    }, .{
        .value = 500171095548865693,
        .magic = 5315093205561107905,
        .shift = 57,
    }, .{
        .value = 525179650326309179,
        .magic = 10123987058211630223,
        .shift = 58,
    }, .{
        .value = 551438632842624641,
        .magic = 9641892436392028731,
        .shift = 58,
    }, .{
        .value = 579010564484755961,
        .magic = 18365509402651480507,
        .shift = 59,
    }, .{
        .value = 607961092708993897,
        .magic = 17490961335858548895,
        .shift = 59,
    }, .{
        .value = 638359147344443641,
        .magic = 16658058415103378617,
        .shift = 59,
    }, .{
        .value = 670277104711665961,
        .magic = 495775548068552833,
        .shift = 54,
    }, .{
        .value = 703790959947249319,
        .magic = 15109350036374942195,
        .shift = 59,
    }, .{
        .value = 738980507944611817,
        .magic = 3597464294374986081,
        .shift = 57,
    }, .{
        .value = 775929533341842413,
        .magic = 13704625883333280217,
        .shift = 59,
    }, .{
        .value = 814726010008934533,
        .magic = 13052024650793600217,
        .shift = 59,
    }, .{
        .value = 855462310509381313,
        .magic = 6215249833711237811,
        .shift = 58,
    }, .{
        .value = 898235426034850433,
        .magic = 184977673622358257,
        .shift = 53,
    }, .{
        .value = 943147197336593023,
        .magic = 11274829630315169133,
        .shift = 59,
    }, .{
        .value = 990304557203422691,
        .magic = 10737932981252541849,
        .shift = 59,
    }, .{
        .value = 1039819785063593969,
        .magic = 10226602839288133683,
        .shift = 59,
    }, .{
        .value = 1091810774316773677,
        .magic = 9739621751702984375,
        .shift = 59,
    }, .{
        .value = 1146401313032612359,
        .magic = 9275830239717127991,
        .shift = 59,
    }, .{
        .value = 1203721378684243091,
        .magic = 8834124037825835345,
        .shift = 59,
    }, .{
        .value = 1263907447618455529,
        .magic = 8413451464596031775,
        .shift = 59,
    }, .{
        .value = 1327102819999378337,
        .magic = 16025621837325774429,
        .shift = 60,
    }, .{
        .value = 1393457960999347253,
        .magic = 15262496987929308989,
        .shift = 60,
    }, .{
        .value = 1463130859049314661,
        .magic = 908481963567220745,
        .shift = 56,
    }, .{
        .value = 1536287402001780431,
        .magic = 6921767341464538843,
        .shift = 59,
    }, .{
        .value = 1613101772101869463,
        .magic = 1648039843205842571,
        .shift = 57,
    }, .{
        .value = 1693756860706962959,
        .magic = 6278247021736543043,
        .shift = 59,
    }, .{
        .value = 1778444703742311217,
        .magic = 11958565755688652675,
        .shift = 60,
    }, .{
        .value = 1867366938929426969,
        .magic = 5694555121756500691,
        .shift = 59,
    }, .{
        .value = 1960735285875898321,
        .magic = 10846771660488572725,
        .shift = 60,
    }, .{
        .value = 2058772050169693399,
        .magic = 5165129362137415177,
        .shift = 59,
    }, .{
        .value = 2161710652678178227,
        .magic = 2459585410541626095,
        .shift = 58,
    }, .{
        .value = 2269796185312087163,
        .magic = 9369849183015718355,
        .shift = 60,
    }, .{
        .value = 2383285994577691523,
        .magic = 17847331777172796853,
        .shift = 61,
    }, .{
        .value = 2502450294306576181,
        .magic = 8498729417701331557,
        .shift = 60,
    }, .{
        .value = 2627572809021905011,
        .magic = 4047014008429205471,
        .shift = 59,
    }, .{
        .value = 2758951449473000293,
        .magic = 7708598111293724619,
        .shift = 60,
    }, .{
        .value = 2896899021946650319,
        .magic = 14683044021511856359,
        .shift = 61,
    }, .{
        .value = 3041743973043982909,
        .magic = 6991925724529455239,
        .shift = 60,
    }, .{
        .value = 3193831171696182079,
        .magic = 13317953761008486067,
        .shift = 61,
    }, .{
        .value = 3353522730280991201,
        .magic = 12683765486674748567,
        .shift = 61,
    }, .{
        .value = 3521198866795040881,
        .magic = 12079776653975950605,
        .shift = 61,
    }, .{
        .value = 3697258810134792971,
        .magic = 11504549194262809957,
        .shift = 61,
    }, .{
        .value = 3882121750641532621,
        .magic = 1369589189793191661,
        .shift = 58,
    }, .{
        .value = 4076227838173609267,
        .magic = 5217482627783587261,
        .shift = 60,
    }, .{
        .value = 4280039230082289733,
        .magic = 38820555266246929,
        .shift = 53,
    }, .{
        .value = 4494041191586404219,
        .magic = 2366205273371241387,
        .shift = 59,
    }, .{
        .value = 4718743251165724471,
        .magic = 9014115327128538539,
        .shift = 61,
    }, .{
        .value = 4954680413724010873,
        .magic = 8584871740122417347,
        .shift = 61,
    }, .{
        .value = 5202414434410211531,
        .magic = 16352136647852223159,
        .shift = 62,
    }, .{
        .value = 5462535156130722121,
        .magic = 7786731737072487199,
        .shift = 61,
    }, .{
        .value = 5735661913937258341,
        .magic = 14831869975376165799,
        .shift = 62,
    }, .{
        .value = 6022445009634121283,
        .magic = 1765698806592400683,
        .shift = 59,
    }, .{
        .value = 6323567260115827453,
        .magic = 6726471644161526299,
        .shift = 61,
    }, .{
        .value = 6639745623121618859,
        .magic = 12812326941260050029,
        .shift = 62,
    }, .{
        .value = 6971732904277699861,
        .magic = 12202216134533380877,
        .shift = 62,
    }, .{
        .value = 7320319549491584971,
        .magic = 11621158223365124459,
        .shift = 62,
    }, .{
        .value = 7686335526966164273,
        .magic = 11067769736538213693,
        .shift = 62,
    }, .{
        .value = 8070652303314472717,
        .magic = 5270366541208673037,
        .shift = 61,
    }, .{
        .value = 8474184918480196373,
        .magic = 627424588239127741,
        .shift = 58,
    }, .{
        .value = 8897894164404206201,
        .magic = 2390188907577629487,
        .shift = 60,
    }, .{
        .value = 9342788872624416551,
        .magic = 9105481552676683721,
        .shift = 62,
    }, .{
        .value = 9809928316255637389,
        .magic = 17343774386050826117,
        .shift = 63,
    }, .{
        .value = 10300424732068419343,
        .magic = 16517880367667453309,
        .shift = 63,
    }, .{
        .value = 10815445968671840317,
        .magic = 7865657317936882523,
        .shift = 62,
    }, .{
        .value = 11356218267105432353,
        .magic = 7491102207558935723,
        .shift = 62,
    }, .{
        .value = 11924029180460704009,
        .magic = 7134383054818033999,
        .shift = 62,
    }, .{
        .value = 12520230639483739223,
        .magic = 6794650528398127611,
        .shift = 62,
    }, .{
        .value = 13146242171457926281,
        .magic = 3235547870665775029,
        .shift = 61,
    }, .{
        .value = 13803554280030822631,
        .magic = 12325896650155333411,
        .shift = 63,
    }, .{
        .value = 14493731994032363789,
        .magic = 11738949190624127037,
        .shift = 63,
    }, .{
        .value = 15218418593733982013,
        .magic = 1397493951264777025,
        .shift = 60,
    }, .{
        .value = 15979339523420681189,
        .magic = 1330946620252168589,
        .shift = 60,
    }, .{
        .value = 16778306499591715409,
        .magic = 10140545678111760581,
        .shift = 63,
    }, .{
        .value = 17617221824571301183,
        .magic = 9657662550582629123,
        .shift = 63,
    } };
};
