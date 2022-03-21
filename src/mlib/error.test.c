#include "./error.h"

#define CHECK(Expr)                                   \
   ((Expr) ? 0                                        \
           : ((fprintf (stderr,                       \
                        "%s:%d: Check '%s' failed\n", \
                        __FILE__,                     \
                        __LINE__,                     \
                        #Expr),                       \
               abort ()),                             \
              0))


MERROR_DECL_ERROR_TYPE (int, NULL);
MERROR_DEF_ERROR_TYPE_SLOT (int);

typedef struct my_error {
   mstr message;
} my_error;
MERROR_DECL_ERROR_TYPE (my_error, mstr_assign (&object->message, MSTR_NULL));
MERROR_DEF_ERROR_TYPE_SLOT (my_error);

int
main ()
{
   CHECK (merror_current_error ().id == 0);

   {
      merror_handler_push (my_error);
      merror_id err = merror_new_error ();

      merror_load (
         err, my_error, {.message = mstr_copy_cstr ("I am a message")});
      CHECK (merror_get (err, my_error));
      merror_handler_deactivate ();
      merror_handler_pop ();
   }

   {
      merror_handler_push (my_error);
      merror_id err = merror_new_error ();
      CHECK (!merror_get (err, my_error));
      merror_handler_deactivate ();
      merror_handler_pop ();
   }

   {
      merror_handler_push (int);
      CHECK (merror_has_handler (int));
      merror_id err = merror_new_error ();
      merror_load (err, int, 42);
      merror_handler_deactivate ();
      CHECK (!merror_has_handler (int));
      CHECK (merror_get (err, int));
      CHECK (*merror_get (err, int) == 42);
      merror_handler_pop ();
   }

   // No-op:
   merror_load (merror_new_error (), int, 42);

   MERROR_HANDLER_BLOCK (int)
   {
      CHECK (merror_has_handler (int));
      merror_id err = merror_new_error ();
      CHECK (!merror_get (err, int));
      merror_load (err, int, 1729);
      CHECK (merror_get (err, int));
      merror_handler_deactivate ();
      merror_load (err, int, 84);
      CHECK (merror_get (err, int));
      CHECK (!merror_has_handler (int));
      CHECK (*merror_get (err, int) == 1729);
   }
   CHECK (!merror_has_handler (int));

   MERROR_HANDLER_BLOCK (my_error)
   {
      CHECK (merror_has_handler (my_error));
      merror_id err = merror_new_error ();
      merror_load (
         err, my_error, {.message = mstr_copy_cstr ("I am a string")});
      CHECK (merror_get (err, my_error));
      MSTR_ASSERT_EQ (merror_get (err, my_error)->message.view,
                      mstrv_lit ("I am a string"));
      merror_handler_deactivate ();
   }
}
