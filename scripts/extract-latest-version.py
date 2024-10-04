#!/usr/bin/env python3
# Description: Extract the latest version deb of a package from the list of debs
# Usage: python3 extract-latest-version.py <package_prefix>
# Debs are read from stdin and the latest version deb is printed to stdout
#
# Example: python3 extract-latest-version.py krb5
# Input:
# debs/16bb2083331c057477d327bd6ccf874968de4a55/arm/krb5_1.20.1_arm.deb
# debs/364cca5a6921c86062174aa698ac4bb7f8893230/arm/krb5_1.21.2_arm.deb
# debs/4f71da0a7c89509dc05c894571dfdfe4cf97628d/arm/krb5_1.21.3_arm.deb
# debs/7ea42b8e284a903cdd2f7f8f2835a99563815b33/arm/krb5_1.21_arm.deb
# debs/8d225aac8a0dd85cba602ab528bf1922d78e01de/arm/krb5_1.20-2_arm.deb
# debs/913fa9c4e78aefac8797071644cff347ff6cee66/arm/krb5_1.20_arm.deb
# debs/91d05a1565faa7deafbe73dc3c79e35d4c0dc9b5/arm/krb5_1.19.3_arm.deb
# debs/a5b0812e862e122108ac0b411ac17466e0fb4230/all/krb5_1.19.2-2_arm.deb
# debs/b7ab6cf582d7e5dae326cc3a026342f74a97b0a6/all/krb5_1.19.1_arm.deb
# debs/d029a26eb77b4d5c4220ec3ddc906997518151cf/arm/krb5_1.20-1_arm.deb
# debs/e19bb680d00dcbdc4afe9f62972cad0de3e669f5/all/krb5_1.19.1-2_arm.deb
#
# Output:
# debs/4f71da0a7c89509dc05c894571dfdfe4cf97628d/arm/krb5_1.21.3_arm.deb

import sys
import re

def semver_split_1(version):
    if "-" in version:
        return version.split("-", 1)
    return version, ""

def semver_compare_main_part(version1, version2):
    version1_parts = version1.split(".")
    version2_parts = version2.split(".")

    for i in range(0, min(len(version1_parts), len(version2_parts))):
        if version1_parts[i] < version2_parts[i]:
            return -1
        elif version1_parts[i] > version2_parts[i]:
            return 1

    if len(version1_parts) < len(version2_parts):
        return -1
    elif len(version1_parts) > len(version2_parts):
        return 1
    return 0

def semver_compare_ext(ext1, ext2):
    if ext1 == ext2:
        return 0
    elif ext1 < ext2:
        return -1
    return 1    

def semver_compare(version1, version2):
    version1_main, version1_ext = semver_split_1(version1)
    version2_main, version2_ext = semver_split_1(version2)

    match semver_compare_main_part(version1_main, version2_main):
        case -1:
            return -1
        case 1:
            return 1
        case 0:
            return semver_compare_ext(version1_ext, version2_ext)

def extract_version(deb_path, package_prefix):
    """
    Extracts the version number from a deb file path.

    Args:
      deb_path: The path to the deb file.
      package_prefix: The prefix of the package name.

    Returns:
      A tuple containing the version number as a string and the deb path.
    """
    pattern = rf"{package_prefix}_([^_]+)_(arm|x86_64|aarch64|i686)\.deb"
    match = re.search(pattern, deb_path)
    if match:
        version = match.group(1)
        return (version, deb_path)
    return None


def main():
    """
    Reads deb file paths from stdin, extracts the latest version, and prints it to stdout.
    """
    package_prefix = sys.argv[1]
    debs = []
    for line in sys.stdin:
        deb_path = line.strip()
        version = extract_version(deb_path, package_prefix)
        if version:
            debs.append(version)

    if debs:
        latest_deb = max(debs)
        print(latest_deb[1])


if __name__ == "__main__":
    main()
