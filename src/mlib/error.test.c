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
MERROR_DECL_ERROR_TYPE (my_error, mstr_assign (&handled.message, MSTR_NULL));
MERROR_DEF_ERROR_TYPE_SLOT (my_error);

int
main ()
{
   CHECK (merror_current_error ().id == 0);

   MERROR_HANDLES (int);
   CHECK (merror_has_handler (int));
   CHECK (!e_int.got_error);
   MERROR_LOAD (int, 42);
   CHECK (e_int.got_error);
   CHECK (e_int.handled == 42);
   MERROR_HANDLES_POP (int);
   CHECK (!merror_has_handler (int));
   CHECK (e_int.handled == 42);
   // No-op:
   MERROR_LOAD (int, 42);

   MERROR_HANDLER_BLOCK (int)
   {
      CHECK (merror_has_handler (int));
      CHECK (!e_int.got_error);
      MERROR_LOAD (int, 1729);
      CHECK (e_int.got_error);
      CHECK (e_int.handled == 1729);
   }
   CHECK (!merror_has_handler (int));

   MERROR_HANDLER_BLOCK (my_error)
   {
      CHECK (merror_has_handler (my_error));
      CHECK (e_my_error.handled.message.data == NULL);
      MERROR_LOAD (my_error, {.message = mstr_copy_cstr ("I am a string")});
      CHECK (e_my_error.got_error);
      MSTR_ASSERT_EQ (e_my_error.handled.message.view,
                      mstrv_lit ("I am a string"));
      MERROR_HANDLES_POP (my_error);
      MSTR_ASSERT_EQ (e_my_error.handled.message.view, MSTR_NULL.view);
   }
}
