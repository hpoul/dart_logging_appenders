#!/bin/bash

set -xeu

cd "${0%/*}"/..


dart pub get
dart pub global activate coverage

fail=false
dart test --coverage coverage || fail=true
echo "fail=$fail"

jq -s '{coverage: [.[].coverage] | flatten}' $(find coverage -name '*.json' | xargs) > coverage/merged_json.cov

dart pub global run coverage:format_coverage -i coverage/merged_json.cov -l --report-on lib --report-on test > coverage/lcov.info

bash <(curl -s https://codecov.io/bash) -f coverage/lcov.info

test "$fail" == "true" && exit 1

echo "Success 🎉️"

exit 0