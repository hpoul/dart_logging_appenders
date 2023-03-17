#!/bin/bash

set -xeu

cd "${0%/*}"/..

dart pub get
dart analyze
# shellcheck disable=SC2046
dart format -l 80 --output none --set-exit-if-changed $(find lib -name '*.dart' \! -name '*.g.dart' -print0 | xargs -0)

echo "Success"
