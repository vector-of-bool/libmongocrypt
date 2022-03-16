#pragma push_macro("MLIB_CONCAT")
#pragma push_macro("MLIB_CONCAT_1")

#define MLIB_CONCAT_1(a, b) a##b
#define MLIB_CONCAT(a, b) MLIB_CONCAT_1 (a, b)

#pragma push_macro("MLIB_SCOPED_BLOCK")
#define MLIB_SOCPED_BLOCK(Before, After)                                     \
   for (int _mlib_scoped_once_ = ((Before), 1); _mlib_scoped_once_; (After)) \
      for (; _mlib_scoped_once_; _mlib_scoped_once_ = 0)
