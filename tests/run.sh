#!/usr/bin/env bash
# Runs the Pure image against the fixtures. Usage: tests/run.sh [image]  (uses <image>:7.4 and <image>:8.5)
set -uo pipefail
image=${1:-pure}
fixtures=$(cd "$(dirname "$0")/fixtures" && pwd)
fails=0

# repo <fixture>: copies a fixture into a fresh git repo, prints its path.
repo() {
  local dir; dir=$(mktemp -d)
  cp -r "$fixtures/$1/." "$dir"
  git -C "$dir" init -q
  git -C "$dir" add .
  git -C "$dir" -c user.name=t -c user.email=t@t commit -qm init
  echo "$dir"
}

# expect <exit code> <text in output> <description> <dir> <tag> [docker args...]
expect() {
  local want=$1 text=$2 desc=$3 dir=$4 tag=$5; shift 5
  local out got
  out=$(docker run --rm -v "$dir:/app" "$@" "$image:$tag" pure 2>&1); got=$?
  if [ "$got" = "$want" ] && [[ "$out" == *"$text"* ]]; then
    echo "ok   $desc"
  else
    echo "FAIL $desc (exit $got, want $want; expected output to contain: $text)"
    echo "$out" | sed 's/^/     /'
    fails=$((fails + 1))
  fi
}

good=$(repo good); bad=$(repo bad); php8=$(repo php8)

expect 0 "Static analysis (PHPStan) | ✅" "clean code passes"                   "$good" 7.4
expect 1 "Syntax (PHP 7.4) | ❌"          "syntax error fails the build"        "$bad"  7.4
expect 1 "Static analysis (PHPStan) | ❌" "undefined variable fails the build"  "$bad"  7.4
expect 1 "::error"                        "github format emits annotations"     "$bad"  7.4 -e PURE_FORMAT=github
expect 1 "Syntax (PHP 7.4) | ❌"          "PHP 8 syntax fails on the 7.4 image" "$php8" 7.4
expect 0 "Syntax (PHP 8.5) | ✅"          "PHP 8 syntax passes on the 8.5 image" "$php8" 8.5

# Only the changed file is checked, yet PHPStan still finds the class defined in an unchanged file.
git -C "$good" rm -q --cached app.php
git -C "$good" -c user.name=t -c user.email=t@t commit -qm "without app"
git -C "$good" add app.php
git -C "$good" -c user.name=t -c user.email=t@t commit -qm "add app"
expect 0 "1 PHP files checked" "PR mode checks only changed files" "$good" 7.4 -e PURE_BASE=HEAD~1

expect 2 "cannot diff" "a bad base ref fails instead of passing" "$good" 7.4 -e PURE_BASE=nope

rm -rf "$good" "$bad" "$php8"
[ "$fails" = 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
