#!/usr/bin/env bash

main() {
  cd "$(dirname "$0")/"

    case "$1" in
      diff)
        cd code-server/lib
        diff -x node_modules -x build -x .build -x 'out-*' -x out -ru vscode.orig vscode
        ;;
      save-diff)
        cd code-server/lib
        diff -x node_modules -x build -x .build -x 'out-*' -x out -ru vscode.orig vscode > ../ci/dev/vscode.vh.patch
        ;;
      apply-patch)
        cd code-server/lib/vscode
        git apply ../../../vscode.vh.patch
        ;;
      build-android-env)
        docker build ./container/android -t vsandroidenv:latest
        ;;
      release)
        set -x
        if [ ! -z "$BUILD_RELEASE" ]; then
          cd code-server
          rm -rf release release-static || true
          cd lib/vscode && CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH yarn
          cd ../..
          CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH yarn build
          CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH yarn build:vscode
          CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH yarn release
          CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH yarn release:static
          cd release-static
          CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH yarn --production --frozen-lockfile
          cd ../..
        fi
        case $ANDROID_ARCH in
          arm) ARCH_NAME="armeabi-v7a" ;;
          x86) ARCH_NAME="x86" ;;
          x64) ARCH_NAME="x86_64" ;;
          arm64|aarch64) ARCH_NAME="arm64-v8a" ;;
          *) echo "Unsupported arch $ANDROID_ARCH"; exit 1; ;;
        esac
        rm -f cs.tar.gz libc++_shared.so node
        cp node-src/out/Release/node ./node
        cp /opt/android-ndk/sources/cxx-stl/llvm-libc++/libs/$ARCH_NAME/libc++_shared.so ./libc++_shared.so
        tar -czvf cs.tgz code-server/release-static code-server/VERSION
        ;;
      *)
        docker run --rm -it \
                -w /vscode \
                -e ANDROID_BUILD_API_VERSION=26 \
                -v $(pwd):/vscode \
                -v $(pwd)/container/android:/vscode-build \
                -v $(pwd)/node:/vscode-node \
                -v $(pwd)/.git/modules/code-server:/.git/modules/code-server \
                vsandroidenv:latest bash; exit $?
        ;;
    esac
}

main "$@"

