// 23 âm giữa (âm đệm + nguyên âm)

// 2 x 16 = 32-byte
0a, // a
0e, // e
0i, // i
0o, // o
0u, // u
0y, // y
az, // â
aw, // ă
ez, // ê
oz, // ô
ow, // ơ
uw, // ư
oa, // oa
oe, // oe
oo, // boong
uy, // uy
// => use `_mm256_cmpeq_epi16`

// 4 x 7 = 28-byte
0iez, // iê
0oaw, // oă (loắt choắt)
0uaz, // uâ (tuân)
0uez, // uê (tuềnh toàng)
0uoz, // uô
uwow, // ươ
uyez, // uyê
// => use `_mm256_cmpeq_epi32`
