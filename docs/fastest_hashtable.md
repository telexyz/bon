Hashtable lý tưởng được dùng bởi nhiều threads mà ko conflict, cache friendly (flat_map), tận dụng SIMD intrinsics cho các thao tác comparing, hashing, probing ...

NGUỒN: https://github.com/search?q=simd+hash+table

https://github.com/matmuher/hash_table_optimize thử nghiệm nhiều hàm hash và nhiều cách optimize hashtable bao gồm SIMD

https://github.com/michaelvlach/ADbHash
The ADbHash is a hash table inspired by google's "Swiss table" presented at CppCon 2017 by Matt Kulukundis. It is based on open-addressing hash table storing extra byte per element (key-value pair). In this byte there are stored a control bit (controlling whether the element is empty or full) and the rest of the byte is taken from the hash of the key. When searching through the table 16 of these control bytes are loaded from the position the element we look for is supposed to be. Then they are compared to a byte constructed from the hash we search for. This is achieved by using Single Instruction Multiple Data (SIMD) and thus a typical search in this hash table will take exactly two instructions:

Compare 16 bytes with 1 byte. - and Jump to the matching element.

https://github.com/telekons/42nd-at-threadmill a nearly lock-free* hash table based on Cliff Click's NonBlockingHashMap, and Abseil's flat_hash_map. use SSE2 intrinsics for fast probing, and optionally use AVX2 for faster byte broadcasting.

https://github.com/efficient/libcuckoo


https://www.youtube.com/watch?v=ncHmEUmJZf4
CppCon 2017: Matt Kulukundis “Designing a Fast, Efficient, Cache-friendly Hash Table, Step by Step”

https://www.youtube.com/watch?v=JZE3_0qvrMg
Abseil's Open Source Hashtables: 2 Years In - Matt Kulukundis - CppCon 2019.


- - -


In practice, cuckoo hashing is about 20–30% slower than linear probing, which is the fastest of the common approaches.[1] The reason is that cuckoo hashing often causes two cache misses per search, to check the two locations where a key might be stored, while linear probing usually causes only one cache miss per search. However, because of its worst case guarantees on search time, cuckoo hashing can still be valuable when real-time response rates are required. One advantage of cuckoo hashing is its link-list free property, which fits GPU processing well.

- - -

https://probablydance.com/2017/02/26/i-wrote-the-fastest-hashtable

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