#include "./defer.h"

#include <stdio.h>
#include <string.h>

#define CHECK(Expr)                                   \
   ((Expr) ? 0                                        \
           : ((fprintf (stderr,                       \
                        "%s:%d: Check '%s' failed\n", \
                        __FILE__,                     \
                        __LINE__,                     \
                        #Expr),                       \
               abort ()),                             \
              0))

static void
test1 ()
{
   mlib_defer_begin ();
   int value = 0;
   mlib_defer (value = 12);
   CHECK (value == 0);
   mlib_defer_runall ();
   CHECK (value == 12);
   CHECK (value == 12);
   mlib_defer_end ();
}

static void
test2 ()
{
   int outer = 0;
   mlib_defer_begin ();
   mlib_defer (outer = 9);
   {
      mlib_defer_push ();
      int inner = 12;
      mlib_defer (inner = 7);
      CHECK (inner == 12);
      mlib_defer_pop ();
      CHECK (inner == 7);
      CHECK (outer == 0);
   }
   mlib_defer_runall ();
   CHECK (outer == 9);
   mlib_defer_end ();
}

static void
test3 ()
{
   mlib_defer_begin ();
   int i = 0;
   for (; i < 900; ++i) {
      mlib_defer_push ();
      char buf[64] = {0};
      snprintf (buf, 64, "%d", i);
      char *s = strdup (buf);
      mlib_defer (free (s));
      if (strcmp (s, "42") == 0) {
         mlib_defer_break;
      }
      mlib_defer_pop ();
   }
   CHECK (i == 42);
   mlib_defer_end_return ();
}

int
main ()
{
   test1 ();
   test2 ();
   test3 ();
}
