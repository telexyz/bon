// Copyright 2022 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// THIS IS A GENERATED FILE! DO NOT EDIT DIRECTLY!
// Generated using unify.py, by concatenating, in order:
// #include "declare.h"
// #include "hash.h"
// #include "map_api.h"
// #include "policy.h"
// #include "set_api.h"

#ifndef CWISSTABLE_H_
#define CWISSTABLE_H_

#include "cwisstable/declare.h"
#include "cwisstable/hash.h"
#include "cwisstable/internal/absl_hash.h"
#include "cwisstable/internal/base.h"
#include "cwisstable/internal/bits.h"
#include "cwisstable/internal/extract.h"
#include "cwisstable/internal/raw_table.h"
#include "cwisstable/policy.h"
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/// declare.h //////////////////////////////////////////////////////////////////
/// SwissTable code generation macros.
///
/// This file is the entry-point for users of `cwisstable`. It exports six
/// macros for generating different kinds of tables. Four correspond to Abseil's
/// four SwissTable containers:
///
/// - `CWISS_DECLARE_FLAT_HASHSET(Set, Type)`
/// - `CWISS_DECLARE_FLAT_HASHMAP(Map, Key, Value)`
/// - `CWISS_DECLARE_NODE_HASHSET(Set, Type)`
/// - `CWISS_DECLARE_NODE_HASHMAP(Map, Key, Value)`
///
/// These expand to a type (with the same name as the first argument) and and
/// a collection of strongly-typed functions associated to it (the generated
/// API is described below). These macros use the default policy (see policy.h)
/// for each of the four containers; custom policies may be used instead via
/// the following macros:
///
/// - `CWISS_DECLARE_HASHSET_WITH(Set, Type, kPolicy)`
/// - `CWISS_DECLARE_HASHMAP_WITH(Map, Key, Value, kPolicy)`
///
/// `kPolicy` must be a constant global variable referring to an appropriate
/// property for the element types of the container.
///
/// The generated API is safe: the functions are well-typed and automatically
/// pass the correct policy pointer. Because the pointer is a constant
/// expression, it promotes devirtualization when inlining.
///
/// # Generated API
///
/// See `set_api.h` and `map_api.h` for detailed listings of what the generated
/// APIs look like.

CWISS_BEGIN
CWISS_BEGIN_EXTERN

/// Generates a new hash set type with inline storage and the default
/// plain-old-data policies.
///
/// See header documentation for examples of generated API.
#define CWISS_DECLARE_FLAT_HASHSET(HashSet_, Type_)                 \
  CWISS_DECLARE_FLAT_SET_POLICY(HashSet_##_kPolicy, Type_, (_, _)); \
  CWISS_DECLARE_HASHSET_WITH(HashSet_, Type_, HashSet_##_kPolicy)

/// Generates a new hash set type with outline storage and the default
/// plain-old-data policies.
///
/// See header documentation for examples of generated API.
#define CWISS_DECLARE_NODE_HASHSET(HashSet_, Type_)                 \
  CWISS_DECLARE_NODE_SET_POLICY(HashSet_##_kPolicy, Type_, (_, _)); \
  CWISS_DECLARE_HASHSET_WITH(HashSet_, Type_, HashSet_##_kPolicy)

/// Generates a new hash map type with inline storage and the default
/// plain-old-data policies.
///
/// See header documentation for examples of generated API.
#define CWISS_DECLARE_FLAT_HASHMAP(HashMap_, K_, V_)                 \
  CWISS_DECLARE_FLAT_MAP_POLICY(HashMap_##_kPolicy, K_, V_, (_, _)); \
  CWISS_DECLARE_HASHMAP_WITH(HashMap_, K_, V_, HashMap_##_kPolicy)

/// Generates a new hash map type with outline storage and the default
/// plain-old-data policies.
///
/// See header documentation for examples of generated API.
#define CWISS_DECLARE_NODE_HASHMAP(HashMap_, K_, V_)                 \
  CWISS_DECLARE_NODE_MAP_POLICY(HashMap_##_kPolicy, K_, V_, (_, _)); \
  CWISS_DECLARE_HASHMAP_WITH(HashMap_, K_, V_, HashMap_##_kPolicy)

/// Generates a new hash set type using the given policy.
///
/// See header documentation for examples of generated API.
#define CWISS_DECLARE_HASHSET_WITH(HashSet_, Type_, kPolicy_) \
  typedef Type_ HashSet_##_Entry;                             \
  typedef Type_ HashSet_##_Key;                               \
  CWISS_DECLARE_COMMON_(HashSet_, HashSet_##_Entry, HashSet_##_Key, kPolicy_)

/// Generates a new hash map type using the given policy.
///
/// See header documentation for examples of generated API.
#define CWISS_DECLARE_HASHMAP_WITH(HashMap_, K_, V_, kPolicy_) \
  typedef struct {                                             \
    K_ key;                                                    \
    V_ val;                                                    \
  } HashMap_##_Entry;                                          \
  typedef K_ HashMap_##_Key;                                   \
  CWISS_DECLARE_COMMON_(HashMap_, HashMap_##_Entry, HashMap_##_Key, kPolicy_)

/// Declares a heterogenous lookup for an existing SwissTable type.
///
/// This macro will expect to find the following functions:
///   - size_t <Table>_<Key>_hash(const Key*);
///   - bool <Table>_<Key>_eq(const Key*, const <Table>_Key*);
///
/// These functions will be used to build the heterogenous key policy.
#define CWISS_DECLARE_LOOKUP(HashSet_, Key_) \
  CWISS_DECLARE_LOOKUP_NAMED(HashSet_, Key_, Key_)

/// Declares a heterogenous lookup for an existing SwissTable type.
///
/// This is like `CWISS_DECLARE_LOOKUP`, but allows customizing the name used
/// in the `_by_` prefix on the names, as well as the names of the extension
/// point functions.
#define CWISS_DECLARE_LOOKUP_NAMED(HashSet_, LookupName_, Key_)                \
  CWISS_BEGIN                                                                  \
  static inline size_t HashSet_##_##LookupName_##_SyntheticHash(               \
      const void* val) {                                                       \
    return HashSet_##_##LookupName_##_hash((const Key_*)val);                  \
  }                                                                            \
  static inline bool HashSet_##_##LookupName_##_SyntheticEq(const void* a,     \
                                                            const void* b) {   \
    return HashSet_##_##LookupName_##_eq((const Key_*)a,                       \
                                         (const HashSet_##_Entry*)b);          \
  }                                                                            \
  static const CWISS_KeyPolicy HashSet_##_##LookupName_##_kPolicy = {          \
      HashSet_##_##LookupName_##_SyntheticHash,                                \
      HashSet_##_##LookupName_##_SyntheticEq,                                  \
  };                                                                           \
                                                                               \
  static inline const CWISS_KeyPolicy* HashSet_##_##LookupName_##_policy(      \
      void) {                                                                  \
    return &HashSet_##_##LookupName_##_kPolicy;                                \
  }                                                                            \
                                                                               \
  static inline HashSet_##_Insert HashSet_##_deferred_insert_by_##LookupName_( \
      HashSet_* self, const Key_* key) {                                       \
    CWISS_Insert ret = CWISS_RawTable_deferred_insert(                         \
        HashSet_##_policy(), &HashSet_##_##LookupName_##_kPolicy, &self->set_, \
        key);                                                                  \
    return (HashSet_##_Insert){{ret.iter}, ret.inserted};                      \
  }                                                                            \
  static inline HashSet_##_CIter HashSet_##_cfind_hinted_by_##LookupName_(     \
      const HashSet_* self, const Key_* key, size_t hash) {                    \
    return (HashSet_##_CIter){CWISS_RawTable_find_hinted(                      \
        HashSet_##_policy(), &HashSet_##_##LookupName_##_kPolicy, &self->set_, \
        key, hash)};                                                           \
  }                                                                            \
  static inline HashSet_##_Iter HashSet_##_find_hinted_by_##LookupName_(       \
      HashSet_* self, const Key_* key, size_t hash) {                          \
    return (HashSet_##_Iter){CWISS_RawTable_find_hinted(                       \
        HashSet_##_policy(), &HashSet_##_##LookupName_##_kPolicy, &self->set_, \
        key, hash)};                                                           \
  }                                                                            \
                                                                               \
  static inline HashSet_##_CIter HashSet_##_cfind_by_##LookupName_(            \
      const HashSet_* self, const Key_* key) {                                 \
    return (HashSet_##_CIter){CWISS_RawTable_find(                             \
        HashSet_##_policy(), &HashSet_##_##LookupName_##_kPolicy, &self->set_, \
        key)};                                                                 \
  }                                                                            \
  static inline HashSet_##_Iter HashSet_##_find_by_##LookupName_(              \
      HashSet_* self, const Key_* key) {                                       \
    return (HashSet_##_Iter){CWISS_RawTable_find(                              \
        HashSet_##_policy(), &HashSet_##_##LookupName_##_kPolicy, &self->set_, \
        key)};                                                                 \
  }                                                                            \
                                                                               \
  static inline bool HashSet_##_contains_by_##LookupName_(                     \
      const HashSet_* self, const Key_* key) {                                 \
    return CWISS_RawTable_contains(HashSet_##_policy(),                        \
                                   &HashSet_##_##LookupName_##_kPolicy,        \
                                   &self->set_, key);                          \
  }                                                                            \
                                                                               \
  static inline bool HashSet_##_erase_by_##LookupName_(HashSet_* self,         \
                                                       const Key_* key) {      \
    return CWISS_RawTable_erase(HashSet_##_policy(),                           \
                                &HashSet_##_##LookupName_##_kPolicy,           \
                                &self->set_, key);                             \
  }                                                                            \
                                                                               \
  CWISS_END                                                                    \
  /* Force a semicolon. */                                                     \
  struct HashSet_##_##LookupName_##_NeedsTrailingSemicolon_ {                  \
    int x;                                                                     \
  }

// ---- PUBLIC API ENDS HERE! ----

#define CWISS_DECLARE_COMMON_(HashSet_, Type_, Key_, kPolicy_)                 \
  CWISS_BEGIN                                                                  \
  static inline const CWISS_Policy* HashSet_##_policy(void) {                  \
    return &kPolicy_;                                                          \
  }                                                                            \
                                                                               \
  typedef struct {                                                             \
    CWISS_RawTable set_;                                                       \
  } HashSet_;                                                                  \
  static inline void HashSet_##_dump(const HashSet_* self) {                   \
    CWISS_RawTable_dump(&kPolicy_, &self->set_);                               \
  }                                                                            \
                                                                               \
  static inline HashSet_ HashSet_##_new(size_t bucket_count) {                 \
    return (HashSet_){CWISS_RawTable_new(&kPolicy_, bucket_count)};            \
  }                                                                            \
  static inline HashSet_ HashSet_##_dup(const HashSet_* that) {                \
    return (HashSet_){CWISS_RawTable_dup(&kPolicy_, &that->set_)};             \
  }                                                                            \
  static inline void HashSet_##_destroy(HashSet_* self) {                      \
    CWISS_RawTable_destroy(&kPolicy_, &self->set_);                            \
  }                                                                            \
                                                                               \
  typedef struct {                                                             \
    CWISS_RawIter it_;                                                         \
  } HashSet_##_Iter;                                                           \
  static inline HashSet_##_Iter HashSet_##_iter(HashSet_* self) {              \
    return (HashSet_##_Iter){CWISS_RawTable_iter(&kPolicy_, &self->set_)};     \
  }                                                                            \
  static inline Type_* HashSet_##_Iter_get(const HashSet_##_Iter* it) {        \
    return (Type_*)CWISS_RawIter_get(&kPolicy_, &it->it_);                     \
  }                                                                            \
  static inline Type_* HashSet_##_Iter_next(HashSet_##_Iter* it) {             \
    return (Type_*)CWISS_RawIter_next(&kPolicy_, &it->it_);                    \
  }                                                                            \
                                                                               \
  typedef struct {                                                             \
    CWISS_RawIter it_;                                                         \
  } HashSet_##_CIter;                                                          \
  static inline HashSet_##_CIter HashSet_##_citer(const HashSet_* self) {      \
    return (HashSet_##_CIter){CWISS_RawTable_citer(&kPolicy_, &self->set_)};   \
  }                                                                            \
  static inline const Type_* HashSet_##_CIter_get(                             \
      const HashSet_##_CIter* it) {                                            \
    return (const Type_*)CWISS_RawIter_get(&kPolicy_, &it->it_);               \
  }                                                                            \
  static inline const Type_* HashSet_##_CIter_next(HashSet_##_CIter* it) {     \
    return (const Type_*)CWISS_RawIter_next(&kPolicy_, &it->it_);              \
  }                                                                            \
  static inline HashSet_##_CIter HashSet_##_Iter_const(HashSet_##_Iter it) {   \
    return (HashSet_##_CIter){it.it_};                                         \
  }                                                                            \
                                                                               \
  static inline void HashSet_##_reserve(HashSet_* self, size_t n) {            \
    CWISS_RawTable_reserve(&kPolicy_, &self->set_, n);                         \
  }                                                                            \
  static inline void HashSet_##_rehash(HashSet_* self, size_t n) {             \
    CWISS_RawTable_rehash(&kPolicy_, &self->set_, n);                          \
  }                                                                            \
                                                                               \
  static inline bool HashSet_##_empty(const HashSet_* self) {                  \
    return CWISS_RawTable_empty(&kPolicy_, &self->set_);                       \
  }                                                                            \
  static inline size_t HashSet_##_size(const HashSet_* self) {                 \
    return CWISS_RawTable_size(&kPolicy_, &self->set_);                        \
  }                                                                            \
  static inline size_t HashSet_##_capacity(const HashSet_* self) {             \
    return CWISS_RawTable_capacity(&kPolicy_, &self->set_);                    \
  }                                                                            \
                                                                               \
  static inline void HashSet_##_clear(HashSet_* self) {                        \
    return CWISS_RawTable_clear(&kPolicy_, &self->set_);                       \
  }                                                                            \
                                                                               \
  typedef struct {                                                             \
    HashSet_##_Iter iter;                                                      \
    bool inserted;                                                             \
  } HashSet_##_Insert;                                                         \
  static inline HashSet_##_Insert HashSet_##_deferred_insert(                  \
      HashSet_* self, const Key_* key) {                                       \
    CWISS_Insert ret = CWISS_RawTable_deferred_insert(&kPolicy_, kPolicy_.key, \
                                                      &self->set_, key);       \
    return (HashSet_##_Insert){{ret.iter}, ret.inserted};                      \
  }                                                                            \
  static inline HashSet_##_Insert HashSet_##_insert(HashSet_* self,            \
                                                    const Type_* val) {        \
    CWISS_Insert ret = CWISS_RawTable_insert(&kPolicy_, &self->set_, val);     \
    return (HashSet_##_Insert){{ret.iter}, ret.inserted};                      \
  }                                                                            \
                                                                               \
  static inline HashSet_##_CIter HashSet_##_cfind_hinted(                      \
      const HashSet_* self, const Key_* key, size_t hash) {                    \
    return (HashSet_##_CIter){CWISS_RawTable_find_hinted(                      \
        &kPolicy_, kPolicy_.key, &self->set_, key, hash)};                     \
  }                                                                            \
  static inline HashSet_##_Iter HashSet_##_find_hinted(                        \
      HashSet_* self, const Key_* key, size_t hash) {                          \
    return (HashSet_##_Iter){CWISS_RawTable_find_hinted(                       \
        &kPolicy_, kPolicy_.key, &self->set_, key, hash)};                     \
  }                                                                            \
  static inline HashSet_##_CIter HashSet_##_cfind(const HashSet_* self,        \
                                                  const Key_* key) {           \
    return (HashSet_##_CIter){                                                 \
        CWISS_RawTable_find(&kPolicy_, kPolicy_.key, &self->set_, key)};       \
  }                                                                            \
  static inline HashSet_##_Iter HashSet_##_find(HashSet_* self,                \
                                                const Key_* key) {             \
    return (HashSet_##_Iter){                                                  \
        CWISS_RawTable_find(&kPolicy_, kPolicy_.key, &self->set_, key)};       \
  }                                                                            \
                                                                               \
  static inline bool HashSet_##_contains(const HashSet_* self,                 \
                                         const Key_* key) {                    \
    return CWISS_RawTable_contains(&kPolicy_, kPolicy_.key, &self->set_, key); \
  }                                                                            \
                                                                               \
  static inline void HashSet_##_erase_at(HashSet_##_Iter it) {                 \
    CWISS_RawTable_erase_at(&kPolicy_, it.it_);                                \
  }                                                                            \
  static inline bool HashSet_##_erase(HashSet_* self, const Key_* key) {       \
    return CWISS_RawTable_erase(&kPolicy_, kPolicy_.key, &self->set_, key);    \
  }                                                                            \
                                                                               \
  CWISS_END                                                                    \
  /* Force a semicolon. */ struct HashSet_##_NeedsTrailingSemicolon_ { int x; }

CWISS_END_EXTERN
CWISS_END
/// declare.h //////////////////////////////////////////////////////////////////

/// hash.h /////////////////////////////////////////////////////////////////////
/// Hash functions.
///
/// This file provides some hash functions to use with cwisstable types.
///
/// Every hash function defines four symbols:
///   - `CWISS_<Hash>_State`, the state of the hash function.
///   - `CWISS_<Hash>_kInit`, the initial value of the hash state.
///   - `void CWISS_<Hash>_Write(State*, const void*, size_t)`, write some more
///     data into the hash state.
///   - `size_t CWISS_<Hash>_Finish(State)`, digest the state into a final hash
///     value.
///
/// Currently available are two hashes: `FxHash`, which is small and fast, and
/// `AbslHash`, the hash function used by Abseil.
///
/// `AbslHash` is the default hash function.

CWISS_BEGIN
CWISS_BEGIN_EXTERN

typedef size_t CWISS_FxHash_State;
#define CWISS_FxHash_kInit ((CWISS_FxHash_State)0)
static inline void CWISS_FxHash_Write(CWISS_FxHash_State* state,
                                      const void* val, size_t len) {
  const size_t kSeed = (size_t)(UINT64_C(0x517cc1b727220a95));
  const uint32_t kRotate = 5;

  const char* p = (const char*)val;
  CWISS_FxHash_State state_ = *state;
  while (len > 0) {
    size_t word = 0;
    size_t to_read = len >= sizeof(state_) ? sizeof(state_) : len;
    memcpy(&word, p, to_read);

    state_ = CWISS_RotateLeft(state_, kRotate);
    state_ ^= word;
    state_ *= kSeed;

    len -= to_read;
    p += to_read;
  }
  *state = state_;
}
static inline size_t CWISS_FxHash_Finish(CWISS_FxHash_State state) {
  return state;
}

typedef CWISS_AbslHash_State_ CWISS_AbslHash_State;
#define CWISS_AbslHash_kInit CWISS_AbslHash_kInit_
static inline void CWISS_AbslHash_Write(CWISS_AbslHash_State* state,
                                        const void* val, size_t len) {
  const char* val8 = (const char*)val;
  if (CWISS_LIKELY(len < CWISS_AbslHash_kPiecewiseChunkSize)) {
    goto CWISS_AbslHash_Write_small;
  }

  while (len >= CWISS_AbslHash_kPiecewiseChunkSize) {
    CWISS_AbslHash_Mix(
        state, CWISS_AbslHash_Hash64(val8, CWISS_AbslHash_kPiecewiseChunkSize));
    len -= CWISS_AbslHash_kPiecewiseChunkSize;
    val8 += CWISS_AbslHash_kPiecewiseChunkSize;
  }

CWISS_AbslHash_Write_small:;
  uint64_t v;
  if (len > 16) {
    v = CWISS_AbslHash_Hash64(val8, len);
  } else if (len > 8) {
    CWISS_U128 p = CWISS_Load9To16(val8, len);
    CWISS_AbslHash_Mix(state, p.lo);
    v = p.hi;
  } else if (len >= 4) {
    v = CWISS_Load4To8(val8, len);
  } else if (len > 0) {
    v = CWISS_Load1To3(val8, len);
  } else {
    // Empty ranges have no effect.
    return;
  }

  CWISS_AbslHash_Mix(state, v);
}
static inline size_t CWISS_AbslHash_Finish(CWISS_AbslHash_State state) {
  return state;
}

CWISS_END_EXTERN
CWISS_END
/// hash.h /////////////////////////////////////////////////////////////////////

/// map_api.h //////////////////////////////////////////////////////////////////
/// Example API expansion of declare.h map macros.
///
/// Should be kept in sync with declare.h; unfortunately we don't have an easy
/// way to test this just yet.

// CWISS_DECLARE_FLAT_HASHMAP(MyMap, K, V) expands to:

/// Returns the policy used with this map type.
static inline const CWISS_Policy* MyMap_policy(void);

/// The generated type.
typedef struct {
  /* ... */
} MyMap;

/// A key-value pair in the map.
typedef struct {
  K key;
  V val;
} MyMap_Entry;

/// Constructs a new map with the given initial capacity.
static inline MyMap MyMap_new(size_t capacity);

/// Creates a deep copy of this map.
static inline MyMap MyMap_dup(const MyMap* self);

/// Destroys this map.
static inline void MyMap_destroy(const MyMap* self);

/// Dumps the internal contents of the table to stderr; intended only for
/// debugging.
///
/// The output of this function is not stable.
static inline void MyMap_dump(const MyMap* self);

/// Ensures that there is at least `n` spare capacity, potentially resizing
/// if necessary.
static inline void MyMap_reserve(MyMap* self, size_t n);

/// Resizes the table to have at least `n` buckets of capacity.
static inline void MyMap_rehash(MyMap* self, size_t n);

/// Returns whether the map is empty.
static inline size_t MyMap_empty(const MyMap* self);

/// Returns the number of elements stored in the table.
static inline size_t MyMap_size(const MyMap* self);

/// Returns the number of buckets in the table.
///
/// Note that this is *different* from the amount of elements that must be
/// in the table before a resize is triggered.
static inline size_t MyMap_capacity(const MyMap* self);

/// Erases every element in the map.
static inline void MyMap_clear(MyMap* self);

/// A non-mutating iterator into a `MyMap`.
typedef struct {
  /* ... */
} MyMap_CIter;

/// Creates a new non-mutating iterator fro this table.
static inline MyMap_CIter MyMap_citer(const MyMap* self);

/// Returns a pointer to the element this iterator is at; returns `NULL` if
/// this iterator has reached the end of the table.
static inline const MyMap_Entry* MyMap_CIter_get(const MyMap_CIter* it);

/// Advances this iterator, returning a pointer to the element the iterator
/// winds up pointing to (see `MyMap_CIter_get()`).
///
/// The iterator must not point to the end of the table.
static inline const MyMap_Entry* MyMap_CIter_next(const MyMap_CIter* it);

/// A mutating iterator into a `MyMap`.
typedef struct {
  /* ... */
} MyMap_Iter;

/// Creates a new mutating iterator fro this table.
static inline MyMap_Iter MyMap_iter(const MyMap* self);

/// Returns a pointer to the element this iterator is at; returns `NULL` if
/// this iterator has reached the end of the table.
static inline MyMap_Entry* MyMap_Iter_get(const MyMap_Iter* it);

/// Advances this iterator, returning a pointer to the element the iterator
/// winds up pointing to (see `MyMap_Iter_get()`).
///
/// The iterator must not point to the end of the table.
static inline MyMap_Entry* MyMap_Iter_next(const MyMap_Iter* it);

/// Checks if this map contains the given element.
///
/// In general, if you plan to use the element and not just check for it,
/// prefer `MyMap_find()` and friends.
static inline bool MyMap_contains(const MyMap* self, const K* key);

/// Searches the table for `key`, non-mutating iterator version.
///
/// If found, returns an iterator at the found element; otherwise, returns
/// an iterator that's already at the end: `get()` will return `NULL`.
static inline MyMap_CIter MyMap_cfind(const MyMap* self, const K* key);

/// Searches the table for `key`, mutating iterator version.
///
/// If found, returns an iterator at the found element; otherwise, returns
/// an iterator that's already at the end: `get()` will return `NULL`.
///
/// This function does not trigger rehashes.
static inline MyMap_Iter MyMap_find(MyMap* self, const K* key);

/// Like `MyMap_cfind`, but takes a pre-computed hash.
///
/// The hash must be correct for `key`.
static inline MyMap_CIter MyMap_cfind_hinted(const MyMap* self, const K* key,
                                             size_t hash);

/// Like `MyMap_find`, but takes a pre-computed hash.
///
/// The hash must be correct for `key`.
///
/// This function does not trigger rehashes.
static inline MyMap_Iter MyMap_find_hinted(MyMap* self, const K* key,
                                           size_t hash);

/// The return type of `MyMap_insert()`.
typedef struct {
  MyMap_Iter iter;
  bool inserted;
} MyMap_Insert;

/// Inserts `val` into the map if it isn't already present, initializing it by
/// copy.
///
/// Returns an iterator pointing to the element in the map and whether it was
/// just inserted or was already present.
static inline MyMap_Insert MyMap_insert(MyMap* self, const MyMap_Entry* val);

/// "Inserts" `val` into the table if it isn't already present.
///
/// This function does not perform insertion; it behaves exactly like
/// `MyMap_insert()` up until it would copy-initialize the new
/// element, instead returning a valid iterator pointing to uninitialized data.
///
/// This allows, for example, lazily constructing the parts of the element that
/// do not figure into the hash or equality. The initialized element must have
/// the same hash value and must compare equal to the value used for the initial
/// lookup; UB may otherwise result.
///
/// If this function returns `true` in `inserted`, the caller has *no choice*
/// but to insert, i.e., they may not change their minds at that point.
static inline MyMap_Insert MyMap_deferred_insert(MyMap* self, const K* key);

/// Looks up `key` and erases it from the map.
///
/// Returns `true` if erasure happened.
static inline bool MyMap_erase(MyMap* self, const K* key);

/// Erases (and destroys) the element pointed to by `it`.
///
/// Although the iterator doesn't point to anything now, this function does
/// not trigger rehashes and the erased iterator can still be safely
/// advanced (although not dereferenced until advanced).
static inline void MyMap_erase_at(MyMap_Iter it);

// CWISS_DECLARE_LOOKUP(MyMap, View) expands to:

/// Returns the policy used with this lookup extension.
static inline const CWISS_KeyPolicy* MyMap_View_policy(void);

/// Checks if this map contains the given element.
///
/// In general, if you plan to use the element and not just check for it,
/// prefer `MyMap_find()` and friends.
static inline bool MyMap_contains_by_View(const MyMap* self, const View* key);

/// Searches the table for `key`, non-mutating iterator version.
///
/// If found, returns an iterator at the found element; otherwise, returns
/// an iterator that's already at the end: `get()` will return `NULL`.
static inline MyMap_CIter MyMap_cfind_by_View(const MyMap* self,
                                              const View* key);

/// Searches the table for `key`, mutating iterator version.
///
/// If found, returns an iterator at the found element; otherwise, returns
/// an iterator that's already at the end: `get()` will return `NULL`.
///
/// This function does not trigger rehashes.
static inline MyMap_Iter MyMap_find_by_View(MyMap* self, const View* key);

/// Like `MyMap_cfind`, but takes a pre-computed hash.
///
/// The hash must be correct for `key`.
static inline MyMap_CIter MyMap_cfind_hinted_by_View(const MyMap* self,
                                                     const View* key,
                                                     size_t hash);

/// Like `MyMap_find`, but takes a pre-computed hash.
///
/// The hash must be correct for `key`.
///
/// This function does not trigger rehashes.
static inline MyMap_Iter MyMap_find_hinted_by_View(MyMap* self, const View* key,
                                                   size_t hash);

/// "Inserts" `key` into the table if it isn't already present.
///
/// This function does not perform insertion; it behaves exactly like
/// `MyMap_insert()` up until it would copy-initialize the new
/// element, instead returning a valid iterator pointing to uninitialized data.
///
/// This allows, for example, lazily constructing the parts of the element that
/// do not figure into the hash or equality. The initialized element must have
/// the same hash value and must compare equal to the value used for the initial
/// lookup; UB may otherwise result.
///
/// If this function returns `true` in `inserted`, the caller has *no choice*
/// but to insert, i.e., they may not change their minds at that point.
static inline MyMap_Insert MyMap_deferred_insert_by_View(MySet* self,
                                                         const View* key);

/// Looks up `key` and erases it from the map.
///
/// Returns `true` if erasure happened.
static inline bool MyMap_erase_by_View(MyMap* self, const View* key);

#error "This file is for demonstration purposes only."
/// map_api.h //////////////////////////////////////////////////////////////////

/// policy.h ///////////////////////////////////////////////////////////////////
/// Hash table policies.
///
/// Table policies are `cwisstable`'s generic code mechanism. All code in
/// `cwisstable`'s internals is completely agnostic to:
/// - The layout of the elements.
/// - The storage strategy for the elements (inline, indirect in the heap).
/// - Hashing, comparison, and allocation.
///
/// This information is provided to `cwisstable`'s internals by way of a
/// *policy*: a vtable describing how to move elements around, hash them,
/// compare them, allocate storage for them, and so on and on. This design is
/// inspired by Abseil's equivalent, which is a template parameter used for
/// sharing code between all the SwissTable-backed containers.
///
/// Unlike Abseil, policies are part of `cwisstable`'s public interface. Due to
/// C's lack of any mechanism for detecting the gross properties of types,
/// types with unwritten invariants, such as C strings (NUL-terminated byte
/// arrays), users must be able to carefully describe to `cwisstable` how to
/// correctly do things to their type. DESIGN.md goes into detailed rationale
/// for this polymorphism strategy.
///
/// # Defining a Policy
///
/// Policies are defined as read-only globals and passed around by pointer to
/// different `cwisstable` functions; macros are provided for doing this, since
/// most of these functions will not vary significantly from one type to
/// another. There are four of them:
///
/// - `CWISS_DECLARE_FLAT_SET_POLICY(kPolicy, Type, ...)`
/// - `CWISS_DECLARE_FLAT_MAP_POLICY(kPolicy, Key, Value, ...)`
/// - `CWISS_DECLARE_NODE_SET_POLICY(kPolicy, Type, ...)`
/// - `CWISS_DECLARE_NODE_MAP_POLICY(kPolicy, Key, Value, ...)`
///
/// These correspond to the four SwissTable types in Abseil: two map types and
/// two set types; "flat" means that elements are stored inline in the backing
/// array, whereas "node" means that the element is stored in its own heap
/// allocation, making it stable across rehashings (which SwissTable does more
/// or less whenever it feels like it).
///
/// Each macro expands to a read-only global variable definition (with the name
/// `kPolicy`, i.e, the first variable) dedicated for the specified type(s).
/// The arguments that follow are overrides for the default values of each field
/// in the policy; all but the size and alignment fields of `CWISS_ObjectPolicy`
/// may be overridden. To override the field `kPolicy.foo.bar`, pass
/// `(foo_bar, value)` to the macro. If multiple such pairs are passed in, the
/// first one found wins. `examples/stringmap.c` provides an example of how to
/// use this functionality.
///
/// For "common" uses, where the key and value are plain-old-data, `declare.h`
/// has dedicated macros, and fussing with policies directly is unnecessary.

CWISS_BEGIN
CWISS_BEGIN_EXTERN

/// A policy describing the basic laying properties of a type.
///
/// This type describes how to move values of a particular type around.
typedef struct {
  /// The layout of the stored object.
  size_t size, align;

  /// Performs a deep copy of `src` onto a fresh location `dst`.
  void (*copy)(void* dst, const void* src);

  /// Destroys an object.
  ///
  /// This member may, as an optimization, be null. This will cause it to
  /// behave as a no-op, and may be more efficient than making this an empty
  /// function.
  void (*dtor)(void* val);
} CWISS_ObjectPolicy;

/// A policy describing the hashing properties of a type.
///
/// This type describes the necessary information for putting a value into a
/// hash table.
///
/// A *heterogenous* key policy is one whose equality function expects different
/// argument types, which can be used for so-called heterogenous lookup: finding
/// an element of a table by comparing it to a somewhat different type. If the
/// table element is, for example, a `std::string`[1]-like type, it could still
/// be found via a non-owning version like a `std::string_view`[2]. This is
/// important for making efficient use of a SwissTable.
///
/// [1]: For non C++ programmers: a growable string type implemented as a
///      `struct { char* ptr; size_t size, capacity; }`.
/// [2]: Similarly, a `std::string_view` is a pointer-length pair to a string
///      *somewhere*; unlike a C-style string, it might be a substring of a
///      larger allocation elsewhere.
typedef struct {
  /// Computes the hash of a value.
  ///
  /// This function must be such that if two elements compare equal, they must
  /// have the same hash (but not vice-versa).
  ///
  /// If this policy is heterogenous, this function must be defined so that
  /// given the original key policy of the table's element type, if
  /// `hetero->eq(a, b)` holds, then `hetero->hash(a) == original->hash(b)`.
  /// In other words, the obvious condition for a hash table to work correctly
  /// with this policy.
  size_t (*hash)(const void* val);

  /// Compares two values for equality.
  ///
  /// This function is actually not symmetric: the first argument will always be
  /// the value being searched for, and the second will be a pointer to the
  /// candidate entry. In particular, this means they can be different types:
  /// in C++ parlance, `needle` could be a `std::string_view`, while `candidate`
  /// could be a `std::string`.
  bool (*eq)(const void* needle, const void* candidate);
} CWISS_KeyPolicy;

/// A policy for allocation.
///
/// This type provides access to a custom allocator.
typedef struct {
  /// Allocates memory.
  ///
  /// This function must never fail and never return null, unlike `malloc`. This
  /// function does not need to tolerate zero sized allocations.
  void* (*alloc)(size_t size, size_t align);

  /// Deallocates memory allocated by `alloc`.
  ///
  /// This function is passed the same size/alignment as was passed to `alloc`,
  /// allowing for sized-delete optimizations.
  void (*free)(void* array, size_t size, size_t align);
} CWISS_AllocPolicy;

/// A policy for allocating space for slots.
///
/// This allows us to distinguish between inline storage (more cache-friendly)
/// and outline (pointer-stable).
typedef struct {
  /// The layout of a slot value.
  ///
  /// Usually, this will be the same as for the object type, *or* the layout
  /// of a pointer (for outline storage).
  size_t size, align;

  /// Initializes a new slot at the given location.
  ///
  /// This function does not initialize the value *in* the slot; it simply sets
  /// up the slot so that a value can be `memcpy`'d or otherwise emplaced into
  /// the slot.
  void (*init)(void* slot);

  /// Destroys a slot, including the destruction of the value it contains.
  ///
  /// This function may, as an optimization, be null. This will cause it to
  /// behave as a no-op.
  void (*del)(void* slot);

  /// Transfers a slot.
  ///
  /// `dst` must be uninitialized; `src` must be initialized. After this
  /// function, their roles will be switched: `dst` will be initialized and
  /// contain the value from `src`; `src` will be initialized.
  ///
  /// This function need not actually copy the underlying value.
  void (*transfer)(void* dst, void* src);

  /// Extracts a pointer to the value inside the a slot.
  ///
  /// This function does not need to tolerate nulls.
  void* (*get)(void* slot);
} CWISS_SlotPolicy;

/// A hash table policy.
///
/// See the header documentation for more information.
typedef struct {
  const CWISS_ObjectPolicy* obj;
  const CWISS_KeyPolicy* key;
  const CWISS_AllocPolicy* alloc;
  const CWISS_SlotPolicy* slot;
} CWISS_Policy;

/// Declares a hash set policy with inline storage for the given type.
///
/// See the header documentation for more information.
#define CWISS_DECLARE_FLAT_SET_POLICY(kPolicy_, Type_, ...) \
  CWISS_DECLARE_POLICY_(kPolicy_, Type_, Type_, __VA_ARGS__)

/// Declares a hash map policy with inline storage for the given key and value
/// types.
///
/// See the header documentation for more information.
#define CWISS_DECLARE_FLAT_MAP_POLICY(kPolicy_, K_, V_, ...) \
  typedef struct {                                           \
    K_ k;                                                    \
    V_ v;                                                    \
  } kPolicy_##_Entry;                                        \
  CWISS_DECLARE_POLICY_(kPolicy_, kPolicy_##_Entry, K_, __VA_ARGS__)

/// Declares a hash set policy with pointer-stable storage for the given type.
///
/// See the header documentation for more information.
#define CWISS_DECLARE_NODE_SET_POLICY(kPolicy_, Type_, ...)          \
  CWISS_DECLARE_NODE_FUNCTIONS_(kPolicy_, Type_, Type_, __VA_ARGS__) \
  CWISS_DECLARE_POLICY_(kPolicy_, Type_, Type_, __VA_ARGS__,         \
                        CWISS_NODE_OVERRIDES_(kPolicy_))

/// Declares a hash map policy with pointer-stable storage for the given key and
/// value types.
///
/// See the header documentation for more information.
#define CWISS_DECLARE_NODE_MAP_POLICY(kPolicy_, K_, V_, ...)                 \
  typedef struct {                                                           \
    K_ k;                                                                    \
    V_ v;                                                                    \
  } kPolicy_##_Entry;                                                        \
  CWISS_DECLARE_NODE_FUNCTIONS_(kPolicy_, kPolicy_##_Entry, K_, __VA_ARGS__) \
  CWISS_DECLARE_POLICY_(kPolicy_, kPolicy_##_Entry, K_, __VA_ARGS__,         \
                        CWISS_NODE_OVERRIDES_(kPolicy_))

// ---- PUBLIC API ENDS HERE! ----

#define CWISS_DECLARE_POLICY_(kPolicy_, Type_, Key_, ...)                \
  CWISS_BEGIN                                                            \
  CWISS_EXTRACT_RAW(modifiers, static, __VA_ARGS__)                      \
  inline void kPolicy_##_DefaultCopy(void* dst, const void* src) {       \
    memcpy(dst, src, sizeof(Type_));                                     \
  }                                                                      \
  CWISS_EXTRACT_RAW(modifiers, static, __VA_ARGS__)                      \
  inline size_t kPolicy_##_DefaultHash(const void* val) {                \
    CWISS_AbslHash_State state = CWISS_AbslHash_kInit;                   \
    CWISS_AbslHash_Write(&state, val, sizeof(Key_));                     \
    return CWISS_AbslHash_Finish(state);                                 \
  }                                                                      \
  CWISS_EXTRACT_RAW(modifiers, static, __VA_ARGS__)                      \
  inline bool kPolicy_##_DefaultEq(const void* a, const void* b) {       \
    return memcmp(a, b, sizeof(Key_)) == 0;                              \
  }                                                                      \
  CWISS_EXTRACT_RAW(modifiers, static, __VA_ARGS__)                      \
  inline void kPolicy_##_DefaultSlotInit(void* slot) {}                  \
  CWISS_EXTRACT_RAW(modifiers, static, __VA_ARGS__)                      \
  inline void kPolicy_##_DefaultSlotTransfer(void* dst, void* src) {     \
    memcpy(dst, src, sizeof(Type_));                                     \
  }                                                                      \
  CWISS_EXTRACT_RAW(modifiers, static, __VA_ARGS__)                      \
  inline void* kPolicy_##_DefaultSlotGet(void* slot) { return slot; }    \
  CWISS_EXTRACT_RAW(modifiers, static, __VA_ARGS__)                      \
  inline void kPolicy_##_DefaultSlotDtor(void* slot) {                   \
    if (CWISS_EXTRACT(obj_dtor, NULL, __VA_ARGS__) != NULL) {            \
      CWISS_EXTRACT(obj_dtor, (void (*)(void*))NULL, __VA_ARGS__)(slot); \
    }                                                                    \
  }                                                                      \
                                                                         \
  CWISS_EXTRACT_RAW(modifiers, static, __VA_ARGS__)                      \
  const CWISS_ObjectPolicy kPolicy_##_ObjectPolicy = {                   \
      sizeof(Type_),                                                     \
      alignof(Type_),                                                    \
      CWISS_EXTRACT(obj_copy, kPolicy_##_DefaultCopy, __VA_ARGS__),      \
      CWISS_EXTRACT(obj_dtor, NULL, __VA_ARGS__),                        \
  };                                                                     \
  CWISS_EXTRACT_RAW(modifiers, static, __VA_ARGS__)                      \
  const CWISS_KeyPolicy kPolicy_##_KeyPolicy = {                         \
      CWISS_EXTRACT(key_hash, kPolicy_##_DefaultHash, __VA_ARGS__),      \
      CWISS_EXTRACT(key_eq, kPolicy_##_DefaultEq, __VA_ARGS__),          \
  };                                                                     \
  CWISS_EXTRACT_RAW(modifiers, static, __VA_ARGS__)                      \
  const CWISS_AllocPolicy kPolicy_##_AllocPolicy = {                     \
      CWISS_EXTRACT(alloc_alloc, CWISS_DefaultMalloc, __VA_ARGS__),      \
      CWISS_EXTRACT(alloc_free, CWISS_DefaultFree, __VA_ARGS__),         \
  };                                                                     \
  CWISS_EXTRACT_RAW(modifiers, static, __VA_ARGS__)                      \
  const CWISS_SlotPolicy kPolicy_##_SlotPolicy = {                       \
      CWISS_EXTRACT(slot_size, sizeof(Type_), __VA_ARGS__),              \
      CWISS_EXTRACT(slot_align, sizeof(Type_), __VA_ARGS__),             \
      CWISS_EXTRACT(slot_init, kPolicy_##_DefaultSlotInit, __VA_ARGS__), \
      CWISS_EXTRACT(slot_dtor, kPolicy_##_DefaultSlotDtor, __VA_ARGS__), \
      CWISS_EXTRACT(slot_transfer, kPolicy_##_DefaultSlotTransfer,       \
                    __VA_ARGS__),                                        \
      CWISS_EXTRACT(slot_get, kPolicy_##_DefaultSlotGet, __VA_ARGS__),   \
  };                                                                     \
  CWISS_END                                                              \
  CWISS_EXTRACT_RAW(modifiers, static, __VA_ARGS__)                      \
  const CWISS_Policy kPolicy_ = {                                        \
      &kPolicy_##_ObjectPolicy,                                          \
      &kPolicy_##_KeyPolicy,                                             \
      &kPolicy_##_AllocPolicy,                                           \
      &kPolicy_##_SlotPolicy,                                            \
  }

#define CWISS_DECLARE_NODE_FUNCTIONS_(kPolicy_, Type_, ...)                    \
  CWISS_BEGIN                                                                  \
  static inline void kPolicy_##_NodeSlotInit(void* slot) {                     \
    void* node = CWISS_EXTRACT(alloc_alloc, CWISS_DefaultMalloc, __VA_ARGS__)( \
        sizeof(Type_), alignof(Type_));                                        \
    memcpy(slot, &node, sizeof(node));                                         \
  }                                                                            \
  static inline void kPolicy_##_NodeSlotDtor(void* slot) {                     \
    if (CWISS_EXTRACT(obj_dtor, NULL, __VA_ARGS__) != NULL) {                  \
      CWISS_EXTRACT(obj_dtor, (void (*)(void*))NULL, __VA_ARGS__)              \
      (*(void**)slot);                                                         \
    }                                                                          \
    CWISS_EXTRACT(alloc_free, CWISS_DefaultFree, __VA_ARGS__)                  \
    (*(void**)slot, sizeof(Type_), alignof(Type_));                            \
  }                                                                            \
  static inline void kPolicy_##_NodeSlotTransfer(void* dst, void* src) {       \
    memcpy(dst, src, sizeof(void*));                                           \
  }                                                                            \
  static inline void* kPolicy_##_NodeSlotGet(void* slot) {                     \
    return *((void**)slot);                                                    \
  }                                                                            \
  CWISS_END

#define CWISS_NODE_OVERRIDES_(kPolicy_)                     \
  (slot_size, sizeof(void*)), (slot_align, alignof(void*)), \
      (slot_init, kPolicy_##_NodeSlotInit),                 \
      (slot_dtor, kPolicy_##_NodeSlotDtor),                 \
      (slot_transfer, kPolicy_##_NodeSlotTransfer),         \
      (slot_get, kPolicy_##_NodeSlotGet)

static inline void* CWISS_DefaultMalloc(size_t size, size_t align) {
  void* p = malloc(size);  // TODO: Check alignment.
  CWISS_CHECK(p != NULL, "malloc() returned null");
  return p;
}
static inline void CWISS_DefaultFree(void* array, size_t size, size_t align) {
  free(array);
}

CWISS_END_EXTERN
CWISS_END
/// policy.h ///////////////////////////////////////////////////////////////////

/// set_api.h //////////////////////////////////////////////////////////////////
/// Example API expansion of declare.h set macros.
///
/// Should be kept in sync with declare.h; unfortunately we don't have an easy
/// way to test this just yet.

// CWISS_DECLARE_FLAT_HASHSET(MySet, T) expands to:

/// Returns the policy used with this set type.
static inline const CWISS_Policy* MySet_policy();

/// The generated type.
typedef struct {
  /* ... */
} MySet;

/// Constructs a new set with the given initial capacity.
static inline MySet MySet_new(size_t capacity);

/// Creates a deep copy of this set.
static inline MySet MySet_dup(const MySet* self);

/// Destroys this set.
static inline void MySet_destroy(const MySet* self);

/// Dumps the internal contents of the table to stderr; intended only for
/// debugging.
///
/// The output of this function is not stable.
static inline void MySet_dump(const MySet* self);

/// Ensures that there is at least `n` spare capacity, potentially resizing
/// if necessary.
static inline void MySet_reserve(MySet* self, size_t n);

/// Resizes the table to have at least `n` buckets of capacity.
static inline void MySet_rehash(MySet* self, size_t n);

/// Returns whether the set is empty.
static inline size_t MySet_empty(const MySet* self);

/// Returns the number of elements stored in the table.
static inline size_t MySet_size(const MySet* self);

/// Returns the number of buckets in the table.
///
/// Note that this is *different* from the amount of elements that must be
/// in the table before a resize is triggered.
static inline size_t MySet_capacity(const MySet* self);

/// Erases every element in the set.
static inline void MySet_clear(MySet* self);

/// A non-mutating iterator into a `MySet`.
typedef struct {
  /* ... */
} MySet_CIter;

/// Creates a new non-mutating iterator fro this table.
static inline MySet_CIter MySet_citer(const MySet* self);

/// Returns a pointer to the element this iterator is at; returns `NULL` if
/// this iterator has reached the end of the table.
static inline const T* MySet_CIter_get(const MySet_CIter* it);

/// Advances this iterator, returning a pointer to the element the iterator
/// winds up pointing to (see `MySet_CIter_get()`).
///
/// The iterator must not point to the end of the table.
static inline const T* MySet_CIter_next(const MySet_CIter* it);

/// A mutating iterator into a `MySet`.
typedef struct {
  /* ... */
} MySet_Iter;

/// Creates a new mutating iterator fro this table.
static inline MySet_Iter MySet_iter(const MySet* self);

/// Returns a pointer to the element this iterator is at; returns `NULL` if
/// this iterator has reached the end of the table.
static inline T* MySet_Iter_get(const MySet_Iter* it);

/// Advances this iterator, returning a pointer to the element the iterator
/// winds up pointing to (see `MySet_Iter_get()`).
///
/// The iterator must not point to the end of the table.
static inline T* MySet_Iter_next(const MySet_Iter* it);

/// Checks if this set contains the given element.
///
/// In general, if you plan to use the element and not just check for it,
/// prefer `MySet_find()` and friends.
static inline bool MySet_contains(const MySet* self, const T* key);

/// Searches the table for `key`, non-mutating iterator version.
///
/// If found, returns an iterator at the found element; otherwise, returns
/// an iterator that's already at the end: `get()` will return `NULL`.
static inline MySet_CIter MySet_cfind(const MySet* self, const T* key);

/// Searches the table for `key`, mutating iterator version.
///
/// If found, returns an iterator at the found element; otherwise, returns
/// an iterator that's already at the end: `get()` will return `NULL`.
///
/// This function does not trigger rehashes.
static inline MySet_Iter MySet_find(MySet* self, const T* key);

/// Like `MySet_cfind`, but takes a pre-computed hash.
///
/// The hash must be correct for `key`.
static inline MySet_CIter MySet_cfind_hinted(const MySet* self, const T* key,
                                             size_t hash);

/// Like `MySet_find`, but takes a pre-computed hash.
///
/// The hash must be correct for `key`.
///
/// This function does not trigger rehashes.
static inline MySet_Iter MySet_find_hinted(MySet* self, const T* key,
                                           size_t hash);

/// The return type of `MySet_insert()`.
typedef struct {
  MySet_Iter iter;
  bool inserted;
} MySet_Insert;

/// Inserts `val` into the map if it isn't already present, initializing it by
/// copy.
///
/// Returns an iterator pointing to the element in the map and whether it was
/// just inserted or was already present.
static inline MySet_Insert MySet_insert(MySet* self, const T* val);

/// "Inserts" `key` into the table if it isn't already present.
///
/// This function does not perform insertion; it behaves exactly like
/// `MyMap_insert()` up until it would copy-initialize the new
/// element, instead returning a valid iterator pointing to uninitialized data.
///
/// This allows, for example, lazily constructing the parts of the element that
/// do not figure into the hash or equality. The initialized element must have
/// the same hash value and must compare equal to the value used for the initial
/// lookup; UB may otherwise result.
///
/// If this function returns `true` in `inserted`, the caller has *no choice*
/// but to insert, i.e., they may not change their minds at that point.
static inline MyMap_Insert MyMap_deferred_insert(MySet* self, const T* key);

/// Looks up `key` and erases it from the set.
///
/// Returns `true` if erasure happened.
static inline bool MySet_erase(MySet* self, const T* key);

/// Erases (and destroys) the element pointed to by `it`.
///
/// Although the iterator doesn't point to anything now, this function does
/// not trigger rehashes and the erased iterator can still be safely
/// advanced (although not dereferenced until advanced).
static inline void MySet_erase_at(MySet_Iter it);

// CWISS_DECLARE_LOOKUP(MySet, View) expands to:

/// Returns the policy used with this lookup extension.
static inline const CWISS_KeyPolicy* MySet_View_policy(void);

/// Checks if this set contains the given element.
///
/// In general, if you plan to use the element and not just check for it,
/// prefer `MySet_find()` and friends.
static inline bool MySet_contains_by_View(const MySet* self, const View* key);

/// Searches the table for `key`, non-mutating iterator version.
///
/// If found, returns an iterator at the found element; otherwise, returns
/// an iterator that's already at the end: `get()` will return `NULL`.
static inline MySet_CIter MySet_cfind_by_View(const MySet* self,
                                              const View* key);

/// Searches the table for `key`, mutating iterator version.
///
/// If found, returns an iterator at the found element; otherwise, returns
/// an iterator that's already at the end: `get()` will return `NULL`.
///
/// This function does not trigger rehashes.
static inline MySet_Iter MySet_find_by_View(MySet* self, const View* key);

/// Like `MySet_cfind`, but takes a pre-computed hash.
///
/// The hash must be correct for `key`.
static inline MySet_CIter MySet_cfind_hinted_by_View(const MySet* self,
                                                     const View* key,
                                                     size_t hash);

/// "Inserts" `key` into the table if it isn't already present.
///
/// This function does not perform insertion; it behaves exactly like
/// `MyMap_insert()` up until it would copy-initialize the new
/// element, instead returning a valid iterator pointing to uninitialized data.
///
/// This allows, for example, lazily constructing the parts of the element that
/// do not figure into the hash or equality. The initialized element must have
/// the same hash value and must compare equal to the value used for the initial
/// lookup; UB may otherwise result.
///
/// If this function returns `true` in `inserted`, the caller has *no choice*
/// but to insert, i.e., they may not change their minds at that point.
static inline MyMap_Insert MyMap_deferred_insert_by_View(MySet* self,
                                                         const View* key);

/// Like `MySet_find`, but takes a pre-computed hash.
///
/// The hash must be correct for `key`.
///
/// This function does not trigger rehashes.
static inline MySet_Iter MySet_find_hinted_by_View(MySet* self, const View* key,
                                                   size_t hash);

/// "Inserts" `key` into the set if it isn't already present.
///
/// This function does not perform insertion; it behaves exactly like
/// `MySet_insert()` up until it would copy-initialize the new
/// element, instead returning a valid iterator pointing to uninitialized data.
///
/// This allows, for example, lazily constructing the parts of the element that
/// do not figure into the hash or equality. The initialized element must have
/// the same hash value and must compare equal to the value used for the initial
/// lookup; UB may otherwise result.
///
/// If this function returns `true` in `inserted`, the caller has *no choice*
/// but to insert, i.e., they may not change their minds at that point.
static inline MySet_Insert MySet_deferred_insert_by_View(MySet* self,
                                                         const View* key);

/// Looks up `key` and erases it from the map.
///
/// Returns `true` if erasure happened.
static inline bool MySet_erase_by_View(MySet* self, const View* key);

#error "This file is for demonstration purposes only."
/// set_api.h //////////////////////////////////////////////////////////////////

#endif  // CWISSTABLE_H_
