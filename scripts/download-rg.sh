echo "Download RG for ANDROID_ARCH=$ANDROID_ARCH TERMUX_ARCH=$TERMUX_ARCH"
mkdir -p rg
rm -rf rg/$ANDROID_ARCH || true
mkdir -p rg/$ANDROID_ARCH
deb_uri=
curl -k "https://vsc.vhn.vn/termux-packages-24/dists/stable/main/binary-$TERMUX_ARCH/Packages" \
    | grep Filename \
    | grep '/ripgrep_' \
    | awk '{print $2}'
curl -k "https://vsc.vhn.vn/termux-packages-24/dists/stable/main/binary-$TERMUX_ARCH/Packages" \
    | grep Filename \
    | grep '/ripgrep_' \
    | awk '{print $2}' \
    | {
        set -e
        read deb_uri;
        if [ -z "$deb_uri" ]; then
            echo "Cant find rg from termux"
            exit -1
        fi
        pushd rg/$ANDROID_ARCH
            wget --no-check-certificate https://vsc.vhn.vn/termux-packages-24/$deb_uri -O rg.deb
            ar x rg.deb data.tar.xz
            tar xf data.tar.xz
            mv data/data/vn.vhn.vsc/files/usr/bin/rg rg
            rm -rf data
        popd
    }
