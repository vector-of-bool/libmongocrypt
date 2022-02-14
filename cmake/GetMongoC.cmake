# Obtain a copy of libmongoc for libbson that we will use in libmongocrypt, and
# libmongoc for the csfle tests.
include (FetchContent OPTIONAL)

# Set the tag that we will fetch.
if (NOT DEFINED MONGOCRYPT_MONGOC_FETCH_TAG)
   set (MONGOCRYPT_MONGOC_FETCH_TAG "1.17.0")
endif ()

if (NOT DEFINED MONGOCRYPT_MONGOC_DIR)
   # The user did not provide a MONGOCRYPT_MONGOC_DIR, so we'll get one
   if (NOT COMMAND FetchContent_Declare)
      # We need FetchContent in order to download the project.
      message (FATAL_ERROR
               "No MONGOCRYPT_MONGOC_DIR setting was defined, and the FetchContent.cmake "
               "module is not available. Upgrade your CMake version, or provide a "
               "MONGOCRYPT_MONGOC_DIR path to a mongo-c-driver directory.")
   endif ()
   # Fetch the source archive for the requested tag from GitHub
   FetchContent_Declare (
      embedded_mcd
      URL "https://github.com/mongodb/mongo-c-driver/archive/refs/tags/${MONGOCRYPT_MONGOC_FETCH_TAG}.tar.gz"
      )
   # Populate it:
   FetchContent_GetProperties(embedded_mcd)
   if (NOT embedded_libbson_POPULATED)
      FetchContent_Populate (embedded_mcd)
   endif ()
   # Store the directory path to the external mongoc project:
   get_filename_component (MONGOCRYPT_MONGOC_DIR "${embedded_mcd_SOURCE_DIR}" ABSOLUTE)
   # The project wants a VERSION_CURRENT file. We know that based on the tag.
   file (WRITE "${embedded_mcd_SOURCE_DIR}/VERSION_CURRENT" "${MONGOCRYPT_MONGOC_FETCH_TAG}")
endif ()

# Disable AWS_AUTH, to prevent it from building the kms-message symbols, which we build ourselves
set (ENABLE_MONGODB_AWS_AUTH OFF)
# Add the subdirectory as a project. EXCLUDE_FROM_ALL to inhibit building and installing of components unless requested
add_subdirectory ("${MONGOCRYPT_MONGOC_DIR}" _ext_mongoc EXCLUDE_FROM_ALL)

# Define an alias target to the embedded libbson that we want
if (ENABLE_SHARED_BSON)
   add_library (_mongocrypt::libbson ALIAS bson_static)
else ()
   add_library (_mongocrypt::libbson ALIAS bson_shared)
endif ()

# And an alias to the mongoc target for use in some test cases
add_library (_mongocrypt::mongoc ALIAS mongoc_shared)
# Workaround: Embedded mongoc_shared does not set its INCLUDE_DIRECTORIES for user targets
target_include_directories (mongoc_shared
   PUBLIC
      "$<BUILD_INTERFACE:${MONGOCRYPT_MONGOC_DIR}/src/libmongoc/src>"
      "$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/_ext_mongoc/src/libmongoc/src/mongoc>"
   )
