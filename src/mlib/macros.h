#ifndef MLIB_MACROS_H_INCLUDED
#define MLIB_MACROS_H_INCLUDED

/// Accepts any arguments, and expands to nothing
#define _mlib_nothing(...)

/// Paste two tokens after macro expansion
#define MLIB_PASTE(A, ...) _mlib_paste1 (A, __VA_ARGS__)
/// Paste three tokens after macro expansion
#define MLIB_PASTE3(A, B, ...) MLIB_PASTE (A, MLIB_PASTE (B, __VA_ARGS__))
/// Paste four tokens after macro expansion
#define MLIB_PASTE4(A, B, C, ...) \
   MLIB_PASTE (MLIB_PASTE (A, B), MLIB_PASTE (C, __VA_ARGS__))
/// Paste five tokens after macro expansion
#define MLIB_PASTE5(A, B, C, D, ...) \
   MLIB_PASTE (MLIB_PASTE (A, B), MLIB_PASTE (C, MLIB_PASTE (D, __VA_ARGS__)))
#define _mlib_paste1(A, ...) A##__VA_ARGS__

#if defined(__GNUC__) && !defined(__clang__)
#define MLIB_IF_GCC(...) __VA_ARGS__
#else
#define MLIB_IF_GCC(...)
#endif

#ifdef __clang__
#define MLIB_IF_CLANG(...) __VA_ARGS__
#else
#define MLIB_IF_CLANG(...)
#endif

#ifdef _MSC_VER
#define MLIB_IF_MSVC(...) __VA_ARGS__
#else
#define MLIB_IF_MSVC(...)
#endif

#if defined(__GNUC__) || defined(__clang__)
#define MLIB_IF_GNU_LIKE(...) __VA_ARGS__
#else
#define MLIB_IF_GNU_LIKE(...)
#endif

/// Expands to the given arguments
#define MLIB_JUST(...) __VA_ARGS__

#endif // MLIB_MACROS_H_INCLUDED
