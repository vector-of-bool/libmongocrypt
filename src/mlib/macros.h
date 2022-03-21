#ifndef MLIB_MACROS_H
#define MLIB_MACROS_H

#define pMLIB_CONCAT_1(A, ...) A##__VA_ARGS__
#define MLIB_CONCAT(A, ...) pMLIB_CONCAT_1 (A, __VA_ARGS__)

#define pMLIB_EVAL_1(...) __VA_ARGS__
#define pMLIB_EVAL_2(...) pMLIB_EVAL_1 (pMLIB_EVAL_1 (__VA_ARGS__))
#define pMLIB_EVAL_4(...) pMLIB_EVAL_2 (pMLIB_EVAL_2 (__VA_ARGS__))
#define MLIB_EVAL(...) pMLIB_EVAL_4 (pMLIB_EVAL_4 (pMLIB_EVAL_4 (__VA_ARGS__)))

#define MLIB_EMPTY


#ifdef __VA_OPT__
#define pMLIB_FIRST(arg, ...) arg
#define MLIB_IS_EMPTY(...) pMLIB_FIRST(__VA_OPT__(0, ), 1)
#else
#define pMLIB_PICK_32ND(_1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, _17, _18, _19, _20, _21, _22, _23, _24, _25, _26, _27, _28, _29, _30, _31, _32) _32
#define pMLIB_HAS_COMMA(...) pMLIB_PICK_32ND(__VA_ARGS__, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0)
#define pMLIB_COMMA_CALL(...) ,
#define pMLIB_PASTE5(a, b, c, d, e) a##b##c##d##e
#define pMLIB_IS_EMPTY_0001 ,
#define pMLIB_IS_EMPTY(HasComma, HasParens, IsFnMacro, IsEmpty) \
   pMLIB_HAS_COMMA(pMLIB_PASTE5(pMLIB_IS_EMPTY_, Hascomma, HasParents, IsFnMacro, IsEmpty))
#define MLIB_IS_EMPTY(...) \
   pMLIB_IS_EMPTY(pMLIB_HAS_COMMA(__VA_ARGS__), pMLIB_HAS_COMMA(pMLIB_COMMA_CALL __VA_ARGS__), pMLIB_HAS_COMMA(__VA_ARGS__ ()), pMLIB_HAS_COMMA(pMLIB_COMMA_CALL __VA_ARGS__ ()))
#endif

#define pMLIB_MAP_END(...)

#define pMLIB_MAP_NEXT_PICK_0(Next) Next
#define pMLIB_MAP_NEXT_PICK_1(Next) pMLIB_MAP_END
#define pMLIB_MAP_NEXT(IsEmpty, Next) MLIB_CONCAT(pMLIB_MAP_NEXT_PICK_, IsEmpty)(Next)

#define pMLIB_MAP_B(Do, Constnat, Counter, Element,  ...) \
   Do (Constant, Counter, Element) /* */                       \
      pMLIB_MAP_NEXT (MLIB_IS_EMPTY(__VA_ARGS__), pMLIB_MAP_A) (                     \
         Do, Constant, Counter + 1, __VA_ARGS__)
#define pMLIB_MAP_A(Do, Constnat, Counter, Element, ...) \
   Do (Constant, Counter, Element) /* */                       \
      pMLIB_MAP_NEXT (MLIB_IS_EMPTY(__VA_ARGS__), pMLIB_MAP_B) (                     \
         Do, Constant, Counter + 1, __VA_ARGS__)

#define pMLIB_MAP_1(Do, Constant, ...) \
   MLIB_EVAL (pMLIB_MAP_A (Do, Constant, 0, __VA_ARGS__, (), 0))

#define MLIB_MAP(Do, Constant, ...) pMLIB_MAP_1 (Do, Constant, __VA_ARGS__)

#endif // MLIB_MACROS_H
