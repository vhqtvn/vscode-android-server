#!/usr/bin/env bash

main() {
  cd "$(dirname "$0")/"

    case "$1" in
      diff)
        cd code-server/lib
        diff -x node_modules -x build -x .build -x 'out-*' -x out -ru vscode.orig vscode > vscode.vh.patch
        ;;
      build-android-env)
        docker build ./container/android -t vsandroidenv:latest
        ;;
      *)
        docker run --rm -it -v $(pwd):/vscode vsandroidenv:latest bash
        ;;
    esac
}

main "$@"

