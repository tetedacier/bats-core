#!/usr/bin/env bats
#
# This suite is dedicated to calculating BATS_ROOT when going through various
# permutations of symlinks. It was inspired by the report in issue #113 that the
# calculation was broken on CentOS, where /bin is symlinked to /usr/bin.
#
# The basic test environment is (all paths relative to BATS_TEST_SUITE_TMPDIR):
#
# - /bin is a relative symlink to /usr/bin, exercising the symlink resolution of
#   the `bats` parent directory (i.e. "${0%/*}")
# - /usr/bin/bats is an absolute symlink to /opt/bats-core/bin/bats, exercising
#   the symlink resolution of the `bats` executable itself (i.e. "${0##*/}")

load test_helper

# This would make a good candidate for a one-time setup/teardown per #39.
setup() {
  make_bats_test_suite_tmpdir
  cd "$BATS_TEST_SUITE_TMPDIR"
  mkdir -p {usr/bin,opt/bats-core}
  "$BATS_ROOT/install.sh" "opt/bats-core"

  ln -s "usr/bin" "bin"

  if [[ ! -L "bin" ]]; then
    cd - >/dev/null
    skip "symbolic links aren't functional on OSTYPE=$OSTYPE"
  fi

  ln -s "$BATS_TEST_SUITE_TMPDIR/opt/bats-core/bin/bats" \
    "$BATS_TEST_SUITE_TMPDIR/usr/bin/bats"
  cd - >/dev/null
}

@test "#113: set BATS_ROOT when /bin is a symlink to /usr/bin" {
  run "$BATS_TEST_SUITE_TMPDIR/bin/bats" -v
  [ "$status" -eq 0 ]
  [ "${output%% *}" == 'Bats' ]
}

# The resolution scheme here is:
#
# Set in setup
# - /bin => /usr/bin (relative directory)
@test "set BATS_ROOT with extreme symlink resolution" {
  cd "$BATS_TEST_SUITE_TMPDIR"
  mkdir -p "opt/bats/bin2"

# - /usr/bin/foo => /usr/bin/bar (relative executable)
  ln -s bar usr/bin/foo
# - /usr/bin/bar => /opt/bats/bin0/bar (absolute executable)
  ln -s "$BATS_TEST_SUITE_TMPDIR/opt/bats/bin0/bar" usr/bin/bar
# - /opt/bats/bin0 => /opt/bats/bin1 (relative directory)
  ln -s bin1 opt/bats/bin0
# - /opt/bats/bin1 => /opt/bats/bin2 (absolute directory)
  ln -s "$BATS_TEST_SUITE_TMPDIR/opt/bats/bin2" opt/bats/bin1
# - /opt/bats/bin2/bar => /opt/bats-core/bin/bar (absolute executable)
  ln -s "$BATS_TEST_SUITE_TMPDIR/opt/bats-core/bin/bar" opt/bats/bin2/bar
# - /opt/bats-core/bin/bar => /opt/bats-core/bin/baz (relative executable)
  ln -s baz opt/bats-core/bin/bar
# - /opt/bats-core/bin/baz => /opt/bats-core/bin/bats (relative executable)
  ln -s bats opt/bats-core/bin/baz

  cd - >/dev/null
  run "$BATS_TEST_SUITE_TMPDIR/bin/foo" -v
  [ "$status" -eq 0 ]
  [ "${output%% *}" == 'Bats' ]
}

@test "set BATS_ROOT when calling from same dir" {
  cd "$BATS_TEST_SUITE_TMPDIR"
  run ./bin/bats -v
  [ "$status" -eq 0 ]
  [ "${output%% *}" == 'Bats' ]
}

@test "set BATS_ROOT from PATH" {
  cd /tmp
  PATH="$PATH:$BATS_TEST_SUITE_TMPDIR/bin"
  run bats -v
  [ "$status" -eq 0 ]
  [ "${output%% *}" == 'Bats' ]
}

@test "#182 and probably #184 as well" {
  cd /tmp
  PATH="$PATH:$BATS_TEST_SUITE_TMPDIR/bin"
  run bash bats -v
  [ "$status" -eq 0 ]
  [ "${output%% *}" == 'Bats' ]
}
