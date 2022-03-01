# Compiles libmongocrypt dependencies and targets.
#
# Set extra cflags for libmongocrypt variables by setting LIBMONGOCRYPT_EXTRA_CFLAGS.
#

set -e
. "$(dirname "${BASH_SOURCE[0]}")/init.sh"

echo "Begin compile process"

evergreen_root="$(pwd)"

cd $evergreen_root

if [ "${OS_NAME}" == "windows" ]; then
    # Make sure libbson.dll is in the path on Windows
    export PATH=${BSON_INSTALL_DIR}/bin:$PATH

    for var in TMP TEMP NUGET_PACKAGES NUGET_HTTP_CACHE_PATH APPDATA; do export $var=z:\\data\\tmp; done

    # Make dotnet happy over ssh
    export DOTNET_CLI_HOME=$(cygpath -w "${evergreen_root}/dotnet_home")
else
    export PATH=$PATH:/usr/share/dotnet
fi

dotnet_tool=$(which dotnet)

_mcr_build="$(native_path "${LIBMONGOCRYPT_BUILD_ROOT}")"

"$dotnet_tool" build -c Release "${_mcr_build}/default/bindings/cs/cs.sln"

"$dotnet_tool" test -c Release "${_mcr_build}/default/bindings/cs/MongoDB.Libmongocrypt.Test/MongoDB.Libmongocrypt.Test.csproj" -- RunConfiguration.TargetPlatform=x64
