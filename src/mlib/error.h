#ifndef MLIB_ERROR_PRIVATE_H
#define MLIB_ERROR_PRIVATE_H

#include "./user-check.h"

#include "./str.h"
#include "./thread.h"

#ifdef _WIN32
#include "./windows-lean.h"
#else
#include <errno.h>
#endif

/**
 * @brief Obtain a string containing an error message corresponding to an error
 * code from the host platform.
 *
 * @param errn An error code for the system. (e.g. GetLastError() on Windows)
 * @return mstr A new string containing the resulting error. Must be freed with
 * @ref mstr_free().
 */
static inline mstr
merror_system_error_string (int errn)
{
#ifdef _WIN32
   wchar_t *wbuffer = NULL;
   DWORD slen = FormatMessageW (FORMAT_MESSAGE_ALLOCATE_BUFFER |
                                   FORMAT_MESSAGE_FROM_SYSTEM |
                                   FORMAT_MESSAGE_IGNORE_INSERTS,
                                NULL,
                                (DWORD) errn,
                                0,
                                (LPWSTR) &wbuffer,
                                0,
                                NULL);
   if (slen == 0) {
      return mstr_copy_cstr (
         "[Error while getting error string from FormatMessageW()]");
   }
   mstr_narrow_result narrow = mstr_win32_narrow (wbuffer);
   LocalFree (wbuffer);
   assert (narrow.error == 0);
   // Messages from FormatMessage contain an additional CR+LF
   if (mstr_ends_with (narrow.string.view, mstrv_lit ("\r\n"))) {
      mstr_inplace_remove_suffix (&narrow.string, 2);
   }
   return narrow.string;
#else
   errno = 0;
   char *const str = strerror (errn);
   if (errno) {
      return mstr_copy_cstr (
         "[Error while getting error string from strerror()]");
   }
   return mstr_copy_cstr (str);
#endif
}

#include "./macros-push.h"
/// Expand to the type name of the error handing slot type for the given error
/// type
#define pMLIB_ERROR_SLOT_TYPE(TypeName) \
   MLIB_CONCAT (_mlib_e_slot_type_for_, TypeName)

/// @private Expand to the name of the global variable managing the given slot
#define pMLIB_ERROR_SLOT_NAME(TypeName) \
   MLIB_CONCAT (_mlib_e_slot_ptr_for_, TypeName)

static inline void *
_merror_e_slot_replace (void *tl_ptrptr, void *new_ptr)
{
   void **tl_ptr = tl_ptrptr;
   void *old_ptr = *tl_ptr;
   *tl_ptr = new_ptr;
   return old_ptr;
}

#define pMLIB_DECL_ERROR_SLOT_1(T, SlotType, SlotName, Destroy) \
   struct SlotType {                                            \
      T handled;                                                \
      struct SlotType *_previous;                               \
      bool got_error;                                           \
   };                                                           \
   static inline void MLIB_CONCAT (_mlib_e_destroy_for_, T) (   \
      struct SlotType * _mlib_e_slot_to_destroy_)               \
   {                                                            \
      if (_mlib_e_slot_to_destroy_->got_error) {                \
         T handled = _mlib_e_slot_to_destroy_->handled;         \
         (void) (Destroy);                                      \
         _mlib_e_slot_to_destroy_->handled = handled;           \
      }                                                         \
   }                                                            \
   extern MLIB_THREAD_LOCAL struct SlotType *SlotName

/**
 * @brief Declare an error slot type for the given error type. May appear
 * anywhere that the type 'T' is also visible and complete.
 *
 * @note There must be exactly one MERROR_DEF_ERROR_TYPE_SLOT() call in the
 * runtime program
 */
#define MERROR_DECL_ERROR_TYPE(T, Destroy) \
   pMLIB_DECL_ERROR_SLOT_1 (               \
      T, pMLIB_ERROR_SLOT_TYPE (T), pMLIB_ERROR_SLOT_NAME (T), (Destroy))

/**
 * @brief Declare the storage of the error slot for the given error type
 */
#define MERROR_DEF_ERROR_TYPE_SLOT(T)                   \
   MLIB_THREAD_LOCAL struct pMLIB_ERROR_SLOT_TYPE (T) * \
      pMLIB_ERROR_SLOT_NAME (T) = NULL

#define pMLIB_ERROR_HANDLE_PUSH_1(SlotT, SlotVar, SlotThreadPtr)             \
   struct SlotT SlotVar = {                                                  \
      ._previous =                                                           \
         (struct SlotT *) _merror_e_slot_replace (&SlotThreadPtr, &SlotVar), \
      .got_error = false,                                                    \
   }

/**
 * @brief Declare a local error slot object for the given error type.
 *
 * A variable will be declared in the current scope with the name of the type
 * with an `e_` prefix. For example, MERROR_HANDLES(int) declares a
 * local object `e_int`, which is an error slot for handling an `int`.
 *
 * @note One MUST execute a corresponding `MLIB_ERROR_HANDLE_POP()` call in the
 * same scope.
 */
#define MERROR_HANDLES(T)                                \
   pMLIB_ERROR_HANDLE_PUSH_1 (pMLIB_ERROR_SLOT_TYPE (T), \
                              MLIB_CONCAT (e_, T),       \
                              pMLIB_ERROR_SLOT_NAME (T))

#define merror_has_handler(T) (pMLIB_ERROR_SLOT_NAME (T) != NULL)

#define MLIB_ERROR_LOAD_1(T, SlotName, Value)                                 \
   (void) (merror_has_handler (T)                                             \
              ? (SlotName->handled = Value, SlotName->got_error = true, true) \
              : false)

#define MERROR_LOAD(T, ...) \
   MLIB_ERROR_LOAD_1 (T, pMLIB_ERROR_SLOT_NAME (T), ((T) __VA_ARGS__))


#define pMLIB_ERROR_HANDLE_POP_1(T, SlotThreadPtr, SlotVar)            \
   ((void) _merror_e_slot_replace (&SlotThreadPtr, SlotVar._previous), \
    MLIB_CONCAT (_mlib_e_destroy_for_, T) (&SlotVar))

#define MERROR_HANDLES_POP(T) \
   pMLIB_ERROR_HANDLE_POP_1 (T, pMLIB_ERROR_SLOT_NAME (T), MLIB_CONCAT (e_, T))

#define pMLIB_ERROR_HANDLER_BLOCK_1(T, SlotType, SlotName, SlotVar)   \
   for (int _only_once_ = 1; _only_once_;)                            \
      for (MERROR_HANDLES (T); _only_once_; SlotVar._previous = NULL) \
         for (; _only_once_; MERROR_HANDLES_POP (T), _only_once_ = 0)

#define MERROR_HANDLER_BLOCK(T)                            \
   pMLIB_ERROR_HANDLER_BLOCK_1 (T,                         \
                                pMLIB_ERROR_SLOT_TYPE (T), \
                                pMLIB_ERROR_SLOT_NAME (T), \
                                MLIB_CONCAT (e_, T))

#endif // MLIB_ERROR_PRIVATE_H
