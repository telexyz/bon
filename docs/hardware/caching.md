## Cache-line
https://youtu.be/Pa_l3aHCoGc?t=1391

Dữ liệu được đọc và ghi theo từng mẻ, 64/128-bytes, gọi là cache-line.
Khi ghi dù chỉ 1 bit, bạn đang ghi 64/128-bytes


### Invalidate cache protocol
https://en.wikipedia.org/wiki/MESI_protocol


### Prefetching (CPU)

CPU tự động prefect dữ liệu. Sử dụng `__builtin_prefetch` để gợi ý (cần đo lường hiệu quả)

![](false-sharing.png)

To fix a false sharing problem you need to make sure that the data accessed by the different threads is allocated to different cache lines.

![](mem-perf-tip1.png)

![](mem-perf-tip2.png)