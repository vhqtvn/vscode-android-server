SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

latest_version_deb_of_package() {
    echo "Find latest version of $1 for $TERMUX_ARCH" >&2
    curl -k "https://vsc.vhn.vn/termux-packages-24/dists/stable/main/binary-$TERMUX_ARCH/Packages" |
        grep Filename |
        grep "/${1}_" |
        awk '{print $2}' |
        python3 $SCRIPT_DIR/extract-latest-version.py "$1"
}
