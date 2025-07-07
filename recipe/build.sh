#!/bin/bash

set -euxo pipefail

if [[ "${target_platform}" == osx-* ]]; then
    # See also https://gitlab.kitware.com/cmake/cmake/-/issues/25755
    export CFLAGS="${CFLAGS} -fno-define-target-os-macros"
fi

source gen-bazel-toolchain

export ABSEIL_VERSION=$(conda list -p $PREFIX libabseil --fields version | grep -v '#')
export PROTOC_VERSION=$(conda list -p $PREFIX libprotobuf | grep -v '^#' | tr -s ' ' | cut -f 2 -d ' ' | sed -E 's/^[0-9]+\.([0-9]+\.[0-9]+)$/\1/')
export PROTOBUF_JAVA_MAJOR_VERSION="3"
export EXTRA_BAZEL_ARGS="--host_javabase=@local_jdk//:jdk"
sed -ie "s:\${INSTALL_NAME_TOOL}:${INSTALL_NAME_TOOL:-install_name_tool}:" src/BUILD
sed -ie "s:\${PREFIX}:${PREFIX}:" src/BUILD
sed -ie "s:\${BUILD_PREFIX}:${BUILD_PREFIX}:" third_party/grpc/BUILD
sed -ie "s:\${BUILD_PREFIX}:${BUILD_PREFIX}:" third_party/systemlibs/protobuf/BUILD
sed -ie "s:\${BUILD_PREFIX}:${BUILD_PREFIX}:" third_party/ijar/BUILD
sed -ie "s:ABSEIL_VERSION:${ABSEIL_VERSION}:" third_party/systemlibs/protobuf/MODULE.bazel
sed -ie "s:ABSEIL_VERSION:${ABSEIL_VERSION}:" MODULE.bazel

cp -ap $PREFIX/share/bazel/protobuf/bazel third_party/systemlibs/protobuf/

chmod +x bazel
pushd src/tools/singlejar
../../../bazel build \
	--logging=6 \
	--subcommands \
	--verbose_failures \
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
