#!/bin/sh
set -e
perl md2pod.pl
git commit -am "Update generated docs" || true   # -a = tracked files only; NOT -A
dzil clean
dzil build
# Score the tarball dzil just built: md2pod.pl above ran before `dzil clean`,
# so it could only see the previous release's tarball.
perl md2pod.pl --kwalitee-only
echo "==== tarball contents (verify: no .c/.o/.dll/.bs/.gcda/blib/) ===="
echo "If that looks clean, run: dzil release"
