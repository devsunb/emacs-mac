#!/usr/bin/env bash

set -Eeuo pipefail

# [클린 빌드 시에만 주석 해제]
# git clean -fd
# git clean -fdX

# [configure.ac 또는 *.m4 파일 변경 시에만 필요]
# ./autogen.sh

# [Makefile.in 변경 또는 configure 옵션 변경 시에만 필요]
# CFLAGS="-O3 -mcpu=native -fobjc-arc" ./configure \
#   --enable-mac-app=yes \
#   --enable-mac-self-contained

make -j16

rm -rf /Applications/Emacs.app
make install
