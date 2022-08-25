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
   int value = 0;
   mlib_defer_begin ();
   mlib_defer (value = 12);
   CHECK (value == 0);
   mlib_defer_end_return ();
}

int
main ()
{
   test1 ();
}
