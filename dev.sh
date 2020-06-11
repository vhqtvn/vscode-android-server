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
        case $ANDROID_ARCH in
          arm|armeabi-v7a)
            ARCH_NAME="armeabi-v7a"
            NODE_CONFIGURE_NAME="arm"
          ;;
          x86)
            ARCH_NAME="x86"
            NODE_CONFIGURE_NAME="x86"
          ;;
          x86_64)
            ARCH_NAME="x86_64"
            NODE_CONFIGURE_NAME="x86_64"
            ;;
          arm64|aarch64)
            ARCH_NAME="arm64-v8a"
            NODE_CONFIGURE_NAME="arm64"
            ;;
          *)
            echo "Unsupported arch $ANDROID_ARCH"
            exit 1
            ;;
        esac
        if [ ! -z "$BUILD_NODE" ]; then
          cd node-src
          rm -rf out || true
          make clean || true
          PATH=/vscode-build/hostbin:$PATH ./android-configure /opt/android-ndk/ $NODE_CONFIGURE_NAME $ANDROID_BUILD_API_VERSION
          JOBS=$(nproc) make -j $(nproc)
          cd ..
        fi
        if [ ! -z "$BUILD_RELEASE" ]; then
          cd code-server
          rm -rf release release-static node_modules || true
          CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH yarn
          cd lib/vscode && (rm -rf node_modules || true) && CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH yarn
          cd ../..
          CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH yarn build
          CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH yarn build:vscode
          CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH yarn release
          CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH yarn release:static
          cd release-static
          CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH yarn --production --frozen-lockfile
          cd ../..
        fi
        rm -rf cs-$ANDROID_ARCH.tgz libc++_shared.so node
        cp node-src/out/Release/node ./
        cp /opt/android-ndk/sources/cxx-stl/llvm-libc++/libs/$ARCH_NAME/libc++_shared.so ./libc++_shared.so
        tar -czvf cs-$ANDROID_ARCH.tgz code-server/release-static code-server/VERSION node "libc++_shared.so"
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

