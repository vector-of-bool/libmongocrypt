#ifndef MLIB_ERROR_PRIVATE_H
#define MLIB_ERROR_PRIVATE_H

#include "./user-check.h"

#include "./str.h"
#include "./thread.h"
#include "./macros.h"

#ifdef _WIN32
#include "./windows-lean.h"
#else
#include <errno.h>
#endif

#include <inttypes.h>

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

/**
 * @brief An object representing an error.
 */
typedef struct merror_id {
   /// The ID of the error. If zero, represents no error.
   int64_t id;
} merror_id;

#ifdef _MSC_VER
__declspec(selectany)
#elif __GNUC__ || __clang__
#if _WIN32
__attribute__ ((selectany))
#else
asm(".pushsection .tbss.mlib.dedup1, \"awTG\", @nobits, comdat\n"
    ".type _g_mlib_current_error,@tls_object\n"
    "_g_mlib_current_error:\n"
    ".zero 8\n"
    ".size _g_mlib_current_error, . - _g_mlib_current_error\n"
    ".popsection\n");
#endif
#endif
   extern MLIB_THREAD_LOCAL merror_id _g_mlib_current_error;

/**
 * @brief Generate a new error ID for the current thread and return that ID.
 */
static inline merror_id
merror_new_error ()
{
   _g_mlib_current_error.id++;
   return _g_mlib_current_error;
}

/**
 * @brief Return the current error ID for the calling thread
 */
static inline merror_id
merror_current_error ()
{
   return _g_mlib_current_error;
}

struct merror_info {
   merror_id error;
   void *tl_ptrptr;
   void *tl_previous;
   void *object;
   void (*destroy) (struct merror_info *info);
   struct merror_info *next_info;
};

struct merror_handling_scope {
   struct merror_info *last_info;
};

/// Expand to the type name of the error handing slot type for the given error
/// type
#define pMERROR_SLOT_TYPE(TypeName) \
   MLIB_CONCAT (_mlib_e_slot_type_for_, TypeName)

/// @private Expand to the name of the global variable managing the given slot
#define pMERROR_SLOT_PTR(TypeName) MLIB_CONCAT (_mlib_e_slot_ptr_for_, TypeName)

#define pMERROR_SLOT_INFO_VAR(T) MLIB_CONCAT (_mlib_e_, T)

static inline void *
_merror_e_slot_replace (void *tl_ptrptr, void *new_ptr)
{
   void **tl_ptr = tl_ptrptr;
   void *old_ptr = *tl_ptr;
   *tl_ptr = new_ptr;
   return old_ptr;
}

#define pMERROR_DECL_ERROR_TYPE_1(T, SlotType, SlotName, Destroy)   \
   struct SlotType {                                                \
      struct merror_info _p;                                        \
      T handled;                                                    \
   };                                                               \
   static inline void MLIB_CONCAT (_mlib_e_destroy_for_,            \
                                   T) (struct merror_info * _info_) \
   {                                                                \
      if (_info_->error.id) {                                       \
         T *object = _info_->object;                                \
         (void) object;                                             \
         (void) (Destroy);                                          \
      }                                                             \
   }                                                                \
   extern MLIB_THREAD_LOCAL struct SlotType *SlotName

/**
 * @brief Declare an error slot type for the given error type. May appear
 * anywhere that the type 'T' is also visible.
 *
 * @param T The type for which to enable error-handling.
 * @param Destroy An expression that destroys a value of `T` when you are dont
 * with it. In the expression, the name `object` is a pointer to the error
 * object. The expression will only be evaluated if there was a call to
 * `merror_load` for `T`.
 *
 * @note There must be exactly one MERROR_DEF_ERROR_TYPE_SLOT() call in the
 * final program. It should appear once in any one C source file.
 */
#define MERROR_DECL_ERROR_TYPE(T, Destroy) \
   pMERROR_DECL_ERROR_TYPE_1 (             \
      T, pMERROR_SLOT_TYPE (T), pMERROR_SLOT_PTR (T), (Destroy))

/**
 * @brief Declare the storage of the error slot for the given error type
 */
#define MERROR_DEF_ERROR_TYPE_SLOT(T) \
   MLIB_THREAD_LOCAL struct pMERROR_SLOT_TYPE (T) * pMERROR_SLOT_PTR (T) = NULL


#define merror_has_handler(T) (pMERROR_SLOT_PTR (T) != NULL)

#define pMERROR_GET(ErrorID, T, SlotVar)                              \
   ((SlotVar._p.error.id == (ErrorID).id && SlotVar._p.error.id != 0) \
       ? &SlotVar.handled                                             \
       : NULL)

/**
 * @brief Obtain the error object value associated with the given error ID
 *
 * Given an error id `ErrorID` and a type `T`, obtain a pointer-to `T` if there
 * is any `T` object that was loaded for the given `ErrorID` within the current
 * error handling scope. `T` must be a type that is declared to be handled in
 * the current error-handling scope via `MERROR_HANDLER_BLOCK` or
 * `MERROR_HANDLER_PUSH`.
 *
 * If no `T` object was loaded for the given error, or if ErrorID is zero,
 * returns a NULL pointer-to-T.
 */
#define merror_get(ErrorID, T) \
   pMERROR_GET (ErrorID, T, pMERROR_SLOT_INFO_VAR (T))

#define pMERROR_LOAD(EID, T, SlotThreadPtr, Value)                     \
   (void) ((merror_has_handler (T) && SlotThreadPtr->_p.error.id == 0) \
              ? (SlotThreadPtr->handled = Value,                       \
                 SlotThreadPtr->_p.error = EID,                        \
                 true)                                                 \
              : false)

#define merror_load(ErrorID, T, ...) \
   pMERROR_LOAD ((ErrorID), T, pMERROR_SLOT_PTR (T), ((T) __VA_ARGS__))

#define pMERROR_TYPE_BLOCK_HEAD(_unused, _counter, T)            \
   for (pMLIB_ERROR_DECL_SLOT_FOR_1 (T,                          \
                                     pMERROR_SLOT_TYPE (T),      \
                                     pMERROR_SLOT_PTR (T),       \
                                     MLIB_CONCAT (_mlib_e_, T)); \
        _only_once_;)

#define MERROR_HANDLER_BLOCK(...)                              \
   for (int _only_once_ = 1; _only_once_;)                     \
      for (struct merror_handling_scope _mlib_error_scope_ =   \
              {                                                \
                 .last_info = NULL,                            \
              };                                               \
           _only_once_;)                                       \
         MLIB_MAP (pMERROR_TYPE_BLOCK_HEAD, ~, __VA_ARGS__)    \
   for (; _only_once_; merror_handler_pop (), _only_once_ = 0) \
      for (; _only_once_; _only_once_ = 0)

#define pMLIB_ERROR_DECL_SLOT_FOR_1(T, SlotType, SlotThreadPtr, SlotVar)      \
   struct SlotType SlotVar = {                                                \
      ._p =                                                                   \
         (struct merror_info){                                                \
            .tl_ptrptr = &SlotThreadPtr,                                      \
            .tl_previous = _merror_e_slot_replace (&SlotThreadPtr, &SlotVar), \
            .object = &SlotVar.handled,                                       \
            .destroy = &MLIB_CONCAT (_mlib_e_destroy_for_, T),                \
            .next_info = _merror_e_slot_replace (                             \
               &_mlib_error_scope_.last_info, &SlotVar._p),                   \
         },                                                                   \
   }
#define pMLIB_ERROR_DECL_SLOT_FOR(_const, _counter, T) \
   pMLIB_ERROR_DECL_SLOT_FOR_1 (T,                     \
                                pMERROR_SLOT_TYPE (T), \
                                pMERROR_SLOT_PTR (T),  \
                                pMERROR_SLOT_INFO_VAR (T));

#define merror_handler_push(...)                       \
   struct merror_handling_scope _mlib_error_scope_ = { \
      .last_info = NULL,                               \
   };                                                  \
   MLIB_MAP (pMLIB_ERROR_DECL_SLOT_FOR, ~, __VA_ARGS__) ((void) 0)

static inline void
_merror_run_destructors (struct merror_handling_scope *scope)
{
   for (struct merror_info *d = scope->last_info; d; d = d->next_info) {
      void **ptrptr = d->tl_ptrptr;
      (void) ptrptr;
      assert (*ptrptr == d->tl_previous &&
              "Do not call merror_handler_pop() without first calling "
              "merror_handler_deactivate()\n");
      if (d->error.id != 0) {
         d->destroy (d);
      }
   }
}

static inline void
_merror_deactivate (struct merror_handling_scope *scope)
{
   for (struct merror_info *d = scope->last_info; d; d = d->next_info) {
      void **ptrptr = d->tl_ptrptr;
      assert (*ptrptr == d && "merror_handler_deactivate() does not match the "
                              "prior call to merror_handler_push()");
      *ptrptr = d->tl_previous;
   }
}

#define merror_handler_deactivate() _merror_deactivate (&_mlib_error_scope_)
#define merror_handler_pop() _merror_run_destructors (&_mlib_error_scope_)

#endif // MLIB_ERROR_PRIVATE_H
