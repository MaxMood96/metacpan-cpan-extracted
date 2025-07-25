#!/usr/bin/env bash

ROOT=$(cd "$(dirname "$0")/../" && pwd)

if [[ $# -eq 0 ]]; then
    $0 5.40.2 5-40 x86_64
    $0 5.40.2 5-40 arm64
    $0 5.38.4 5-38 x86_64
    $0 5.38.4 5-38 arm64
    exit 0
fi

PERL_VERSION=$1
TAG=$2
PLATFORM=$3

OPT="$ROOT/.perl-layer/$PERL_VERSION-paws.al2023"
DIST="$ROOT/.perl-layer/dist"
set -uex

# sanity check of required tools
command -v parallel # GNU parallel

# clean up
rm -rf "$OPT-$PLATFORM"
mkdir -p "$OPT-$PLATFORM/lib/perl5/site_perl"
rm -f "$DIST/perl-$TAG-paws-al2023-$PLATFORM.zip"

DOCKER_PLATFORM=linux/unknown
case $PLATFORM in
    "x86_64") DOCKER_PLATFORM=linux/amd64;;
    "arm64") DOCKER_PLATFORM=linux/arm64;;
    *) echo "unknown platform: $PLATFORM";
    exit 1;;
esac

docker run \
    -v "$ROOT:/var/task" \
    -v "$OPT-$PLATFORM/lib/perl5/site_perl:/opt/lib/perl5/site_perl" \
    -v "$OPT-$PLATFORM/lib:/opt-lib" \
    --platform "$DOCKER_PLATFORM" \
    "public.ecr.aws/sam/build-provided.al2023:1-$PLATFORM" \
    ./author/build-paws-al2023.sh "$TAG"

find "$OPT-$PLATFORM" -type f -a -name '*.pm' -print0 | parallel -0 -j 32 "$ROOT/author/perlstrip.sh"

cd "$OPT-$PLATFORM"
mkdir -p "$DIST"
zip -9 -r "$DIST/perl-$TAG-paws-al2023-$PLATFORM.zip" .
