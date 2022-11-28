#include <catch2/catch.hpp>

#include "./mc-dec128.h"

inline std::ostream &
operator<< (std::ostream &out, mc_dec128 d) noexcept
{
   auto s = mc_dec128_to_new_decimal_string (d);
   out << s;
   free (s);
   return out;
}

#define OPER(Op, Fn)                                           \
   inline auto operator Op (mc_dec128 a, mc_dec128 b) noexcept \
   {                                                           \
      return mc_dec128_##Fn (a, b);                            \
   }

OPER (+, add)
OPER (-, sub)
OPER (*, mul)
OPER (/, div)
OPER (==, equal)
OPER (>, greater)
OPER (<, less)

TEST_CASE ("Simple decimal128 math")
{
   mc_dec128 a = MC_DEC128_ZERO;
   REQUIRE (mc_dec128_is_zero (a));

   mc_dec128 b = MC_DEC128_ZERO;
   mc_dec128 c = a * b;
   CHECK (c == MC_DEC128_ZERO);
   CHECK (mc_dec128_is_zero (c));

   b = MC_DEC128_C (1);
   // 0 + 1 = 1
   c = a + b;
   CHECK (c == MC_DEC128_C (1));

   // 1 + 1 = 2
   c = b + b;
   CHECK (c == MC_DEC128_C (2));

   // 2 * 2 = 4
   c = c * c;
   CHECK (c == MC_DEC128_C (4));

   // (4 + 1) / 2 = 2.5
   c = (c + MC_DEC128_C (1)) / MC_DEC128_C (2);
   CHECK (c == mc_dec128_from_string ("2.5"));

   mc_dec128_string s = mc_dec128_to_string (c);
   CHECK_THAT (s.str, Catch::Matchers::Equals ("+25E-1"));

   char *str = mc_dec128_to_new_decimal_string (c);
   CHECK_THAT (str, Catch::Matchers::Equals ("2.5"));
   free (str);
}
