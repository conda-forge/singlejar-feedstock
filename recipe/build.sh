#!/bin/bash

set -euxo pipefail

if [[ "${target_platform}" == osx-* ]]; then
    # See also https://gitlab.kitware.com/cmake/cmake/-/issues/25755
    export CFLAGS="${CFLAGS} -fno-define-target-os-macros -target ${HOST}"
    export LDFLAGS="${LDFLAGS} -target ${HOST}"
fi

# Prepare systemlibs defintions
mkdir -p third_party/systemlibs
cp -ap "${PREFIX}/share/bazel/systemlibs/absl" third_party/systemlibs/
cp -ap "${PREFIX}/share/bazel/systemlibs/protobuf" third_party/systemlibs/
cp -ap $PREFIX/share/bazel/protobuf/bazel third_party/systemlibs/protobuf/

source gen-bazel-toolchain

export ABSEIL_VERSION="$(conda list -p "${PREFIX}" libabseil --fields version | awk '!/^#/ && NF { print $1; exit }')"
export PROTOC_VERSION="$(conda list -p "${PREFIX}" libprotobuf --fields version | awk '!/^#/ && NF { print $1; exit }' | sed -E 's/^[0-9]+\.([0-9]+\.[0-9]+)$/\1/')"
export PROTOBUF_JAVA_MAJOR_VERSION="3"
export EXTRA_BAZEL_ARGS="--host_javabase=@local_jdk//:jdk"
sed -ie "s:ABSEIL_VERSION:${ABSEIL_VERSION}:" \
	third_party/systemlibs/protobuf/MODULE.bazel \
	MODULE.bazel

chmod +x bazel-${PKG_VERSION}
pushd src/tools/singlejar
../../../bazel-${PKG_VERSION} build \
	--logging=6 \
	--subcommands \
	--verbose_failures \
	--noincompatible_enable_proto_toolchain_resolution \
	--define=PROTOC_PREFIX=${BUILD_PREFIX} \
	--define=PROTOBUF_INCLUDE_PATH=${PREFIX}/include \
	--extra_toolchains=//bazel_toolchain:cc_cf_toolchain \
	--extra_toolchains=//bazel_toolchain:cc_cf_host_toolchain \
	--platforms=//bazel_toolchain:target_platform \
	--host_platform=//bazel_toolchain:build_platform \
	--cpu ${TARGET_CPU} \
	singlejar singlejar_local
mkdir -p $PREFIX/bin
cp ../../../bazel-out/${TARGET_CPU}-fastbuild/bin/src/tools/singlejar/singlejar $PREFIX/bin
cp ../../../bazel-out/${TARGET_CPU}-fastbuild/bin/src/tools/singlejar/singlejar_local $PREFIX/bin


../../../bazel-${PKG_VERSION} clean --expunge
