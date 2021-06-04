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
        if [[ -f ./vscode.vh.patch ]]; then
          cd code-server/lib/vscode && git apply ../../../vscode.vh.patch
        fi
        if [[ -f ./node-src.vh.patch ]]; then
          cd node-src && git apply ../node-src.vh.patch
        fi
        ;;
      build-android-env)
        docker build ./container/android -t vsandroidenv:latest
        ;;
      release)
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
	set -e
        if [ ! -z "$BUILD_NODE" ]; then
          cd node-src
          rm -rf out
          make clean
          PATH=/vscode-build/hostbin:$PATH CC_host=gcc CXX_host=g++ LINK_host=g++ ./android-configure /opt/android-ndk/ $NODE_CONFIGURE_NAME $ANDROID_BUILD_API_VERSION
          PATH=/vscode-build/hostbin:$PATH JOBS=$(nproc) make -j $(nproc)
          cd ..
        fi
        for f in /usr/lib/node_modules/npm/bin/node-gyp-bin/node-gyp; do
          if [ ! -f "$f.orig" ]; then
            mv $f "$f.orig"
          fi
          echo -e '#!/bin/bash\necho "okzzz"\nnode-gyp.orig --nodedir /vscode/node-src/ $@' > $f
          chmod +x $f
        done
        if [ ! -z "$BUILD_RELEASE" ]; then
          pushd code-server
            rm -rf release release-standalone node_modules
            CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH yarn
            pushd lib/vscode
              rm -rf node_modules
              CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH yarn
            popd
            CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH yarn build
            CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH yarn build:vscode
            CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH yarn release
            CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH yarn release:standalone
            cd release-standalone
            CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH yarn --production --frozen-lockfile
          popd
        fi
        rm -rf cs-$ANDROID_ARCH.tgz libc++_shared.so node
        cp node-src/out/Release/node ./
        cp /opt/android-ndk/sources/cxx-stl/llvm-libc++/libs/$ARCH_NAME/libc++_shared.so ./libc++_shared.so
	cat code-server/package.json | jq -r '.version' > code-server/VERSION
        tar -czvf cs-$ANDROID_ARCH.tgz code-server/release-standalone code-server/VERSION node "libc++_shared.so"
        ;;
      *)
        docker run --rm -it \
                -w /vscode \
                -e ANDROID_BUILD_API_VERSION=24 \
                -v $(pwd):/vscode \
                -v $(pwd)/container/android:/vscode-build \
                -v $(pwd)/node:/vscode-node \
                -v $(pwd)/.git/modules/code-server:/.git/modules/code-server \
                vsandroidenv:latest bash; exit $?
        ;;
    esac
}

main "$@"

