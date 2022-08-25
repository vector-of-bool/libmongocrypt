#ifndef MLIB_DEFER_H_INCLUDED
#define MLIB_DEFER_H_INCLUDED

/**
 * @file defer.h
 * @brief A general-purpose lexically scoped "undo" mechanism for C code
 * @date 2022-08-22
 *
 * This file provides a "defer"-like mechanism as a set of function-like macros.
 *
 * *======================
 * *=========== How to use
 *
 * Within a function, use mlib_defer_begin() near the top of the function,
 * before placing and defer control flow.
 *
 * Near the end of the function, place an mlib_defer_end(). This must appear
 * at the same lexical scope as the corresponding begin() call. NOTE: There may
 * be only one begin()/end() pair within a function. It is recommended to wrap
 * the entire function body.
 *
 * At any point between begin()/end(), use 'mlib_defer(X)` to declare a
 * deferred statement "X". "X" may be a single expression, or a compound
 * statement between braces. "X" may refer to any variables within scope at the
 * point of use. The expression "X" will not be evaluated (i.e. "deferred")
 * until unwinding time. "X" MUST NOT use 'goto' or 'return' to transfer
 * control outside of X itself. "X" MAY use "break" to "early exit" its own
 * evaluation.
 *
 * Use 'mlib_defer_runall()' to execute all preceding deferred statements in the
 * reverse order that they were declared.
 *
 * NOTE: If control reaches mlib_defer_end() and there are any outstanding
 * deferred statements, this is assumed to be a bug, and the program will
 * terminate with an error message.
 *
 *
 * *===============================
 * *============ Convenience macros
 *
 *
 * * mlib_defer_return()
 *
 * Since you are likely going to 'return' after `mlib_defer_runall()`, you can
 * use `mlib_defer_return(...)` as a shorthand. If given no arguments, it is
 * equivalent to:
 *
 *    mlib_defer_runall();
 *    return __VA_ARGS__;
 *
 * That is: The return value expression is evaluated *first*, and then unwinding
 * occurs. (Note that this requires compiler support for decltype/__typeof__).
 *
 *
 * * mlib_defer_end_return(...)
 *
 * Equivalent to:
 *
 *    mlib_defer_return(...);
 *    mlib_defer_end();
 *
 *
 * * mlib_defer_check(...)
 *
 * If the given argument evaluates to a false-like value, equivalent to
 * mlib_defer_return(false)
 */

#include "./user-check.h"
#include "./macros.h"

#include <stdio.h>  // for fprintf()
#include <stdlib.h> // for abort()

#if !defined(__clang__) && defined(__GNUC__) && __GNUC__ <= 4
// Old GCC has trouble with the inlie _Pragma to disable maybe-uninitialized. If
// we're using defer(), we'll almost certainly hit those warnings, even though
// they are false-positivies. We test on other compilers that have better
// diagnostic control and will catch maybe-uninitialized more correctly, so
// we'll just disable it completely for this GCC version.
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
#endif

/**
 * @brief Each mlib_defer creates an instance of this object with a generated
 * name.
 *
 * The mlib_defer() hides the deferred code within an "if (0)" block, and
 * inserts a 'case' label with a generated number that will jump into that
 * block. The number of that can label is stored within this object.
 *
 * The object also has a pointer to the previous deferred item, so that we can
 * later "unwind" the stack of deferred objects.
 */
struct mlib_deferred_item {
   // The number of the generated 'case' label for the deferred code
   int label;
   // The previous deferred item in the current deferral block, or NULL if this
   // is the first one.
   struct mlib_deferred_item const *prev_item;
};

/**
 * @brief Represents a stack block of deferred items.
 *
 * Points to the top-most deferred item. The mlib_defer() macro will generate a
 * new item D and update the 'top_item' to point to D.
 */
struct mlib_defer_block_scope {
   // The previous block in the stack block, or NULL if this is the first
   struct mlib_defer_block_scope *next_block;
   // The most recently created deferred item created by mlib_defer(), or NULL
   // if there are none.
   struct mlib_deferred_item const *top_item;
};

/**
 * @brief The context used to control execution of deferred code. Only one may
 * exist in a function.
 */
struct mlib_defer_context {
   // The jump target to the deferred code to execute, the jump target to resume
   // normal execution, or zero to just enter the normal code block
   int jump;
   int labels[256];
   int *label_ptr;
};

static inline void *
_mlib_defer_clobber_item (void *p)
{
   return p;
}

static void *_mlib_defer_clobber_ptr = NULL;

/**
 * @brief Begin a new function deferral section.
 *
 * Only one of these may appear per function.
 *
 * There must be a single corresponding mlib_defer_end() or
 * mlib_defer_end_return().
 */
#define mlib_defer_begin(...) _mlibDeferBegin (__VA_ARGS__)
#define _mlibDeferBegin(...)                                     \
   MLIB_IF_ELSE (MLIB_IS_EMPTY (__VA_ARGS__),                    \
                 _mlibDeferBeginReturnsVoid _mlib_nothing () (), \
                 _mlibDeferBeginReturnsValue _mlib_nothing () (__VA_ARGS__))

#define _mlibDeferBeginPreamble()                          \
   /* init a new deferral context. There should be at most \
one of these per function */                               \
   struct mlib_defer_context _mlibDeferContext = {0};      \
   _mlibDeferContext.label_ptr = _mlibDeferContext.labels; \
   *_mlibDeferContext.label_ptr++ = -1;                    \
                                                           \
   goto _mlibDeferBegin;                                   \
   _mlibDeferReenter:


#define _mlibDeferBeginReturnsVoid()                     \
   _mlibDeferBeginPreamble ();                           \
   /* Jump! */                                           \
   switch (_mlibDeferContext.jump) {                     \
   default: /* Should never be reached */                \
      abort ();                                          \
   case -1:                                              \
      return;                                            \
   case 0: /* The initial label, just enters the code */ \
   _mlibDeferBegin:                                      \
      ((void) 0)

#define _mlibDeferBeginReturnsValue(T)                   \
   T _deferFunctionReturnValue;                          \
   _mlib_defer_clobber_ptr = &_deferFunctionReturnValue; \
   _mlibDeferBeginPreamble ();                           \
   switch (_mlibDeferContext.jump) {                     \
   default:                                              \
      abort ();                                          \
   case -1: {                                            \
      return _deferFunctionReturnValue;                  \
   }                                                     \
   case 0:                                               \
   _mlibDeferBegin:                                      \
      ((void) 0)


/**
 * @brief End an deferral section that was opened by mlib_defer_begin()
 *
 * If control reaches this point, it will assert that all defer scopes have
 * been unwound.
 */
#define mlib_defer_end() _mlibDeferEnd ()
#define _mlibDeferEnd()                                                      \
   if (_mlibDeferContext.label_ptr != _mlibDeferContext.labels) {            \
      fprintf (                                                              \
         stderr,                                                             \
         "%s:%d: Reached mlib_defer_end() without an mlib_defer_return()\n", \
         __FILE__,                                                           \
         __LINE__);                                                          \
      abort ();                                                              \
   }                                                                         \
   }                                                                         \
   ((void) 0)


/**
 * @brief Like mlib_defer_end(), but with a return value.
 *
 * NOTE: The return-value expression is evaluated AFTER unwinding
 */
#define mlib_defer_end_return(...)  \
   mlib_defer_return (__VA_ARGS__); \
   mlib_defer_end ();

/**
 * @brief Declare an deferred action on the current deferral scope.
 *
 * @param X A compound statement that will be evaluated during unwinding.
 *
 * The deferred statement can be arbitrarily complex, but MUST NOT use
 * 'return'. To early-terminate in a deferred compound statemtn, use 'break'
 * instead.
 */
#define mlib_defer(...) _mlibDefer ((__VA_ARGS__))
#define _mlibDefer(Expr)                                                 \
   _mlibDefer_1 (                                                        \
      -((__LINE__ * 100) + __COUNTER__),                                 \
      MLIB_PASTE4 (_mlibDeferredItem, __COUNTER__, _on_line_, __LINE__), \
      Expr)
#define _mlibDefer_1(Label, Name, Expr)                        \
   /* "push" an defer item into the current scope */           \
   *_mlibDeferContext.label_ptr++ = Label;                     \
   /* Create a local "subroutine" that evaluates "Expr"  */    \
   if (0) {                                                    \
   case Label:                                                 \
      do {                                                     \
         MLIB_JUST Expr;                                       \
      } while (0);                                             \
      _mlibDeferContext.jump = *--_mlibDeferContext.label_ptr; \
      goto _mlibDeferReenter;                                  \
   } else                                                      \
      ((void) 0)

/**
 * @brief Perform an mlib_defer_runall() and return the given expression.
 *
 * This will evaluate the given expression (if provided), then run
 * mlib_defer_runall(), and then return.
 *
 * @note The return-expression is evaluated AFTER mlib_defer_runall() is
 * executed.
 */
#define mlib_defer_return(...) _mlibDeferReturn (__VA_ARGS__)
#define _mlibDeferReturn(...)                              \
   MLIB_IF_ELSE (MLIB_IS_EMPTY (__VA_ARGS__),              \
                 _mlibDeferReturnVoid _mlib_nothing () (), \
                 _mlibDeferReturnValue _mlib_nothing () (__VA_ARGS__))
#define _mlibDeferReturnVoid() \
   if (1) {                    \
      _mlibDeferRunAll ();     \
   } else                      \
      ((void) 0)
#define _mlibDeferReturnValue(...)             \
   if (1) {                                    \
      _deferFunctionReturnValue = __VA_ARGS__; \
      _mlibDeferRunAll ();                     \
   } else                                      \
      ((void) 0)

#define _mlibDeferRunAll()                                     \
   if (1) {                                                    \
      _mlibDeferContext.jump = *--_mlibDeferContext.label_ptr; \
      goto _mlibDeferReenter;                                  \
   } else                                                      \
      ((void) 0)

/**
 * @brief If the given expression evaluates to a non-truthy value, perform an
 * mlib_defer_return(false) immediately.
 */
#define mlib_defer_check(...)    \
   if (!(__VA_ARGS__)) {         \
      mlib_defer_return (false); \
   } else                        \
      ((void) 0)

#endif // MLIB_DEFER_H_INCLUDED
