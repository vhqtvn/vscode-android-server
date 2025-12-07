#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

codeserver_remove_unuseful_node_module() {
  local dir="$1"
  local name="$2"
  [ -z "$dir" ] || [ -z "$name" ] && { echo "usage: codeserver_remove_unuseful_node_module <dir> <pkg>"; return 2; }

  # --- package.json ---
  if [[ -f "$dir/package.json" ]]; then
    tmp="$(mktemp)"
    if jq --arg pkg "$name" '
        ( .dependencies      // {} ) as $d
      | ( .devDependencies  // {} ) as $dd
      | .dependencies     = ($d  | del(.[$pkg]))
      | .devDependencies  = ($dd | del(.[$pkg]))
    ' "$dir/package.json" > "$tmp"; then
      chown "$(stat -c '%u:%g' "$dir/package.json")" "$tmp"
      mv "$tmp" "$dir/package.json"
    else
      rm -f "$tmp"; echo "jq failed to edit package.json" >&2; return 1
    fi
  fi

  # --- package-lock.json (supports lockfileVersion 1/2/3) ---
  if [[ -f "$dir/package-lock.json" ]]; then
    tmp="$(mktemp)"
    # node_modules path inside packages map (v2/v3); works for scoped names too
    local nm_path="node_modules/$name"

    if jq --arg pkg "$name" --arg nm "$nm_path" '
      # Remove from top-level dependencies map (v1/v2/v3)
      (if .dependencies? then .dependencies |= with_entries(select(.key != $pkg)) else . end)
      # Remove package entry from packages map (v2/v3)
      | (if .packages? then .packages |= (with_entries(
            if .key == $nm then empty else
              (.value |= ( if .dependencies? then .dependencies |= with_entries(select(.key != $pkg)) else . end ))
            end))
         else . end)
      # Also clean any direct child in .packages[""] (root) deps (v2/v3)
      | (if .packages? and (.packages[""]? // null) then
           .packages[""] |= ( if .dependencies? then .dependencies |= with_entries(select(.key != $pkg)) else . end )
         else . end)
    ' "$dir/package-lock.json" > "$tmp"; then
      chown "$(stat -c '%u:%g' "$dir/package-lock.json")" "$tmp"
      mv "$tmp" "$dir/package-lock.json"
    else
      rm -f "$tmp"; echo "jq failed to edit package-lock.json" >&2; return 1
    fi
  fi

  if [[ -d "$dir/node_modules/$name" ]]; then
    rm -rf -- "$dir/node_modules/$name"
  fi
}

codeserver_remove_unuseful_node_modules() {
  codeserver_remove_unuseful_node_module $1 kerberos
}

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
        rm -rf .pc;QUILT_PATCHES=patches/code-server quilt push -a
        rm -rf .pc;QUILT_PATCHES=patches/node-src quilt push -a
        ;;
      build-android-env)
        docker build ./container/android -t vsandroidenv:latest
        ;;
      release)
        if [ "$EUID" -ne 0 ]; then
          USERRUN=
        else
          BUILDING_USER=$(ls -n /vscode/dev.sh | awk '{print $3}')
          BUILDING_GROUP=$(ls -n /vscode/dev.sh | awk '{print $4}')
          if ! grep -q code-builder /etc/passwd; then
            groupadd -g $BUILDING_GROUP builder-gr
            useradd -m -g $BUILDING_GROUP -u $BUILDING_USER -N code-builder 
          fi
          USERRUN="sudo -E -H -u #$BUILDING_USER"
        fi
        set -x

        echo $ANDROID_ARCH > current_building
        gcc -shared -fPIC /vscode-build/lib/node-preload.c -o /vscode-build/lib/node-preload.so -ldl 
        chmod 0744 /vscode-build/lib/node-preload.so
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
          pushd node-src
          make clean
          git clean -dfx
          git checkout -f HEAD
          (cd ..; rm -rf .pc; QUILT_PATCHES=patches/node-src quilt push -a -f)
          sed -i "s|<(android_ndk_path)|$NDK|g" common.gypi
          $USERRUN PATH=/vscode-build/hostbin:$PATH CC_host=gcc CXX_host=g++ LINK_host=g++ ./android-configure /opt/android-ndk/ $ANDROID_BUILD_API_VERSION $NODE_CONFIGURE_NAME
          NODE_MAKE_CUSTOM_LDFLAGS=
          if [[ "$ANDROID_ARCH" == "x86" ]]; then
            NODE_MAKE_CUSTOM_LDFLAGS="$NODE_MAKE_CUSTOM_LDFLAGS -latomic"
          fi
          LDFLAGS="$LDFLAGS $NODE_MAKE_CUSTOM_LDFLAGS" PATH=/vscode-build/hostbin:$PATH JOBS=$(nproc) make -j $(nproc)
          $USERRUN mkdir -p include/node
          $USERRUN cp config.gypi include/node/config.gypi
          popd
        fi
        for f in /usr/lib/node_modules/npm/bin/node-gyp-bin/node-gyp; do
          if [ ! -f "$f.orig" ]; then
            mv $f "$f.orig"
          fi
          echo -e '#!/bin/bash\n/vscode-build/bin/node-gyp-hook $0 $@\n'$f'.orig --nodedir /vscode/node-src/ "$@"' > $f
          chmod 0747 $f
          chmod 0747 "$f.orig"
        done
        for f in /usr/bin/node; do
          if [ ! -f "$f.orig" ]; then
            mv $f "$f.orig"
          fi
          echo -e '#!/bin/bash\n/vscode-build/bin/node-hook '$f'.orig "$@"' > $f
          chmod 0747 $f
          chmod 0747 "$f.orig"
        done
        export VERSION=$(cd code-server && git describe --tags)
        if [ ! -z "$BUILD_RELEASE" ]; then
          ./scripts/vseditor-repo.sh activate $ANDROID_ARCH
          ./scripts/vseditor-repo.sh install krb5
          VHEDITOR_REPO_ABS="$(cd $(dirname $0) && pwd)/scripts/vseditor-repo.sh"
          NPM_BIN="$USERRUN npm_config_build_from_source=true CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH $VHEDITOR_REPO_ABS env npm"
          pushd code-server
            $USERRUN git checkout -f HEAD
            git clean -dfx
            $USERRUN git submodule foreach --recursive 'git checkout -f HEAD'
            git submodule foreach --recursive 'git clean -dfx'
            quilt push -a # changes made by code-server
            (cd ..;rm -rf .pc;QUILT_PATCHES=patches/code-server quilt push -a) || true # changes made by me
            # we dont run tests but its packages are problematic, so just remove them
            rm -f test/package-lock.json test/package.json || true
            # create dummy package.json
            (cd test && echo '{"name":"test","version":"1.0.0","dependencies":{}}' > package.json && chmod 0644 package.json)
            # codeserver_remove_unuseful_node_modules lib/vscode
            # codeserver_remove_unuseful_node_modules lib/vscode/remote
            npm cache clean --force
            $USERRUN npm cache clean --force
            sub_builder() {
              find $1 -iname package-lock.json | grep -v node_modules | while IPS= read dir
              do
                if [[ "$dir" == ./test/* ]]; then
                  continue
                fi
                echo "$dir"
                pushd "$(dirname "$dir")"
                set -x
                  echo "* Work on $(pwd)"
                  $NPM_BIN ci
                  [[ "$(jq ".scripts.build" package.json )" != "null" ]] && $NPM_BIN run build
                  [[ "$(jq ".scripts.release" package.json )" != "null" ]] && $NPM_BIN run release
                  [[ "$(jq ".scripts[\"release:standalone\"]" package.json )" != "null" ]] && $NPM_BIN run release:standalone
                set +x
                popd
              done
            }
            rm -rf release release-standalone node_modules
            export NODE_PATH=/usr/lib/node_modules
            npm install -g @mapbox/node-pre-gyp node-addon-api
            $USERRUN mv -f package-lock.json.origbk package-lock.json || true
            $NPM_BIN ci
            $USERRUN mv -f package-lock.json package-lock.json.origbk || true
            sub_builder .
            $USERRUN mv -f package-lock.json package-lock.json.origbk || true
            sub_builder lib
            pushd lib/vscode
                  $NPM_BIN ci
            popd
            if [[ ! -f package-lock.json ]] && [[ -f package-lock.json.origbk ]]; then
              $USERRUN mv -f package-lock.json.origbk package-lock.json || true
            fi
            $NPM_BIN run build
            DISABLE_V8_COMPILE_CACHE=1 $NPM_BIN run build:vscode
            $NPM_BIN run release
            $NPM_BIN run release:standalone
            cd release-standalone
            $NPM_BIN ci --production
          popd
        fi
        rm -rf cs-$ANDROID_ARCH.tgz libc++_shared.so node
        cp node-src/out/Release/node ./
        case $ANDROID_ARCH in
          arm|armeabi-v7a)
            LIBCPP_ARCH_NAME="arm-linux-androideabi"
          ;;
          x86)
            LIBCPP_ARCH_NAME="i686-linux-android"
          ;;
          x86_64)
            LIBCPP_ARCH_NAME="x86_64-linux-android"
            ;;
          arm64|aarch64)
            LIBCPP_ARCH_NAME="aarch64-linux-android"
            ;;
          *)
            echo "Unsupported arch $ANDROID_ARCH"
            exit 1
            ;;
        esac
        cp /opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/$LIBCPP_ARCH_NAME/libc++_shared.so ./libc++_shared.so
        VERSION_SUFFIX=
        if [[ -f patch_version ]]; then
          VERSION_SUFFIX="-p$(cat patch_version)"
        fi
      	echo "$VERSION$VERSION_SUFFIX" | tr -d '\n' | $USERRUN tee code-server/VERSION
        $USERRUN ANDROID_ARCH=$ANDROID_ARCH TERMUX_ARCH=$TERMUX_ARCH bash ./scripts/download-rg.sh
        find code-server/release-standalone -iname rg | while IPS= read p
        do
          echo "Replace rg in $p"
          $USERRUN cp rg/$ANDROID_ARCH/rg $p
          echo md5 $p
        done
        if [[ "$(find code-server/release-standalone -iname '*.orig')" != "" ]]; then
          find code-server/release-standalone -iname '*.orig'
          exit -1
        fi
        $USERRUN tar -czvf cs-$ANDROID_ARCH.tgz code-server/release-standalone code-server/VERSION node "libc++_shared.so"
        {
          find code-server/release-standalone/ -iname '*.node' | grep -vE 'watcher/prebuilds'
          find code-server -type f -executable -print
        } | sort | uniq | xargs file | grep -vE '(ASCII|UTF-8|OpenType|TrueType|JSON)'
        ;;
      docker-run)
        shift
        set -x
        docker run --rm \
                -w /vscode \
                --memory=13g \
                --memory-swap=-1 \
                -e ANDROID_BUILD_API_VERSION=24 \
                -v $(pwd):/vscode \
                -v $(pwd)/container/android:/vscode-build \
                -v $(pwd)/node:/vscode-node \
                -v $(pwd)/.git/modules/code-server:/.git/modules/code-server \
                --entrypoint env \
                vsandroidenv:latest OKOKOKRUN=1 "$@"; exit $?
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

