#include "mongocrypt.h"

#include "mongocrypt-dll-private.h"

#include <mlib/path.h>

#include "test-mongocrypt.h"

static void
_test_load_simple_library (_mongocrypt_tester_t *t)
{
   (void) t;
   mstr self_path = mstr_copy_cstr (TEST_MONGOCRYPT_OUTPUT_PATH);

   mstr dll_path = mpath_join (mpath_parent (self_path.view, MPATH_NATIVE),
                               mstrv_view_cstr ("test-dll.dll"),
                               MPATH_NATIVE);

   mcr_dll lib;
   MERROR_HANDLER_BLOCK (dll_open_error)
   {
      lib = mcr_dll_open (dll_path.data);
      BSON_ASSERT (!e_dll_open_error.got_error);
   }

   int (*say_hello) (void) = mcr_dll_sym (lib, "say_hello");
   BSON_ASSERT (say_hello != NULL);

   int rval = say_hello ();
   ASSERT_CMPINT (rval, ==, 42);

   mcr_dll_close (lib);
   mstr_free (dll_path);
   mstr_free (self_path);
   BSON_ASSERT (!merror_has_handler (dll_open_error));
}

static void
_test_load_nonesuch (_mongocrypt_tester_t *t)
{
   (void) t;
   MERROR_HANDLER_BLOCK (dll_open_error)
   {
      mcr_dll lib = mcr_dll_open ("no-such-directory/no-such-lib.dll");
      BSON_ASSERT (lib._native_handle == NULL);
      BSON_ASSERT (e_dll_open_error.got_error);
      mcr_dll_close (lib);
   }
}

void
_mongocrypt_tester_install_dll (_mongocrypt_tester_t *tester)
{
   INSTALL_TEST (_test_load_simple_library);
   INSTALL_TEST (_test_load_nonesuch);
}
