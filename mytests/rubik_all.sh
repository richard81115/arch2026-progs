#!/usr/bin/env bash
# Build mytests/rubik_all.c against each C build and run it on rv32emu.
# Usage: mytests/rubik_all.sh d11.txt [O1 O2 O3 Os]
set -e
cd "$(dirname "$0")/.."
list=$1
shift
opts=${*:-O1 O2 O3 Os}
make elfs >/dev/null
mkdir -p build/mytests
{
    echo "#define D11_COUNT $(wc -l < "$list")u"
    echo "static const char *const d11[] = {"
    sed 's/.*/    "&",/' "$list"
    echo "};"
} > build/mytests/d11_states.h
for opt in $opts; do
    riscv-none-elf-gcc -march=rv32i_zicsr -mabi=ilp32 -ffreestanding -fno-pic \
        -fno-stack-protector -O2 -iquote . -Icommon -Itests -Ibuild/mytests \
        -c mytests/rubik_all.c -o build/mytests/all.o
    riscv-none-elf-ld -T common/linker.ld --no-warn-rwx-segments \
        -o build/mytests/all-$opt.elf build/rubik/$opt/impl.o \
        build/rubik/impl_asm.o build/mytests/all.o build/common/start.o \
        build/common/perf.o build/common/rt.o build/common/print.o
    echo "== $opt"
    third_party/rv32emu/build/rv32emu build/mytests/all-$opt.elf
done
