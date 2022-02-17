include(CMakeFindDependencyMacro)
find_dependency(kms_message 0.0.1)
include("${CMAKE_CURRENT_LIST_DIR}/mongocrypt_targets.cmake")

if (TARGET mongo::mongocrypt_static)
    # We are exporting the mongocrypt static library, which requires a libbson
    # in order to be used. Search for an appropriate CMake target to link with.
    set (_libbson_link)
    if(DEFINED MONGOCRYPT_USE_LIBBSON_TARGET)
        set (_libbson_link ${MONGOCRYPT_USE_LIBBSON_TARGET})
    elseif (TARGET mongo::bson_static)
        set (_libbson_link mongo::bson_static)
    elseif (TARGET mongo::bson_shared)
        set (_libbson_link mongo::bson_shared)
    elseif (TARGET bson_static)
        set (_libbson_link bson_static)
    elseif (TARGET bson_shared)
        set (_libbson_link bson_shared)
    elseif (NOT MONGOCRYPT_NO_WARN_MISSING_LIBBSON)
        message (WARNING
            "No libbson library target is defined. In order to use mongo::mongocrypt_static, "
            "you will need to explicitly link to a libbson library, add an appropriate "
            "find_package() call to find libbson prior to find_package(mongocrypt), OR "
            "set MONGOCRYPT_USE_LIBBSON_TARGET to a target/library name before calling "
            "find_package(mongocrypt). "
            "(Set MONGOCRYPT_NO_WARN_MISSING_LIBBSON to silence this warning)")
    endif ()
    if (_libbson_link)
        message (STATUS "mongo::mongocrypt_static will use ${_libbson_link} for a libbson")
        set_property (
            TARGET mongo::_mongocrypt-libbson
            APPEND PROPERTY INTERFACE_LINK_LIBRARIES ${_libbson_link}
            )
    endif ()
endif ()
