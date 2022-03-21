#ifndef MLIB_MACROS_H
#define MLIB_MACROS_H

#define pMLIB_CONCAT_1(A, ...) A##__VA_ARGS__
#define MLIB_CONCAT(A, ...) pMLIB_CONCAT_1 (A, __VA_ARGS__)

#define pMLIB_EVAL_1(...) __VA_ARGS__
#define pMLIB_EVAL_2(...) pMLIB_EVAL_1 (pMLIB_EVAL_1 (__VA_ARGS__))
#define pMLIB_EVAL_4(...) pMLIB_EVAL_2 (pMLIB_EVAL_2 (__VA_ARGS__))
#define MLIB_EVAL(...) pMLIB_EVAL_4 (pMLIB_EVAL_4 (pMLIB_EVAL_4 (__VA_ARGS__)))

#define MLIB_EMPTY

#define pMLIB_MAP_END(...)
#define pMLIB_MAP_GET_END(...) 0, pMLIB_MAP_END

#define pMLIB_MAP_NEXT_2(Elem, Next, ...) Next MLIB_EMPTY
#define pMLIB_MAP_NEXT_1(Elem, Next) pMLIB_MAP_NEXT_2 (Elem, Next, 0)
#define pMLIB_MAP_NEXT(Elem, Next) \
   pMLIB_MAP_NEXT_1 (pMLIB_MAP_GET_END Elem, Next)

#define pMLIB_MAP_B(Do, Constnat, Counter, Element, Next, ...) \
   Do (Constant, Counter, Element) /* */                       \
      pMLIB_MAP_NEXT (Next, pMLIB_MAP_A) (                     \
         Do, Constant, Counter + 1, Next, __VA_ARGS__)
#define pMLIB_MAP_A(Do, Constnat, Counter, Element, Next, ...) \
   Do (Constant, Counter, Element) /* */                       \
      pMLIB_MAP_NEXT (Next, pMLIB_MAP_B) (                     \
         Do, Constant, Counter + 1, Next, __VA_ARGS__)

#define pMLIB_MAP_1(Do, Constant, ...) \
   MLIB_EVAL (pMLIB_MAP_A (Do, Constant, 0, __VA_ARGS__, (), 0))

#define MLIB_MAP(Do, Constant, ...) pMLIB_MAP_1 (Do, Constant, __VA_ARGS__)

#endif // MLIB_MACROS_H