#ifndef MLIB_MACROS_H_INCLUDED
#define MLIB_MACROS_H_INCLUDED

// clang-format off
/// Evaluate to the 64th argument given
#define _mlib_64th(_0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, \
                   _11, _12, _13, _14, _15, _16, _17, _18, _19, _20, \
                   _21, _22, _23, _24, _25, _26, _27, _28, _29, _30, \
                   _31, _32, _33, _34, _35, _36, _37, _38, _39, _40, \
                   _41, _42, _43, _44, _45, _46, _47, _48, _49, _50, \
                   _51, _52, _53, _54, _55, _56, _57, _58, _59, _60, \
                   _61, _62, _63, ...) \
    _63

/// Accepts any arguments, and expands to nothing
#define _mlib_nothing(...)

/// Paste two tokens after macro expansion
#define MLIB_PASTE(A, ...) _mlib_paste1(A, __VA_ARGS__)
/// Paste three tokens after macro expansion
#define MLIB_PASTE3(A, B, ...) MLIB_PASTE(A, MLIB_PASTE(B, __VA_ARGS__))
/// Paste four tokens after macro expansion
#define MLIB_PASTE4(A, B, C, ...) MLIB_PASTE(MLIB_PASTE(A, B), MLIB_PASTE(C, __VA_ARGS__))
/// Paste five tokens after macro expansion
#define MLIB_PASTE5(A, B, C, D, ...) MLIB_PASTE(MLIB_PASTE(A, B), MLIB_PASTE(C, MLIB_PASTE(D, __VA_ARGS__)))
#define _mlib_paste1(A, ...) A##__VA_ARGS__

/**
 * @brief Expands to 1 if the given arguments contain any top-level commas, zero
 * otherwise.
 *
 * There is an expansion of __VA_ARGS__, followed by 62 '1' arguments, followed
 * by single '0'. If __VA_ARGS__ contains no commas, pick64th() will return the
 * single zero. If __VA_ARGS__ contains any top-level commas, the series of ones
 * will shift to the right and pick64th will return one of those ones. (This
 * only works __VA_ARGS__ contains fewer than 62 commas, which is a somewhat
 * reasonable limit.) The _mlib_nothing() is a workaround for MSVC's bad
 * preprocessor that expands __VA_ARGS__ incorrectly.
 *
 * If we had __VA_OPT__, this can be a lot simpler.
 */
#define _mlib_hasComma(...) \
    _mlib_64th \
    _mlib_nothing() (__VA_ARGS__, \
                     1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, \
                     1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, \
                     1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, \
                     1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, ~)

#define _mlib_commaIfRhsHasParens(...) ,

/**
 * @brief Expand to 1 if given no arguments, otherwise expand to zero
 */
#define MLIB_IS_EMPTY(...) \
    _mlib_isEmpty_1(\
        /* Expands to '1' if __VA_ARGS__ contains any top-level commas */ \
        _mlib_hasComma(__VA_ARGS__), \
        /* Expands to '1' if __VA_ARGS__ begins with a parenthesis, because \
         * that will cause an "invocation" of _mlib_commaIfRhsHasParens, \
         * which immediately expands to a single comma. */ \
        _mlib_hasComma(_mlib_commaIfRhsHasParens __VA_ARGS__), \
        /* Expands to '1' if __VA_ARGS__ expands to a function-like macro name \
         * that then expands to anything containing a top-level comma */ \
        _mlib_hasComma(__VA_ARGS__ ()), \
        /* Expands to '1' if __VA_ARGS__ expands to nothing. */ \
        _mlib_hasComma(_mlib_commaIfRhsHasParens __VA_ARGS__ ()))

#define _mlib_isEmpty_1(_1, _2, _3, _4) \
    _mlib_hasComma(MLIB_PASTE5(_mlib_isEmpty_CASE_, _1, _2, _3, _4))

#define _mlib_isEmpty_CASE_0001 ,

/**
 * @brief Expand to the first argument if `Cond` is 1, the second argument if
 * `Cond` is 0.
 *
 * Macro expansion is suppressed on the non-taken branch
 */
#define MLIB_IF_ELSE(Cond, IfTrue, IfFalse) \
    /* Suppress expansion of the two branches by using the '#' operator */ \
    _mlib_nothing(#IfTrue, #IfFalse)  \
    /* Concat the cond 1/0 with a prefix macro: */ \
    MLIB_PASTE(_mlib_ifElsePick_, Cond)(IfTrue, IfFalse)

#define _mlib_ifElsePick_1(IfTrue, IfFalse) \
   /* Expand the first operand, throw away the second */ \
   IfTrue _mlib_nothing(#IfFalse)
#define _mlib_ifElsePick_0(IfTrue, IfFalse) \
   /* Expand to the second operand, throw away the first */ \
   IfFalse _mlib_nothing(#IfTrue)

// clang-format on

#ifndef mlib_decltype
#if defined(_MSC_VER) || defined(__cplusplus)
/// A type expression that is the type of the given expression
#define mlib_decltype(...) decltype (__VA_ARGS__)
#else
/// A type expression that is the type of the given expression
#define mlib_decltype(...) __typeof__ (__VA_ARGS__)
#endif
#endif

#if defined(__GNUC__) || defined(__clang__)
#define MLIB_IF_GNU_LIKE(...) __VA_ARGS__
#else
#define MLIB_IF_GNU_LIKE(...)
#endif

/// Expands to the given arguments
#define MLIB_JUST(...) __VA_ARGS__

#endif // MLIB_MACROS_H_INCLUDED
