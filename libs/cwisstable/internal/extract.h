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

#ifndef CWISSTABLE_INTERNAL_EXTRACT_H_
#define CWISSTABLE_INTERNAL_EXTRACT_H_

/// Macro keyword-arguments machinery.
///
/// This file defines a number of macros used by policy.h to implement its
/// policy construction macros.
///
/// The way they work is more-or-less like this:
///
/// `CWISS_EXTRACT(foo, ...)` will find the first parenthesized pair that
/// matches exactly `(foo, whatever)`, where `foo` is part of a small set of
/// tokens defined in this file. To do so, this first expands into
///
/// ```
/// CWISS_EXTRACT1(CWISS_EXTRACT_foo, (k, v), ...)
/// ```
///
/// where `(k, v)` is the first pair in the macro arguments. This in turn
/// expands into
///
/// ```
/// CWISS_SELECT01(CWISS_EXTRACT_foo (k, v), CWISS_EXTRACT_VALUE, (k, v),
/// CWISS_EXTRACT2, (needle, __VA_ARGS__), CWISS_NOTHING)
/// ```
///
/// At this point, the preprocessor will expand `CWISS_EXTRACT_foo (k, v)` into
/// `CWISS_EXTRACT_foo_k`, which will be further expanded into `tok,tok,tok` if
/// `k` is the token `foo`, because we've defined `CWISS_EXTRACT_foo_foo` as a
/// macro.
///
/// `CWISS_SELECT01` will then delete the first three arguments, and the fourth
/// and fifth arguments will be juxtaposed.
///
/// In the case that `k` does not match, `CWISS_EXTRACT_foo (k, v), IDENT, (k,
/// v),` is deleted from the call, and the rest of the macro expands into
/// `CWISS_EXTRACT2(needle, __VA_ARGS__, _)` repeating the cycle but with a
/// different name.
///
/// In the case that `k` matches, the `tok,tok,tok` is deleted, and we get
/// `CWISS_EXTRACT_VALUE(k, v)`, which expands to `v`.

#define CWISS_EXTRACT(needle_, default_, ...) \
  (CWISS_EXTRACT_RAW(needle_, default_, __VA_ARGS__))

#define CWISS_EXTRACT_RAW(needle_, default_, ...) \
  CWISS_EXTRACT00(CWISS_EXTRACT_##needle_, __VA_ARGS__, (needle_, default_))

#define CWISS_EXTRACT_VALUE(key, val) val

// NOTE: Everything below this line is generated by cwisstable/extract.py!
// !!!

#define CWISS_EXTRACT_obj_copy(key_, val_) CWISS_EXTRACT_obj_copyZ##key_
#define CWISS_EXTRACT_obj_copyZobj_copy \
  CWISS_NOTHING, CWISS_NOTHING, CWISS_NOTHING
#define CWISS_EXTRACT_obj_dtor(key_, val_) CWISS_EXTRACT_obj_dtorZ##key_
#define CWISS_EXTRACT_obj_dtorZobj_dtor \
  CWISS_NOTHING, CWISS_NOTHING, CWISS_NOTHING
#define CWISS_EXTRACT_key_hash(key_, val_) CWISS_EXTRACT_key_hashZ##key_
#define CWISS_EXTRACT_key_hashZkey_hash \
  CWISS_NOTHING, CWISS_NOTHING, CWISS_NOTHING
#define CWISS_EXTRACT_key_eq(key_, val_) CWISS_EXTRACT_key_eqZ##key_
#define CWISS_EXTRACT_key_eqZkey_eq CWISS_NOTHING, CWISS_NOTHING, CWISS_NOTHING
#define CWISS_EXTRACT_alloc_alloc(key_, val_) CWISS_EXTRACT_alloc_allocZ##key_
#define CWISS_EXTRACT_alloc_allocZalloc_alloc \
  CWISS_NOTHING, CWISS_NOTHING, CWISS_NOTHING
#define CWISS_EXTRACT_alloc_free(key_, val_) CWISS_EXTRACT_alloc_freeZ##key_
#define CWISS_EXTRACT_alloc_freeZalloc_free \
  CWISS_NOTHING, CWISS_NOTHING, CWISS_NOTHING
#define CWISS_EXTRACT_slot_size(key_, val_) CWISS_EXTRACT_slot_sizeZ##key_
#define CWISS_EXTRACT_slot_sizeZslot_size \
  CWISS_NOTHING, CWISS_NOTHING, CWISS_NOTHING
#define CWISS_EXTRACT_slot_align(key_, val_) CWISS_EXTRACT_slot_alignZ##key_
#define CWISS_EXTRACT_slot_alignZslot_align \
  CWISS_NOTHING, CWISS_NOTHING, CWISS_NOTHING
#define CWISS_EXTRACT_slot_init(key_, val_) CWISS_EXTRACT_slot_initZ##key_
#define CWISS_EXTRACT_slot_initZslot_init \
  CWISS_NOTHING, CWISS_NOTHING, CWISS_NOTHING
#define CWISS_EXTRACT_slot_transfer(key_, val_) \
  CWISS_EXTRACT_slot_transferZ##key_
#define CWISS_EXTRACT_slot_transferZslot_transfer \
  CWISS_NOTHING, CWISS_NOTHING, CWISS_NOTHING
#define CWISS_EXTRACT_slot_get(key_, val_) CWISS_EXTRACT_slot_getZ##key_
#define CWISS_EXTRACT_slot_getZslot_get \
  CWISS_NOTHING, CWISS_NOTHING, CWISS_NOTHING
#define CWISS_EXTRACT_slot_dtor(key_, val_) CWISS_EXTRACT_slot_dtorZ##key_
#define CWISS_EXTRACT_slot_dtorZslot_dtor \
  CWISS_NOTHING, CWISS_NOTHING, CWISS_NOTHING
#define CWISS_EXTRACT_modifiers(key_, val_) CWISS_EXTRACT_modifiersZ##key_
#define CWISS_EXTRACT_modifiersZmodifiers \
  CWISS_NOTHING, CWISS_NOTHING, CWISS_NOTHING

#define CWISS_EXTRACT00(needle_, kv_, ...)                               \
  CWISS_SELECT00(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT01, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT01(needle_, kv_, ...)                               \
  CWISS_SELECT01(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT02, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT02(needle_, kv_, ...)                               \
  CWISS_SELECT02(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT03, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT03(needle_, kv_, ...)                               \
  CWISS_SELECT03(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT04, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT04(needle_, kv_, ...)                               \
  CWISS_SELECT04(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT05, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT05(needle_, kv_, ...)                               \
  CWISS_SELECT05(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT06, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT06(needle_, kv_, ...)                               \
  CWISS_SELECT06(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT07, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT07(needle_, kv_, ...)                               \
  CWISS_SELECT07(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT08, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT08(needle_, kv_, ...)                               \
  CWISS_SELECT08(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT09, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT09(needle_, kv_, ...)                               \
  CWISS_SELECT09(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT0A, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT0A(needle_, kv_, ...)                               \
  CWISS_SELECT0A(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT0B, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT0B(needle_, kv_, ...)                               \
  CWISS_SELECT0B(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT0C, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT0C(needle_, kv_, ...)                               \
  CWISS_SELECT0C(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT0D, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT0D(needle_, kv_, ...)                               \
  CWISS_SELECT0D(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT0E, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT0E(needle_, kv_, ...)                               \
  CWISS_SELECT0E(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT0F, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT0F(needle_, kv_, ...)                               \
  CWISS_SELECT0F(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT10, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT10(needle_, kv_, ...)                               \
  CWISS_SELECT10(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT11, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT11(needle_, kv_, ...)                               \
  CWISS_SELECT11(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT12, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT12(needle_, kv_, ...)                               \
  CWISS_SELECT12(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT13, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT13(needle_, kv_, ...)                               \
  CWISS_SELECT13(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT14, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT14(needle_, kv_, ...)                               \
  CWISS_SELECT14(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT15, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT15(needle_, kv_, ...)                               \
  CWISS_SELECT15(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT16, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT16(needle_, kv_, ...)                               \
  CWISS_SELECT16(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT17, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT17(needle_, kv_, ...)                               \
  CWISS_SELECT17(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT18, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT18(needle_, kv_, ...)                               \
  CWISS_SELECT18(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT19, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT19(needle_, kv_, ...)                               \
  CWISS_SELECT19(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT1A, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT1A(needle_, kv_, ...)                               \
  CWISS_SELECT1A(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT1B, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT1B(needle_, kv_, ...)                               \
  CWISS_SELECT1B(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT1C, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT1C(needle_, kv_, ...)                               \
  CWISS_SELECT1C(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT1D, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT1D(needle_, kv_, ...)                               \
  CWISS_SELECT1D(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT1E, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT1E(needle_, kv_, ...)                               \
  CWISS_SELECT1E(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT1F, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT1F(needle_, kv_, ...)                               \
  CWISS_SELECT1F(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT20, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT20(needle_, kv_, ...)                               \
  CWISS_SELECT20(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT21, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT21(needle_, kv_, ...)                               \
  CWISS_SELECT21(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT22, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT22(needle_, kv_, ...)                               \
  CWISS_SELECT22(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT23, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT23(needle_, kv_, ...)                               \
  CWISS_SELECT23(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT24, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT24(needle_, kv_, ...)                               \
  CWISS_SELECT24(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT25, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT25(needle_, kv_, ...)                               \
  CWISS_SELECT25(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT26, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT26(needle_, kv_, ...)                               \
  CWISS_SELECT26(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT27, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT27(needle_, kv_, ...)                               \
  CWISS_SELECT27(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT28, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT28(needle_, kv_, ...)                               \
  CWISS_SELECT28(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT29, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT29(needle_, kv_, ...)                               \
  CWISS_SELECT29(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT2A, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT2A(needle_, kv_, ...)                               \
  CWISS_SELECT2A(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT2B, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT2B(needle_, kv_, ...)                               \
  CWISS_SELECT2B(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT2C, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT2C(needle_, kv_, ...)                               \
  CWISS_SELECT2C(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT2D, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT2D(needle_, kv_, ...)                               \
  CWISS_SELECT2D(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT2E, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT2E(needle_, kv_, ...)                               \
  CWISS_SELECT2E(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT2F, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT2F(needle_, kv_, ...)                               \
  CWISS_SELECT2F(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT30, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT30(needle_, kv_, ...)                               \
  CWISS_SELECT30(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT31, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT31(needle_, kv_, ...)                               \
  CWISS_SELECT31(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT32, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT32(needle_, kv_, ...)                               \
  CWISS_SELECT32(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT33, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT33(needle_, kv_, ...)                               \
  CWISS_SELECT33(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT34, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT34(needle_, kv_, ...)                               \
  CWISS_SELECT34(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT35, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT35(needle_, kv_, ...)                               \
  CWISS_SELECT35(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT36, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT36(needle_, kv_, ...)                               \
  CWISS_SELECT36(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT37, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT37(needle_, kv_, ...)                               \
  CWISS_SELECT37(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT38, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT38(needle_, kv_, ...)                               \
  CWISS_SELECT38(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT39, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT39(needle_, kv_, ...)                               \
  CWISS_SELECT39(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT3A, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT3A(needle_, kv_, ...)                               \
  CWISS_SELECT3A(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT3B, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT3B(needle_, kv_, ...)                               \
  CWISS_SELECT3B(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT3C, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT3C(needle_, kv_, ...)                               \
  CWISS_SELECT3C(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT3D, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT3D(needle_, kv_, ...)                               \
  CWISS_SELECT3D(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT3E, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT3E(needle_, kv_, ...)                               \
  CWISS_SELECT3E(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT3F, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)
#define CWISS_EXTRACT3F(needle_, kv_, ...)                               \
  CWISS_SELECT3F(needle_ kv_, CWISS_EXTRACT_VALUE, kv_, CWISS_EXTRACT40, \
                 (needle_, __VA_ARGS__), CWISS_NOTHING)

#define CWISS_SELECT00(x_, ...) CWISS_SELECT00_(x_, __VA_ARGS__)
#define CWISS_SELECT01(x_, ...) CWISS_SELECT01_(x_, __VA_ARGS__)
#define CWISS_SELECT02(x_, ...) CWISS_SELECT02_(x_, __VA_ARGS__)
#define CWISS_SELECT03(x_, ...) CWISS_SELECT03_(x_, __VA_ARGS__)
#define CWISS_SELECT04(x_, ...) CWISS_SELECT04_(x_, __VA_ARGS__)
#define CWISS_SELECT05(x_, ...) CWISS_SELECT05_(x_, __VA_ARGS__)
#define CWISS_SELECT06(x_, ...) CWISS_SELECT06_(x_, __VA_ARGS__)
#define CWISS_SELECT07(x_, ...) CWISS_SELECT07_(x_, __VA_ARGS__)
#define CWISS_SELECT08(x_, ...) CWISS_SELECT08_(x_, __VA_ARGS__)
#define CWISS_SELECT09(x_, ...) CWISS_SELECT09_(x_, __VA_ARGS__)
#define CWISS_SELECT0A(x_, ...) CWISS_SELECT0A_(x_, __VA_ARGS__)
#define CWISS_SELECT0B(x_, ...) CWISS_SELECT0B_(x_, __VA_ARGS__)
#define CWISS_SELECT0C(x_, ...) CWISS_SELECT0C_(x_, __VA_ARGS__)
#define CWISS_SELECT0D(x_, ...) CWISS_SELECT0D_(x_, __VA_ARGS__)
#define CWISS_SELECT0E(x_, ...) CWISS_SELECT0E_(x_, __VA_ARGS__)
#define CWISS_SELECT0F(x_, ...) CWISS_SELECT0F_(x_, __VA_ARGS__)
#define CWISS_SELECT10(x_, ...) CWISS_SELECT10_(x_, __VA_ARGS__)
#define CWISS_SELECT11(x_, ...) CWISS_SELECT11_(x_, __VA_ARGS__)
#define CWISS_SELECT12(x_, ...) CWISS_SELECT12_(x_, __VA_ARGS__)
#define CWISS_SELECT13(x_, ...) CWISS_SELECT13_(x_, __VA_ARGS__)
#define CWISS_SELECT14(x_, ...) CWISS_SELECT14_(x_, __VA_ARGS__)
#define CWISS_SELECT15(x_, ...) CWISS_SELECT15_(x_, __VA_ARGS__)
#define CWISS_SELECT16(x_, ...) CWISS_SELECT16_(x_, __VA_ARGS__)
#define CWISS_SELECT17(x_, ...) CWISS_SELECT17_(x_, __VA_ARGS__)
#define CWISS_SELECT18(x_, ...) CWISS_SELECT18_(x_, __VA_ARGS__)
#define CWISS_SELECT19(x_, ...) CWISS_SELECT19_(x_, __VA_ARGS__)
#define CWISS_SELECT1A(x_, ...) CWISS_SELECT1A_(x_, __VA_ARGS__)
#define CWISS_SELECT1B(x_, ...) CWISS_SELECT1B_(x_, __VA_ARGS__)
#define CWISS_SELECT1C(x_, ...) CWISS_SELECT1C_(x_, __VA_ARGS__)
#define CWISS_SELECT1D(x_, ...) CWISS_SELECT1D_(x_, __VA_ARGS__)
#define CWISS_SELECT1E(x_, ...) CWISS_SELECT1E_(x_, __VA_ARGS__)
#define CWISS_SELECT1F(x_, ...) CWISS_SELECT1F_(x_, __VA_ARGS__)
#define CWISS_SELECT20(x_, ...) CWISS_SELECT20_(x_, __VA_ARGS__)
#define CWISS_SELECT21(x_, ...) CWISS_SELECT21_(x_, __VA_ARGS__)
#define CWISS_SELECT22(x_, ...) CWISS_SELECT22_(x_, __VA_ARGS__)
#define CWISS_SELECT23(x_, ...) CWISS_SELECT23_(x_, __VA_ARGS__)
#define CWISS_SELECT24(x_, ...) CWISS_SELECT24_(x_, __VA_ARGS__)
#define CWISS_SELECT25(x_, ...) CWISS_SELECT25_(x_, __VA_ARGS__)
#define CWISS_SELECT26(x_, ...) CWISS_SELECT26_(x_, __VA_ARGS__)
#define CWISS_SELECT27(x_, ...) CWISS_SELECT27_(x_, __VA_ARGS__)
#define CWISS_SELECT28(x_, ...) CWISS_SELECT28_(x_, __VA_ARGS__)
#define CWISS_SELECT29(x_, ...) CWISS_SELECT29_(x_, __VA_ARGS__)
#define CWISS_SELECT2A(x_, ...) CWISS_SELECT2A_(x_, __VA_ARGS__)
#define CWISS_SELECT2B(x_, ...) CWISS_SELECT2B_(x_, __VA_ARGS__)
#define CWISS_SELECT2C(x_, ...) CWISS_SELECT2C_(x_, __VA_ARGS__)
#define CWISS_SELECT2D(x_, ...) CWISS_SELECT2D_(x_, __VA_ARGS__)
#define CWISS_SELECT2E(x_, ...) CWISS_SELECT2E_(x_, __VA_ARGS__)
#define CWISS_SELECT2F(x_, ...) CWISS_SELECT2F_(x_, __VA_ARGS__)
#define CWISS_SELECT30(x_, ...) CWISS_SELECT30_(x_, __VA_ARGS__)
#define CWISS_SELECT31(x_, ...) CWISS_SELECT31_(x_, __VA_ARGS__)
#define CWISS_SELECT32(x_, ...) CWISS_SELECT32_(x_, __VA_ARGS__)
#define CWISS_SELECT33(x_, ...) CWISS_SELECT33_(x_, __VA_ARGS__)
#define CWISS_SELECT34(x_, ...) CWISS_SELECT34_(x_, __VA_ARGS__)
#define CWISS_SELECT35(x_, ...) CWISS_SELECT35_(x_, __VA_ARGS__)
#define CWISS_SELECT36(x_, ...) CWISS_SELECT36_(x_, __VA_ARGS__)
#define CWISS_SELECT37(x_, ...) CWISS_SELECT37_(x_, __VA_ARGS__)
#define CWISS_SELECT38(x_, ...) CWISS_SELECT38_(x_, __VA_ARGS__)
#define CWISS_SELECT39(x_, ...) CWISS_SELECT39_(x_, __VA_ARGS__)
#define CWISS_SELECT3A(x_, ...) CWISS_SELECT3A_(x_, __VA_ARGS__)
#define CWISS_SELECT3B(x_, ...) CWISS_SELECT3B_(x_, __VA_ARGS__)
#define CWISS_SELECT3C(x_, ...) CWISS_SELECT3C_(x_, __VA_ARGS__)
#define CWISS_SELECT3D(x_, ...) CWISS_SELECT3D_(x_, __VA_ARGS__)
#define CWISS_SELECT3E(x_, ...) CWISS_SELECT3E_(x_, __VA_ARGS__)
#define CWISS_SELECT3F(x_, ...) CWISS_SELECT3F_(x_, __VA_ARGS__)

#define CWISS_SELECT00_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT01_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT02_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT03_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT04_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT05_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT06_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT07_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT08_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT09_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT0A_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT0B_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT0C_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT0D_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT0E_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT0F_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT10_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT11_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT12_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT13_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT14_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT15_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT16_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT17_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT18_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT19_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT1A_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT1B_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT1C_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT1D_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT1E_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT1F_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT20_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT21_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT22_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT23_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT24_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT25_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT26_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT27_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT28_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT29_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT2A_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT2B_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT2C_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT2D_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT2E_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT2F_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT30_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT31_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT32_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT33_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT34_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT35_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT36_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT37_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT38_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT39_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT3A_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT3B_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT3C_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT3D_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT3E_(ignored_, _call_, _args_, call_, args_, ...) call_ args_
#define CWISS_SELECT3F_(ignored_, _call_, _args_, call_, args_, ...) call_ args_

#endif  // CWISSTABLE_INTERNAL_EXTRACT_H_
