> Hashtable lý tưởng được dùng bởi nhiều threads mà ko conflict, cache friendly (flat_map), tận dụng SIMD intrinsics cho các thao tác comparing, hashing, probing ...

https://martin.ankerl.com/2022/08/27/hashmap-bench-01

- - -

## [All hash table sizes you will ever need](http://databasearchitects.blogspot.com/2020/01/all-hash-table-sizes-you-will-ever-need.html)

Khi chọn kích thước bảng băm ta thường có 2 lựa chọn: số nguyên tố hoặc lũy thừa 2. Lũy thừa bậc 2 dễ sử dụng nhưng 1/ tốn không gian lưu trữ và 2/ đòi hỏi hàm băm phải tốt hơn.

Các số nguyên tố dễ dàng hơn cho hàm băm và chúng ta có nhiều lựa chọn hơn liên quan đến kích thước, dẫn đến chi phí thấp hơn. Nhưng việc sử dụng một số nguyên tố cần phải tính toán chia mô đun, điều này rất tốn kém. Và chúng ta phải tìm một số nguyên tố phù hợp trong thời gian chạy, điều này cũng không hề đơn giản.

May mắn thay chúng ta có thể giải quyết cả 2 vấn đề trên cùng một lúc. Chúng ta có thể tính toán trước các số nguyên tố cần dùng. Nếu chọn khoảng cách giữa chúng là 5% thì trong khoảng trong khoảng 0 - 2^64 chỉ có 841 số nguyên tố. Với phép chia mô đun, ta có thể tính toán trước magic numbers trong cuốn sách Hacker's Delight cho mỗi số nguyên tố đã chọn để sử dụng phép nhân để thực hiện phép chia mô đun. Và ta có thể bỏ qua các số nguyên tố mà có magic numbers không thuận tiện cho việc tính toán, đơn giản là chọn số nguyên tố hợp lý tiếp theo.

https://db.in.tum.de/~neumann/primes.hpp
```cpp
   struct Number {
      uint64_t value, magic, shift;
   };
   /// All pre-computed numbers
   static constexpr unsigned primeCount = 814;
   static constexpr Number primes[primeCount] = {
         {3ull, 12297829382473034411ull, 1},
         {5ull, 14757395258967641293ull, 2},
         {11ull, 3353953467947191203ull, 1},
         {13ull, 5675921253449092805ull, 2},
         {17ull, 17361641481138401521ull, 4},
         {19ull, 15534100272597517151ull, 4},
         {37ull, 15953940820505558155ull, 5},
         {41ull, 14397458789236723213ull, 5},
         ... // `ull` suffix makes it type unsigned long long.
```

- - -

## [I Wrote The Fastest Hashtable](https://probablydance.com/2017/02/26/i-wrote-the-fastest-hashtable)

## Open addressing

`Open addressing` nghĩa là dữ liệu của key và value được lưu trữ một mảng liên tục - không như `std::unordered_map` cấp phát bộ nhớ riêng cho value.


## Linear probing

`Linear probing` nghĩa là khi thêm 1 phần tử vào mảng mà slot hiện tại ko còn trống thì `thăm dò` slot tiếp theo, nếu slot tiếp theo đầy thì `thăm dò` slot tiếp theo nữa ... Cách tiếp cận đơn giản này tồn tại vài vấn đề => dùng hạn chế số lần `thăm dò` để giải quyết.


## Robin Hood hashing

`Robin Hood hashing` nghĩa là khi thăm dò tuyến tính (linear probing), cố gắng đặt mọi phần tử gần vị trí lý tưởng nhất có thể - bằng cách khi `thêm` và `xoá` phần tử, ta `lấy` của phần tử `giàu` chia cho phần tử `nghèo`. Phần tử càng `giàu` thì càng gần vị trí lý tưởng. Phần tử càng `nghèo` thì càng xa vị trí lý tưởng.

Khi thêm phần tử mới sử dụng thăm dò tuyến tính, tính khoảng cách từ vị trí hiện tại tới vị trí lý tưởng, nếu nó xa hơn hơn khoảng cách của phần tử hiện tại thì hoán đổi phần tử mới với phần tử hiện tại và tìm vị trí mới cho phần tử hiện tại.


## Prime number amount of slots

`Prime number amount of slots` nghĩa là mảng lưu trữ có kích cỡ được mở rộng theo số nguyên tố, từ 5 slots lên 11 slots, lên 23, lên 47 slots ... Để tìm vị trí để thêm phần tử mới, sử dụng hàm tính số dư (modulo) để ánh xạ giá trị hash của một phần tử vào slot. Cách làm phổ biến khác là sử dụng cấp số mũ của 2 (từ 4 slots lên 8, lên 16, lên 32 slots ...)


## Upper limit on the probe count

`Upper limit on the probe count` giới hạn số lượng slots được thăm dò trước khi mở rộng mảng lưu trữ. Cần chọn giới hạn số lần thăm sao cho cân bằng giữa việc mở rộng mảng lưu trữ và số thao tác phải thực hiện khi `thêm` và `xoá` phần tử => chọn `log2(n)` với `n` size của mảng lưu trữ, sẽ giúp mảng chỉ mở rộng khi đầy khoảng 2/3 khi `thêm` các giá trị ngẫu nhiên. Trên thực tế mảng mở rộng khi đầu khoảng 60%, có vài trường hợp 55%. Vậy nên set `max_load_factor = 0.5` để bảng mở rộng khi đầy 1/2 kể cả khi chưa đạt giới hạn lượt thăm dò. 

Cách đặt giới hạn số lần thăm dò là một mẹo để tối ưu hoá code. Giả sử cần băm lại bảng để chứ 1k phần tử. Bảng băm sẽ mở rộng tới 1009 slots vì đó là số nguyên tố gần nhất với 1k. Mẹo ở đây là thay vì cấp bộ nhớ cho 1 mảng 1009 slots, ta cấp 1 mảng 1019 slots nhưng mọi theo tác khác đều vờ như chỉ có 1009 slots. Giả sử có 2 phần tử được băm tới vị trí 1008, chỉ cần chèn thêm phần tử mới vào vị trí 1009 chẳng hạn mà không cần phải kiểm tra xem vị trí đó đã được cấp phát bộ nhớ chưa (bounds checking) - là nhờ vào giới hạn số lần thăm là `log2(n)` đảm bảo rằng nó sẽ không bao giờ đạt với phần tử cuối cùng 1018 vì `log2(1008) = 10` là giới hạn số lần thăm (1008+10=1018 < 1019).

Ko cần bound checking khiến code ngắn ngọn và `đẹp`:
```cpp
iterator find(const FindKey & key)
{
    size_t index = hash_policy.index_for_hash(hash_object(key));
    EntryPointer it = entries + index;
    for (int8_t distance = 0;; ++distance, ++it)
    {
        if (it->distance_from_desired < distance)
            return end();
        else if (compares_equal(key, it->value))
            return { it };
    }
}
```
. . .

## Kết luận

I think I wrote the fastest hash table there is. It’s definitely the fastest for lookups. The main new trick is to set an upper limit on the probe count. The probe count limit can be set to log2(n) which makes the worst case lookup time O(log(n)) instead of O(n). The probe count limit works great with Robin Hood hashing and allows some neat optimizations in the inner loop.