`hash_count_pair.zig` have to use ArrayBitSet instead of IntegerBitSet due to

src/hash_count_pair.zig:148:46: error: expected type '*bit_set.IntegerBitSet(64)', found '*align(4) bit_set.IntegerBitSet(64)'
                    self.entries[i].in_chunks.set(curr_chunk); // TODO: enable later
const InChunksType = std.bit_set.ArrayBitSet(u64, MAX_CHUNKS);
// const InChunksType = std.bit_set.IntegerBitSet(MAX_CHUNKS); // TODO: Enable later

`byte_pair_encoding.zig` have problem with random number. => Temporary disable dropout.