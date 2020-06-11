# Create vscode.orig
```
git submodule init
git submodule update --recursive
cd code-server && yarn vscode:patch
cp -r code-server/lib/vscode code-server/lib/vscode.orig
```
# Apply patches
```
cd code-server && yarn vscode:patch #apply code-server patches
cd .. && ./dev.sh apply-patch #apply android patches
```
# Build node
Comment out gcc version check
```
# if [ -z $major ] || [ -z $minor ] || [ $major -lt 6 ] || [ $major -eq 6 -a $minor -lt 3 ]; then
#   echo "host gcc $host_gcc_version is too old, need gcc 6.3.0"
#   exit 1
# fi
```

```
-        TOOLCHAIN_NAME="armv7-linux-androideabi"
+        TOOLCHAIN_NAME="armv7a-linux-androideabi"
```

./configure.py:
```py
  o['variables']['want_separate_host_toolset'] = int(
-      cross_compiling and want_snapshots)
+      cross_compiling)
```

Run configure:
```
PATH=/vscode-build/hostbin:$PATH ./android-configure /opt/android-ndk/ $ANDROID_ARCH $ANDROID_BUILD_API_VERSION
JOBS=10 make -j 10 # lol... just for sure
```

# Build lib/vscode

```
CC_target=cc AR_target=ar CXX_target=cxx LINK_target=ld PATH=/vscode-build/bin:$PATH yarn
```

```
yarn release && yarn release:static
```

# Rebuild all

```
BUILD_NODE=1 BUILD_RELEASE=1 ANDROID_ARCH=aarch64 ./dev.sh release
BUILD_NODE=1 BUILD_RELEASE=1 ANDROID_ARCH=arm ./dev.sh release
BUILD_NODE=1 BUILD_RELEASE=1 ANDROID_ARCH=x86_64 ./dev.sh release
```
