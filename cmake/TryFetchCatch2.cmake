# Try to enable a C++ compiler:
enable_language (CXX OPTIONAL)
if (NOT CMAKE_CXX_COMPILER_ID)
    message (STATUS "No C++ compiler: Not using Catch2")
    return ()
endif ()

include (FetchContent OPTIONAL)
if (NOT COMMAND FetchContent_MakeAvailable)
    message (STATUS "No FetchContent_MakeAvailable(): Not downloading Catch2")
    return ()
endif ()

# These features are explicitly required by Catch2 in its CMake config:
set (required_features cxx_alignas cxx_alignof cxx_attributes cxx_auto_type
    cxx_constexpr cxx_defaulted_functions cxx_deleted_functions cxx_final
    cxx_lambdas cxx_noexcept cxx_override cxx_range_for cxx_rvalue_references
    cxx_static_assert cxx_strong_enums cxx_trailing_return_types
    cxx_unicode_literals cxx_user_literals cxx_variable_templates
    cxx_variadic_macros)

set (missing_features ${required_features})
list (REMOVE_ITEM missing_features ${CMAKE_CXX_COMPILE_FEATURES})

if (missing_features)
    string (REPLACE ";" ", " missing "${missing_features}")
    message (STATUS "Not using Catch2: C++ compiler is missing required features: ${missing}")
    return ()
endif ()

# Obtain Catch2 v3.1.0
FetchContent_Declare (Catch2
    URL "https://github.com/catchorg/Catch2/archive/refs/tags/v3.1.0.zip"
    )

FetchContent_Populate (Catch2)

# Import the module, used to define/discover tests automatically
list (APPEND CMAKE_MODULE_PATH "${catch2_SOURCE_DIR}/extras")
include (Catch)

# Build a library from the amalgamation. This builds significantly faster than
# compiling all files individually (we don't care about incremental compilation)
add_library (Catch2WithMain STATIC "${catch2_SOURCE_DIR}/extras/catch_amalgamated.cpp")
target_include_directories (Catch2WithMain INTERFACE "${catch2_SOURCE_DIR}/extras")
target_compile_features (Catch2WithMain PUBLIC ${required_features})

# GCC has trouble with compiling and optimizing the large Catch2 file, and takes
# several minutes before giving up and dropping the debug info. We don't need
# opt and debug info for Catch2, so compile it plain.
target_compile_options (Catch2WithMain PRIVATE $<$<CXX_COMPILER_ID:GNU>: -O0 -g0 >)
