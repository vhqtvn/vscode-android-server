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

def extract_version(deb_path, package_prefix):
  """
  Extracts the version number from a deb file path.

  Args:
    deb_path: The path to the deb file.
    package_prefix: The prefix of the package name.

  Returns:
    A tuple containing the version number as a string and the deb path.
  """
  pattern = rf"{package_prefix}_([^_]+)_arm\.deb"
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

if __name__ == '__main__':
  main()
