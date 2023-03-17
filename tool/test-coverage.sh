#!/bin/bash

set -xeu

cd "${0%/*}"/..


dart pub get
dart pub global activate test_coverage

fail=false
dart pub global run test_coverage --port 38274 || fail=true
echo "fail=$fail"
bash <(curl -s https://codecov.io/bash) -f coverage/lcov.info

test "$fail" == "true" && exit 1

echo "Success 🎉️"

exit 0