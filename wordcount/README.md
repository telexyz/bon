
`wordcount` Perf https://easyperf.net/blog/2022/05/28/Performance-analysis-and-tuning-contest-6#upd-july-20th-2022-results

Slides https://docs.google.com/presentation/d/16M90It8nOK-Oiy7j9Kw27o9boLFwr6GFy55XFVzaAVA

__Goal__: Split a text and count each word's frequency, then print the list sorted by frequency in decreasing order. Ties are printed in alphabetical order.

__Example__:
```sh
$ echo "apple pear apple art" | ./wordcount.exe
apple	2
art     1
pear    1
```

__Dataset__: complete snapshot of Hungarian Wikipedia (5.4 GB).

parsing: large input file (> 5GB) - exessive mem copy
hashing: large hashtable (> 1GB) - DRAM latency, DTLB misses

Naive Impl
* 75% parsing & hashing
* 13% sorting
* 12% others

Obervation
* 70% words occured one!
* Most of words (types) < 32 chars (90% of all words (tokens) < 20 chars)
* Most of words differ in first 32 chars (45% differ with others in first 10 chars)

- - -

Optimization

* Parsing: 
	- `mmap` file into the process address space
	- SIMD-based word parsing

* Hasing
	- More suitable hashtable and hash function
	- `Store first N chars` (of a string) into hashtable node (Small-String-Optimization)
	- `Use large page` for mitigating DTLB misses when acessing hashtable entries
	- `Prefetching` hashtable entries

* Aggregating
	- Cluster words into `extra-small, small, unique`

* Sorting
	- Multiple passes
	- Better algo: pdqsort, radix sort
	- `Composite keys` for fast string comparisons

* Impl
	- fstream -> mmap: 2.0x speedup
	- AVX2 word parse: 2.5x speedup

- - -


Hiện tại quá nửa thời gian nằm ở HashCount => Thử nghiệm:
* Hybrid Hashing
* SSO
* Hash prefetch
