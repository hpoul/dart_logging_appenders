#!/bin/bash

set -xeu

cd "${0%/*}"/..

flutter pub get
flutter analyze
# shellcheck disable=SC2046
dartfmt -l 80 -w --set-exit-if-changed $(find lib -name '*.dart' \! -name '*.g.dart' -print0 | xargs -0)

echo "Success"
