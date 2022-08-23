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
 *    return;
 *
 * If given any arguments, it is equivalent to:
 *
 *    decltype(__VA_ARGS__) __retval = __VA_ARGS__;
 *    mlib_defer_runall();
 *    return __retval;
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
 * * mlib_defer_push() / mlib_defer_pop()
 *
 * Push/pop a "block" on the defer stack.
 *
 * By default, there is a single block created with mlib_defer_begin(). Each
 * mlib_defer() is associated with the nearest preceding block.
 * mlib_defer_pop() will execute only the deferred statements for the top-most
 * block, and then remove that block from the stack.
 *
 * These are useful to create deferred statements that are executed within a
 * loop, or need to be unwound without fully existing the function:
 *
 *    mlib_defer_begin()
 *    while (some_condition) {
 *       mlib_defer_push();
 *
 *       / ... do stuff ... /
 *
 *       mlib_defer_pop();  // Clean up loop resources
 *    }
 *    mlib_defer_end_return();
 *
 * NOTE: mlib_defer_runall() is equivalent to calling mlib_defer_pop() for
 * every block in scope, in reverse order.
 *
 *
 * * mlib_defer_continue / mlib_defer_break
 *
 * Psuedo-keywords analogous to continue/break, but execute an
 * 'mlib_defer_pop()' before jumping.
 *
 *    mlib_defer_begin()
 *    while (some_condition) {
 *       mlib_defer_push();
 *
 *       / ... do stuff ... /
 *
 *       if (should_continue) {
 *          mlib_defer_continue;  // Clean up loop resources, then 'continue'
 *       }
 *
 *       if (should_break) {
 *          mlib_defer_break;     // Clean up look resources, then 'break'
 *       }
 *
 *       / ... do more stuff ... /
 *
 *       mlib_defer_pop();  // Clean up loop resources
 *    }
 *    mlib_defer_end_return();
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
   // The top-most deferred block. Updated by mlib_defer_push() and
   // mlib_defer_pop()
   struct mlib_defer_block_scope *top_block;
   // The jump target to the deferred code to execute, the jump target to resume
   // normal execution, or zero to just enter the normal code block
   int jump;
   // Tell the deferred code where to jump to after executing the deferred code.
   int resume_label;
};

/**
 * @brief Begin a new function deferral section.
 *
 * Only one of these may appear per function.
 *
 * There must be a single corresponding mlib_defer_end() or
 * mlib_defer_end_return().
 */
#define mlib_defer_begin() _mlibDeferBegin ()
#define _mlibDeferBegin()                                            \
   MLIB_IF_GNU_LIKE (_Pragma ("GCC diagnostic push");)               \
   MLIB_IF_GNU_LIKE (                                                \
      _Pragma ("GCC diagnostic ignored \"-Wmaybe-uninitialized\"");) \
   /* init a new deferral context. There should be at most           \
      one of these per function */                                   \
   struct mlib_defer_context _mlibDeferContext = {NULL, 0, 0};       \
   mlib_defer_push ();                                               \
                                                                     \
   _mlibDeferReenter:                                                \
   /* Jump! */                                                       \
   switch (_mlibDeferContext.jump) {                                 \
   default: /* Should never be reached */                            \
      abort ();                                                      \
   case 0: /* The initial label, just enters the code */             \
      ((void) 0)

/**
 * @brief End an deferral section that was opened by mlib_defer_begin()
 *
 * If control reaches this point, it will assert that all defer scopes have
 * been unwound.
 */
#define mlib_defer_end() _mlibDeferEnd ()
#define _mlibDeferEnd()                                                      \
   MLIB_IF_GNU_LIKE (_Pragma ("GCC diagnostic pop");)                        \
   if (_mlibDeferContext.top_block) {                                        \
      fprintf (                                                              \
         stderr,                                                             \
         "%s:%d: Reached mlib_defer_end() without an mlib_defer_runall()\n", \
         __FILE__,                                                           \
         __LINE__);                                                          \
      abort ();                                                              \
   }                                                                         \
   }                                                                         \
   ((void) 0)


/**
 * @brief Like mlib_defer_end(), but with a return value.
 *
 * NOTE: The return-value expression is evaluated BEFORE unwinding
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
   struct mlib_deferred_item const Name = {                    \
      Label,                                                   \
      _mlibDeferContext.top_block->top_item,                   \
   };                                                          \
   _mlibDeferContext.top_block->top_item = &Name;              \
   /* Create a local "subroutine" that evaluates "Expr"  */    \
   if (0) {                                                    \
   case Label:                                                 \
      do {                                                     \
         MLIB_JUST Expr;                                       \
      } while (0);                                             \
      _mlibDeferContext.jump = _mlibDeferContext.resume_label; \
      goto _mlibDeferReenter;                                  \
   } else                                                      \
      ((void) 0)

/**
 * @brief Unwind all deferral scopes in the current function.
 *
 * No further defer-related psuedo-statements may be invoked after this point,
 * except for mlib_defer_end().
 */
#define mlib_defer_runall() _mlibDeferRunAll ()
#define _mlibDeferRunAll()                  \
   if (1) {                                 \
      while (_mlibDeferContext.top_block) { \
         mlib_defer_pop ();                 \
      }                                     \
   } else                                   \
      ((void) 0)

/**
 * @brief Push an additional deferral scope onto the current function's defer
 * stack.
 *
 * Subsequent mlib_defer() statements will associate with this stack item
 * until it is popped via another defer psuedo-statement.
 */
#define mlib_defer_push() _mlibDeferPush ()
#define _mlibDeferPush() \
   _mlibDeferPush_1 (    \
      MLIB_PASTE4 (_mlibDeferBlock, __COUNTER__, _on_line_, __LINE__))
#define _mlibDeferPush_1(Name)                   \
   struct mlib_defer_block_scope Name = {        \
      .next_block = _mlibDeferContext.top_block, \
   };                                            \
   _mlibDeferContext.top_block = &Name

/**
 * @brief Pop the nearest deferral scope from the function's defer stack.
 *
 * This should correspond to a call to mlib_defer_push().
 *
 * All mlib_defer() actions between the push() and pop() will be
 * executed, but actions in parent scopes will remain unexecuted.
 *
 * @note The mlib_defer_break and mlib_defer_continue psuedo-statements
 * perform an mlib_defer_pop() automatically.
 */
#define mlib_defer_pop() _mlibDeferPop ()
#define _mlibDeferPop()                                                      \
   if (1) {                                                                  \
      while (_mlibDeferContext.top_block->top_item) {                        \
         _mlibDeferRunTopItem (-((__LINE__ * 100) + __COUNTER__));           \
      }                                                                      \
      _mlibDeferContext.top_block = _mlibDeferContext.top_block->next_block; \
   } else                                                                    \
      ((void) 0)

#define _mlibDeferRunTopItem(ResumeLabel)                                    \
   if (1) {                                                                  \
      /* Tell the defer context the case label of the hidden block that      \
       * contains the deferred code. */                                      \
      _mlibDeferContext.jump = _mlibDeferContext.top_block->top_item->label; \
      /* Tell the defer context where to come back to after it has finished  \
       * running the deferred code */                                        \
      _mlibDeferContext.resume_label = ResumeLabel;                          \
      goto _mlibDeferReenter;                                                \
      /* It will come back to this point: */                                 \
   case ResumeLabel:                                                         \
      /* Remove the deferred item that was executed: */                      \
      _mlibDeferContext.top_block->top_item =                                \
         _mlibDeferContext.top_block->top_item->prev_item;                   \
   } else                                                                    \
      ((void) 0)

/**
 * @brief Perform an mlib_defer_runall() and return the given expression.
 *
 * This will evaluate the given expression (if provided), then run
 * mlib_defer_runall(), and then return.
 *
 * @note The return-expression is evaluated BEFORE mlib_defer_runall() is
 * executed.
 */
#define mlib_defer_return(...) _mlibDeferReturn (__VA_ARGS__)
#define _mlibDeferReturn(...)                 \
   MLIB_IF_ELSE (MLIB_IS_EMPTY (__VA_ARGS__), \
                 _mlibDeferReturnVoid (),     \
                 _mlibDeferReturnVal (__VA_ARGS__))


#define _mlibDeferReturnVoid() \
   if (1) {                    \
      mlib_defer_runall ();    \
      return;                  \
   } else                      \
      ((void) 0)

#define _mlibDeferReturnVal(...)                                    \
   if (1) {                                                         \
      mlib_decltype (__VA_ARGS__) _mlibReturnValue = (__VA_ARGS__); \
      mlib_defer_runall ();                                         \
      return _mlibReturnValue;                                      \
   } else                                                           \
      ((void) 0)

/**
 * @brief Perform an mlib_defer_pop() followed by 'break' statement
 */
#define mlib_defer_break _mlibDeferBreak ()
#define _mlibDeferBreak() \
   if (1) {               \
      mlib_defer_pop ();  \
      break;              \
   } else                 \
      ((void) 0)

/**
 * @brief Perform an mlib_defer_pop() followed by a 'continue' statement
 */
#define mlib_defer_continue _mlibDeferContinue ()
#define _mlibDeferContinue() \
   if (1) {                  \
      mlib_defer_pop ();     \
      continue;              \
   } else                    \
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
