#!/bin/sh

# This script installs the Nix package manager on your system by
# downloading a binary distribution and running its installer script
# (which in turn creates and populates /nix).

{ # Prevent execution if this script was only partially downloaded
oops() {
    echo "$0:" "$@" >&2
    exit 1
}

umask 0022

tmpDir="$(mktemp -d -t nix-binary-tarball-unpack.XXXXXXXXXX || \
          oops "Can't create temporary directory for downloading the Nix binary tarball")"
cleanup() {
    rm -rf "$tmpDir"
}
trap cleanup EXIT INT QUIT TERM

require_util() {
    command -v "$1" > /dev/null 2>&1 ||
        oops "you do not have '$1' installed, which I need to $2"
}

case "$(uname -s).$(uname -m)" in
    Linux.x86_64)
        hash=29d5d29a3db0f71c367102b71e0940190a980a1297b370d62e50c11807bb39eb
        path=3hhmgz6q8di3x9h1nwqjary513ahi425/nix-2.6.1-x86_64-linux.tar.xz
        system=x86_64-linux
        ;;
    Linux.i?86)
        hash=ae464e9e5a51a01e8efb101b31851820750624b5326fdd63515ae86f995a491e
        path=pz8gjmga24wszzxvicslwcdq160qdbms/nix-2.6.1-i686-linux.tar.xz
        system=i686-linux
        ;;
    Linux.aarch64)
        hash=4501724b81cb83a1183cca4412f838b46a2d77f9c07955206960ebcc2582a404
        path=ljnykib3aad681db1divlcbsjfsxiiyh/nix-2.6.1-aarch64-linux.tar.xz
        system=aarch64-linux
        ;;
    Linux.armv6l_linux)
        hash=ada524c2ce1d474a1cf36c5ca684f524c3d0718a7cfd98d6687b2eb3dc3d8890
        path=sgw87q8gi10nf0w1x8mh3k4zm4nhq61b/nix-2.6.1-armv6l-linux.tar.xz
        system=armv6l-linux
        ;;
    Linux.armv7l_linux)
        hash=02ee0e64da5d9d508786605b6bf9bdb72b9a4971e95c00fcb8258eec0eaec481
        path=ka1498v1gzv2sbk23cz5ilynxwrd88gs/nix-2.6.1-armv7l-linux.tar.xz
        system=armv7l-linux
        ;;
    Darwin.x86_64)
        hash=d3585b4a2f330db7b4cef500898280f7c10a5f19b9cf93fe04549c7ff79bc0b7
        path=ika4d9l1nmr9s1sq5c8fsjybphz5hadf/nix-2.6.1-x86_64-darwin.tar.xz
        system=x86_64-darwin
        ;;
    Darwin.arm64|Darwin.aarch64)
        hash=147b8262f19ac98f3d78c9e23bbad4edf920f173b2ab5dd8bf7281c22391adbb
        path=fydplmrw6djxdkdg3dsc3x208sxkvf8q/nix-2.6.1-aarch64-darwin.tar.xz
        system=aarch64-darwin
        ;;
    *) oops "sorry, there is no binary distribution of Nix for your platform";;
esac

# Use this command-line option to fetch the tarballs using nar-serve or Cachix
if [ "${1:-}" = "--tarball-url-prefix" ]; then
    if [ -z "${2:-}" ]; then
        oops "missing argument for --tarball-url-prefix"
    fi
    url=${2}/${path}
    shift 2
else
    url=https://releases.nixos.org/nix/nix-2.6.1/nix-2.6.1-$system.tar.xz
fi

tarball=$tmpDir/nix-2.6.1-$system.tar.xz

require_util tar "unpack the binary tarball"
if [ "$(uname -s)" != "Darwin" ]; then
    require_util xz "unpack the binary tarball"
fi

if command -v curl > /dev/null 2>&1; then
    fetch() { curl -L "$1" -o "$2"; }
elif command -v wget > /dev/null 2>&1; then
    fetch() { wget "$1" -O "$2"; }
else
    oops "you don't have wget or curl installed, which I need to download the binary tarball"
fi

echo "downloading Nix 2.6.1 binary tarball for $system from '$url' to '$tmpDir'..."
fetch "$url" "$tarball" || oops "failed to download '$url'"

if command -v sha256sum > /dev/null 2>&1; then
    hash2="$(sha256sum -b "$tarball" | cut -c1-64)"
elif command -v shasum > /dev/null 2>&1; then
    hash2="$(shasum -a 256 -b "$tarball" | cut -c1-64)"
elif command -v openssl > /dev/null 2>&1; then
    hash2="$(openssl dgst -r -sha256 "$tarball" | cut -c1-64)"
else
    oops "cannot verify the SHA-256 hash of '$url'; you need one of 'shasum', 'sha256sum', or 'openssl'"
fi

if [ "$hash" != "$hash2" ]; then
    oops "SHA-256 hash mismatch in '$url'; expected $hash, got $hash2"
fi

unpack=$tmpDir/unpack
mkdir -p "$unpack"
tar -xJf "$tarball" -C "$unpack" || oops "failed to unpack '$url'"

script=$(echo "$unpack"/*/install)

[ -e "$script" ] || oops "installation script is missing from the binary tarball!"
export INVOKED_FROM_INSTALL_IN=1
"$script" "$@"

} # End of wrapping
