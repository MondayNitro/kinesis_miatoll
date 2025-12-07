#!/bin/bash

set -eE
trap 'catch $? $LINENO' ERR

catch() {
    echo "❌ Build failed at line $2 with exit code $1" >&2
    exit $1
}

exec > build.log 2>&1

export KBUILD_BUILD_USER=nobody
export KBUILD_BUILD_HOST=android-build

export PATH=${PWD}/toolchain/bin:${PATH}
export AnyKernel3=AnyKernel3
export LLVM_DIR=${PWD}/toolchain/bin
export LLVM=1
export LLVM_IAS=1

export ARCH=arm64
export DEVICE=miatoll

if [[ -z "$1" || "$1" = "-c" ]]; then
    echo "Clean Build"
    rm -rf out
elif [ "$1" = "-d" ]; then
    echo "Dirty Build"
else
    echo "Error: Set $1 to -c or -d"
    exit 1
fi

curl -LSs https://raw.githubusercontent.com/rsuntk/KernelSU/main/kernel/setup.sh | bash -s main

ARGS="
ARCH=arm64
CC=clang
LLVM=1
LLVM_IAS=1
CROSS_COMPILE=${LLVM_DIR}/aarch64-linux-gnu-
CROSS_COMPILE_COMPAT=${LLVM_DIR}/arm-linux-gnueabi-
LD=${LLVM_DIR}/ld.lld
AR=${LLVM_DIR}/llvm-ar
NM=${LLVM_DIR}/llvm-nm
LLVM_AR=${LLVM_DIR}/llvm-ar
LLVM_NM=${LLVM_DIR}/llvm-nm
OBJCOPY=${LLVM_DIR}/llvm-objcopy
OBJDUMP=${LLVM_DIR}/llvm-objdump
READELF=${LLVM_DIR}/llvm-readelf
OBJSIZE=${LLVM_DIR}/llvm-size
STRIP=${LLVM_DIR}/llvm-strip
"

make ${ARGS} O=out vendor/xiaomi/miatoll_defconfig
make ${ARGS} O=out -j$(nproc --all)

if [ ! -e out/arch/arm64/boot/Image.gz ]; then
    echo "❌ ERROR: Image binary not found in expected location, fix compile!"
    exit 1
fi

git clone --branch kinesis --single-branch --depth=1 https://github.com/MondayNitro/AnyKernel3 ${AnyKernel3}

rm -rf ${AnyKernel3}/.github

kver=$(make kernelversion)
kmod=$(echo ${kver} | awk -F'.' '{print $3}')

cp out/.config kernel_config
cp out/arch/arm64/boot/Image.gz ${AnyKernel3}/Image.gz
cp out/arch/arm64/boot/dtbo.img ${AnyKernel3}/dtbo.img
cp out/arch/arm64/boot/dts/qcom/cust-atoll-ab.dtb ${AnyKernel3}/dtb

cd ${AnyKernel3}
zip -r9 build.zip * -x .git README.md *placeholder
echo "✅ Build completed successfully!"
