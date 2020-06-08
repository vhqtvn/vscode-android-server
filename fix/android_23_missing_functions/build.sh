#!/bin/bash

/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android23-clang -fPIC -shared in6addr_any.c -o in6addr_any.so