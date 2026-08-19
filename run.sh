#!/bin/bash
cd "$(dirname "$0")"

OS_NAME="$(uname -s)"
case "$OS_NAME" in
    Darwin*)
        TARGET="macos"
        ;;
    Linux*)
        TARGET="linux"
        ;;
    *)
        TARGET="linux"
        ;;
esac

flutter run -d "$TARGET"
