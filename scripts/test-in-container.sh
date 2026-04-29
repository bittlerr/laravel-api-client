#!/usr/bin/env bash
#
# Run the test suite in a Docker container against a specific Laravel version.
#
# Usage:
#   scripts/test-in-container.sh [laravel-major]   # default: 11
#
# Env:
#   OAUTH2_PATH          Absolute path to the sibling laravel-oauth2-client fork
#                        (defaults to ../laravel-oauth2-client).
#   COMPOSER_IMAGE       Docker image to use (default: composer:2.8).
#
# The script copies this package + the sibling oauth2 fork to a scratch dir
# and wires a composer path repository so the fork resolves locally without
# going through packagist/git. The source tree is not mutated.

set -euo pipefail

LARAVEL="${1:-11}"
if [[ $# -gt 0 ]]; then shift; fi
COMPOSER_IMAGE="${COMPOSER_IMAGE:-composer:2.8}"

case "$LARAVEL" in
    11) TESTBENCH="^9.0";  PHPUNIT="^11.5" ;;
    12) TESTBENCH="^10.0"; PHPUNIT="^11.5" ;;
    13) TESTBENCH="^11.0"; PHPUNIT="^11.5" ;;
    *)  echo "Unsupported Laravel major: $LARAVEL (supported: 11, 12, 13)" >&2; exit 2 ;;
esac

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OAUTH2_PATH="${OAUTH2_PATH:-$(cd "$PROJECT_ROOT/../laravel-oauth2-client" 2>/dev/null && pwd || true)}"

if [[ -z "${OAUTH2_PATH}" || ! -d "${OAUTH2_PATH}" ]]; then
    echo "laravel-oauth2-client fork not found." >&2
    echo "Set OAUTH2_PATH or clone it to \$(dirname '$PROJECT_ROOT')/laravel-oauth2-client." >&2
    exit 3
fi

WORK_DIR="$(mktemp -d -t laravel-api-client-test.XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo ">> Staging working copy in $WORK_DIR (Laravel $LARAVEL)"
cp -r "$PROJECT_ROOT" "$WORK_DIR/api-client"
cp -r "$OAUTH2_PATH"  "$WORK_DIR/oauth2-client"
rm -rf "$WORK_DIR/api-client/vendor" "$WORK_DIR/api-client/composer.lock"

echo ">> Rewriting composer repositories to use local path for oauth2 fork"
docker run --rm \
    -v "$WORK_DIR:/work" -w /work/api-client \
    -u "$(id -u):$(id -g)" \
    -e COMPOSER_HOME=/tmp/composer-cache -e COMPOSER_ALLOW_SUPERUSER=1 \
    "$COMPOSER_IMAGE" \
    config repositories.oauth2-path '{"type":"path","url":"../oauth2-client","options":{"symlink":false}}'

docker run --rm \
    -v "$WORK_DIR:/work" -w /work/api-client \
    -u "$(id -u):$(id -g)" \
    -e COMPOSER_HOME=/tmp/composer-cache -e COMPOSER_ALLOW_SUPERUSER=1 \
    "$COMPOSER_IMAGE" \
    config minimum-stability dev

docker run --rm \
    -v "$WORK_DIR:/work" -w /work/api-client \
    -u "$(id -u):$(id -g)" \
    -e COMPOSER_HOME=/tmp/composer-cache -e COMPOSER_ALLOW_SUPERUSER=1 \
    "$COMPOSER_IMAGE" \
    config prefer-stable true

echo ">> Pinning framework to ^$LARAVEL.0 / testbench $TESTBENCH / phpunit $PHPUNIT"
docker run --rm \
    -v "$WORK_DIR:/work" -w /work/api-client \
    -u "$(id -u):$(id -g)" \
    -e COMPOSER_HOME=/tmp/composer-cache -e COMPOSER_ALLOW_SUPERUSER=1 \
    "$COMPOSER_IMAGE" \
    require --dev --no-interaction --no-update \
        "laravel/framework:^${LARAVEL}.0" \
        "orchestra/testbench:${TESTBENCH}" \
        "phpunit/phpunit:${PHPUNIT}"

echo ">> composer update"
docker run --rm \
    -v "$WORK_DIR:/work" -w /work/api-client \
    -u "$(id -u):$(id -g)" \
    -e COMPOSER_HOME=/tmp/composer-cache -e COMPOSER_ALLOW_SUPERUSER=1 \
    "$COMPOSER_IMAGE" \
    update --prefer-stable --prefer-dist --no-interaction

echo ">> Running PHPUnit"
docker run --rm \
    -v "$WORK_DIR:/work" -w /work/api-client \
    -u "$(id -u):$(id -g)" \
    --entrypoint php \
    "$COMPOSER_IMAGE" \
    vendor/bin/phpunit "$@"
