#!/usr/bin/env bash

set -Eeuo pipefail

# [clean build]
# git clean -fd
# git clean -fdX

# [configure.ac or *.m4 changed]
# ./autogen.sh

# [Makefile.in or configure options changed]
# CFLAGS="-O3 -mcpu=native -fobjc-arc" ./configure \
#   --enable-mac-app=yes \
#   --enable-mac-self-contained

make -j16

rm -rf /Applications/Emacs.app
make install
