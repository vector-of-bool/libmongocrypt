# Compiles libmongocrypt dependencies and targets.
#

set -o xtrace
set -o errexit

echo "Begin compile process"

evergreen_root="$(pwd)"

. ${evergreen_root}/libmongocrypt/.evergreen/setup-env.sh

cd $evergreen_root

if [ "$OS" == "Windows_NT" ]; then
    # Make sure libbson.dll is in the path on Windows
    export PATH=${INSTALL_PREFIX}/mongo-c-driver/bin:$PATH

    for var in TMP TEMP NUGET_PACKAGES NUGET_HTTP_CACHE_PATH APPDATA; do export $var=z:\\data\\tmp; done

    # Make dotnet happy over ssh
    export DOTNET_CLI_HOME=$(cygpath -w "${evergreen_root}/dotnet_home")
else
    export PATH=$PATH:/usr/share/dotnet
fi

dotnet_tool=$(which dotnet)

"$dotnet_tool" build -c Release libmongocrypt/cmake-build/bindings/cs/cs.sln

"$dotnet_tool" test -c Release libmongocrypt/cmake-build/bindings/cs/MongoDB.Libmongocrypt.Test/MongoDB.Libmongocrypt.Test.csproj -- RunConfiguration.TargetPlatform=x64
