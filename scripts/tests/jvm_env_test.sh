#!/usr/bin/env bash
# Proxy credentials must not land in JAVA_TOOL_OPTIONS (printed by every JVM) and must be stored 0600.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/jvmenv.XXXXXX")"; trap 'rm -rf "$SANDBOX"' EXIT
mkdir -p "$SANDBOX/scripts/bin"; cp "$ROOT/scripts/bin/_jvm-env.sh" "$SANDBOX/scripts/bin/" 2>/dev/null || { echo "FAIL: scripts/bin/_jvm-env.sh missing"; exit 1; }
fail=0
out="$(cd "$SANDBOX" && HTTPS_PROXY='http://user:s3cr%40t@localhost:3128' JAVA_HOME=/x ROOT="$SANDBOX" bash -c '. scripts/bin/_jvm-env.sh; printf "%s" "$JAVA_TOOL_OPTIONS"')"
case "$out" in *s3cr*|*proxyPassword*) echo "FAIL: password in JAVA_TOOL_OPTIONS: $out"; fail=1;; esac
case "$out" in *proxyHost=127.0.0.1*proxyPort=3128*) ;; *) echo "FAIL: proxy host/port missing: $out"; fail=1;; esac
P="$SANDBOX/.home/.gradle/gradle.properties"
[ -f "$P" ] || { echo "FAIL: $P not written"; exit 1; }
/usr/bin/grep -q '^systemProp.https.proxyPassword=s3cr@t$' "$P" || { echo "FAIL: decoded password not in gradle.properties"; fail=1; }
perm="$(stat -f %Lp "$P" 2>/dev/null || stat -c %a "$P")"
[ "$perm" = 600 ] || { echo "FAIL: gradle.properties mode $perm, want 600"; fail=1; }
[ $fail -eq 0 ] && echo "PASS: jvm_env_test"
exit $fail
