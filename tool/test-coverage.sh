#!/bin/bash

set -xeu

cd "${0%/*}"/..


flutter pub get

fail=false
flutter test --coverage || fail=true
echo "fail=$fail"
bash <(curl -s https://codecov.io/bash) -f coverage/lcov.info
