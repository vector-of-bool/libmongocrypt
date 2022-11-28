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
    cxx_unicode_literals cxx_user_literals cxx_variadic_macros)

list (REMOVE_ITEM required_features ${CMAKE_CXX_COMPILE_FEATURES} ~~~)

if (required_features)
    string (REPLACE ";" ", " missing "${required_features}")
    message (STATUS "Not using Catch2: C++ compiler is missing required features: ${missing}")
    return ()
endif ()

# Obtain Catch2 v2.13.10
FetchContent_Declare (Catch2
    URL "https://github.com/catchorg/Catch2/archive/refs/tags/v2.13.10.zip"
    )

FetchContent_Populate (Catch2)

add_library (catch2-interface INTERFACE)
target_include_directories (catch2-interface INTERFACE "${catch2_SOURCE_DIR}/single_include")
add_library (Catch2::Catch2 ALIAS catch2-interface)

# # Build a library from the amalgamation. This builds significantly faster than
# # compiling all files individually (we don't care about incremental compilation)
add_library (catch2-main STATIC "${CMAKE_CURRENT_LIST_DIR}/catch2-main.cpp")
target_link_libraries (catch2-main PUBLIC catch2-interface)
add_library (Catch2::Main ALIAS catch2-main)

# Import the module, used to define/discover tests automatically
list (APPEND CMAKE_MODULE_PATH "${catch2_SOURCE_DIR}/contrib")
include (Catch)
