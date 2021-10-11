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
        diff -x node_modules -x build -x .build -x 'out-*' -x out -ru vscode.orig vscode > ../../vscode.vh.patch
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
        echo $ANDROID_ARCH > current_building
        gcc -shared -fPIC /vscode-build/lib/node-preload.c -o /vscode-build/lib/node-preload.so -ldl 
        case $ANDROID_ARCH in
          arm|armeabi-v7a)
            ARCH_NAME="armeabi-v7a"
            NODE_CONFIGURE_NAME="arm"
            TERMUX_ARCH="arm"
          ;;
          x86)
            ARCH_NAME="x86"
            NODE_CONFIGURE_NAME="x86"
            TERMUX_ARCH="i686"
          ;;
          x86_64)
            ARCH_NAME="x86_64"
            NODE_CONFIGURE_NAME="x86_64"
            TERMUX_ARCH="x86_64"
            ;;
          arm64|aarch64)
            ARCH_NAME="arm64-v8a"
            NODE_CONFIGURE_NAME="arm64"
            TERMUX_ARCH="aarch64"
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
          if [[ "$ANDROID_ARCH" == "x86_64" ]]; then
            git checkout HEAD -- ./deps/v8/src/api/api.cc
            mv ./deps/v8/src/api/api.cc ./deps/v8/src/api/api.cc.orig
            cat ./deps/v8/src/api/api.cc.orig | sed 's/#if V8_TARGET_ARCH_X64 && !V8_OS_ANDROID/#if true\nreturn false;\n#elif false/g' > ./deps/v8/src/api/api.cc
            git checkout HEAD -- ./deps/v8/src/trap-handler/trap-handler.h
            mv ./deps/v8/src/trap-handler/trap-handler.h ./deps/v8/src/trap-handler/trap-handler.h.orig
            cat ./deps/v8/src/trap-handler/trap-handler.h.orig | sed 's/define V8_TRAP_HANDLER_SUPPORTED true/define V8_TRAP_HANDLER_SUPPORTED false/g' > ./deps/v8/src/trap-handler/trap-handler.h
          fi
          PATH=/vscode-build/hostbin:$PATH CC_host=gcc CXX_host=g++ LINK_host=g++ ./android-configure /opt/android-ndk/ $NODE_CONFIGURE_NAME $ANDROID_BUILD_API_VERSION
          PATH=/vscode-build/hostbin:$PATH JOBS=$(nproc) make -j $(nproc)
          if [[ -f "deps/v8/src/api/api.cc.orig" ]]; then
            mv -f ./deps/v8/src/api/api.cc.orig ./deps/v8/src/api/api.cc
          fi
          if [[ -f "deps/v8/src/trap-handler/trap-handler.h.orig" ]]; then
            mv -f ./deps/v8/src/trap-handler/trap-handler.h.orig ./deps/v8/src/trap-handler/trap-handler.h
          fi
          cd ..
        fi
        for f in /usr/lib/node_modules/npm/bin/node-gyp-bin/node-gyp; do
          if [ ! -f "$f.orig" ]; then
            mv $f "$f.orig"
          fi
          echo -e '#!/bin/bash\n/vscode-build/bin/node-gyp-hook $0 $@\n'$f'.orig --nodedir /vscode/node-src/ "$@"' > $f
          chmod +x $f
        done
        for f in /usr/bin/node; do
          if [ ! -f "$f.orig" ]; then
            mv $f "$f.orig"
          fi
          echo -e '#!/bin/bash\n/vscode-build/bin/node-hook '$f'.orig "$@"' > $f
          chmod +x $f
        done
        if [ ! -z "$BUILD_RELEASE" ]; then
          pushd code-server
            rm -rf release release-standalone node_modules
            CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH yarn
            find . -iname yarn.lock | grep -v node_modules | while IPS= read -l dir
            do
              echo "$dir"
              pushd "$(basename "$dir")"
                CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH yarn
                [[ "$(jq ".scripts.build" code-server/package.json )" != "null" ]] && CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH yarn build
                [[ "$(jq ".scripts.release" code-server/package.json )" != "null" ]] && CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH yarn release
                [[ "$(jq ".scripts[\"release:standalone\"]" code-server/package.json )" != "null" ]] && CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH yarn release:standalone
                CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH yarn --production --frozen-lockfile
              popd
            done
            CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH yarn build
            CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH yarn build:vscode
            CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH yarn release
            #nonexisten proxy to disable downloading
            CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH yarn release:standalone
            cd release-standalone
            CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH yarn --production --frozen-lockfile
          popd
        fi
        rm -rf cs-$ANDROID_ARCH.tgz libc++_shared.so node
        cp node-src/out/Release/node ./
        cp /opt/android-ndk/sources/cxx-stl/llvm-libc++/libs/$ARCH_NAME/libc++_shared.so ./libc++_shared.so
      	cat code-server/package.json | jq -r '.version' > code-server/VERSION
        ANDROID_ARCH=$ANDROID_ARCH TERMUX_ARCH=$TERMUX_ARCH bash ./scripts/download-rg.sh
        cp rg/$ANDROID_ARCH/rg code-server/release-standalone/vendor/modules/code-oss-dev/node_modules/vscode-ripgrep/bin/rg
        echo md5 code-server/release-standalone/lib/vscode/node_modules/vscode-ripgrep/bin/rg
        if [[ "$(find code-server/release-standalone -iname '*.orig')" != "" ]]; then
          find code-server/release-standalone -iname '*.orig'
          exit -1
        fi
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

