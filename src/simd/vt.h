#if defined(SPECTREPRO_SIMD_VT_H_) == defined(HWY_TARGET_TOGGLE)
#ifdef SPECTREPRO_SIMD_VT_H_
#undef SPECTREPRO_SIMD_VT_H_
#else
#define SPECTREPRO_SIMD_VT_H_
#endif

#include <hwy/highway.h>

HWY_BEFORE_NAMESPACE();
namespace spectrepro {
namespace HWY_NAMESPACE {

namespace hn = hwy::HWY_NAMESPACE;

}  // namespace HWY_NAMESPACE
}  // namespace spectrepro
HWY_AFTER_NAMESPACE();

#if HWY_ONCE

namespace spectrepro {

typedef void (*PrintFunc)(const char32_t* chars, size_t count);

}  // namespace spectrepro

#endif  // HWY_ONCE

#endif  // SPECTREPRO_SIMD_VT_H_
