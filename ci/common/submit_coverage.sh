#!/bin/sh
# Collect and submit coverage reports.
#
# Args:
# $1: Flag(s) for codecov, separated by comma.

set -ex

# Change to grandparent dir (POSIXly).
CDPATH='' cd -P -- "$(dirname -- "$0")/../.." || exit

echo "=== running submit_coverage in $PWD: $* ==="
"$GCOV" --version

# Download/install codecov-bash and gcovr once.
codecov_sh="${TEMP:-/tmp}/codecov.bash"
if ! [ -f "$codecov_sh" ]; then
  curl --retry 5 --silent --fail -o "$codecov_sh" https://codecov.io/bash
  chmod +x "$codecov_sh"

  python -m pip install --quiet --user gcovr
fi

(
  cd build
  python -m gcovr --branches --exclude-unreachable-branches --print-summary -j 2 --exclude '.*/auto/.*' --root .. --delete -o ../coverage.xml --xml
)

# Upload to codecov.
# -X gcov: disable gcov, done manually above.
# -X fix: disable fixing of reports (not necessary, rather slow)
# -Z: exit non-zero on failure
# -F: flag(s)
# NOTE: ignoring flags for now, since this causes timeouts on codecov.io then,
#       which they know about for about a year already...
# Flags must match pattern ^[\w\,]+$ ("," as separator).
codecov_flags="$(uname -s),${1}"
codecov_flags=$(echo "$codecov_flags" | sed 's/[^,_a-zA-Z0-9]/_/g')
if ! "$codecov_sh" -f coverage.xml -X gcov -X fix -Z -F "${codecov_flags}"; then
  echo "codecov upload failed."
fi

# Cleanup always, especially collected data.
find . \( -name '*.gcov' -o -name '*.gcda' \) -ls -delete | wc -l
rm -f coverage.xml

# Upload Lua coverage  (generated manually on AppVeyor/Windows).
if [ "$USE_LUACOV" = 1 ] && [ "$1" != "oldtest" ]; then
  if [ -x "${DEPS_BUILD_DIR}/usr/bin/luacov" ]; then
    "${DEPS_BUILD_DIR}/usr/bin/luacov"
  fi
  if ! "$codecov_sh" -f luacov.report.out -X gcov -X fix -Z -F "lua,${codecov_flags}"; then
    echo "codecov upload failed."
  fi
  rm luacov.stats.out
fi
