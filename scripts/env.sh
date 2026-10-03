#!/usr/bin/env bash
# Source this file before running Gradle:  source scripts/env.sh
# Uses a project-local toolchain so no system install or admin rights are required.
#
#   .android-sdk/   Android SDK (platform 34, build-tools 34.0.0, platform-tools) — see scripts/install-sdk.sh
#   .jdk/           optional project-local JDK 17 (Temurin/Zulu tar.gz extracted here)
#
# Fallback JDK: Homebrew openjdk@17 (user-owned, no sudo).

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# In a worktree made by scripts/worktree.sh the toolchain folders are symlinks to the main checkout.
# Use their real paths: CMake (native plugin builds) and Gradle break on symlinked paths.
TOOLS="$ROOT"
{ [ -L "$ROOT/.home" ] || [ -L "$ROOT/.pub-cache" ]; } && TOOLS="$(cd -P "$ROOT/.home/.." && pwd)"

if [ -x "$TOOLS/.jdk/Contents/Home/bin/java" ]; then
  export JAVA_HOME="$TOOLS/.jdk/Contents/Home"
elif [ -x "$TOOLS/.jdk/bin/java" ]; then
  export JAVA_HOME="$TOOLS/.jdk"
elif [ -d /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home ]; then
  export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
elif [ -d /opt/homebrew/opt/openjdk@23/libexec/openjdk.jdk/Contents/Home ]; then
  # Gradle 9.x (app_flutter) runs on JDK 23 too.
  export JAVA_HOME=/opt/homebrew/opt/openjdk@23/libexec/openjdk.jdk/Contents/Home
fi

export ANDROID_HOME="$TOOLS/.android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"

# Load secrets from the repo-root .env (gitignored; template: .env.example).
# A variable already set in the environment wins over .env (portable: bash and zsh).
if [ -f "$ROOT/.env" ]; then
  while IFS= read -r _l || [ -n "$_l" ]; do
    case "$_l" in ''|'#'*|*[!A-Za-z0-9_]*=*) [ -z "${_l%%[A-Za-z_]*=*}" ] || continue ;; esac
    _k="${_l%%=*}"; _v="${_l#*=}"; _v="${_v%\"}"; _v="${_v#\"}"
    case "$_k" in ''|*[!A-Za-z0-9_]*) continue ;; esac
    eval "_cur=\${$_k:-}"
    [ -n "$_cur" ] || export "$_k=$_v"
  done < "$ROOT/.env"
  unset _l _k _v _cur
fi
_write_b64() { [ -n "$1" ] && [ ! -f "$2" ] && mkdir -p "$(dirname "$2")" && printf '%s' "$1" | base64 -d > "$2" && chmod 600 "$2" || true; }
_write_b64 "${APP_GOOGLE_SERVICES_JSON_B64:-}" "$ROOT/app/google-services.json"
_write_b64 "${FLUTTER_GOOGLE_SERVICES_JSON_B64:-}" "$ROOT/app_flutter/android/app/google-services.json"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"
export PATH="$ROOT/scripts/bin:$TOOLS/.flutter/bin:$PATH"
export PUB_CACHE="$TOOLS/.pub-cache"
unset JAVA_TOOL_OPTIONS

# --- TLS: this machine sits behind a Cloudflare Zero Trust gateway that re-signs HTTPS.
# The JDK's own cacerts does not contain that CA, so Gradle/Maven downloads fail with
# "PKIX path building failed". Build a truststore = JDK cacerts + macOS keychain certs.
TS="$TOOLS/.certs/truststore.jks"
if [ ! -f "$TS" ]; then
  mkdir -p "$TOOLS/.certs"
  cp "$JAVA_HOME/lib/security/cacerts" "$TS"
  PEM="$TOOLS/.certs/keychain.pem"
  security find-certificate -a -p /Library/Keychains/System.keychain > "$PEM" 2>/dev/null
  security find-certificate -a -p "$HOME/Library/Keychains/login.keychain-db" >> "$PEM" 2>/dev/null
  ( cd "$TOOLS/.certs" && awk '/BEGIN CERT/{n++; f="kc"n".pem"} {print > f}' keychain.pem
    i=0; for c in kc*.pem; do i=$((i+1)); keytool -importcert -noprompt -trustcacerts \
      -keystore truststore.jks -storepass changeit -alias "keychain$i" -file "$c" >/dev/null 2>&1; done
    rm -f kc*.pem keychain.pem )
fi
export GRADLE_OPTS="-Djavax.net.ssl.trustStore=$TS -Djavax.net.ssl.trustStorePassword=changeit"
# The Gradle daemon does not inherit GRADLE_OPTS, so also register it for the daemon JVM:
mkdir -p "$HOME/.gradle"; touch "$HOME/.gradle/gradle.properties"
if ! grep -q 'javax.net.ssl.trustStore=' "$HOME/.gradle/gradle.properties"; then
  printf '\nsystemProp.javax.net.ssl.trustStore=%s\nsystemProp.javax.net.ssl.trustStorePassword=changeit\n' "$TS" >> "$HOME/.gradle/gradle.properties"
fi

[ -f "$ROOT/local.properties" ] || echo "sdk.dir=$ANDROID_HOME" > "$ROOT/local.properties"

echo "JAVA_HOME=$JAVA_HOME"
echo "ANDROID_HOME=$ANDROID_HOME"

# Node (npm, Firebase CLI) also needs the corporate CA
[ -f "$TOOLS/.certs/keychain.pem" ] || { security find-certificate -a -p /Library/Keychains/System.keychain > "$TOOLS/.certs/keychain.pem" 2>/dev/null; security find-certificate -a -p "$HOME/Library/Keychains/login.keychain-db" >> "$TOOLS/.certs/keychain.pem" 2>/dev/null; }
# Keep a CA the user already configured (e.g. Cloudflare Zero Trust root) and add it to Java too.
if [ -n "${NODE_EXTRA_CA_CERTS:-}" ] && [ -f "$NODE_EXTRA_CA_CERTS" ] && [ "$NODE_EXTRA_CA_CERTS" != "$TOOLS/.certs/keychain.pem" ]; then
  /usr/bin/grep -q "$(sed -n 2p "$NODE_EXTRA_CA_CERTS")" "$TOOLS/.certs/keychain.pem" 2>/dev/null || cat "$NODE_EXTRA_CA_CERTS" >> "$TOOLS/.certs/keychain.pem"
  keytool -list -keystore "$TS" -storepass changeit -alias user-extra-ca >/dev/null 2>&1 || \
    keytool -importcert -noprompt -trustcacerts -keystore "$TS" -storepass changeit -alias user-extra-ca -file "$NODE_EXTRA_CA_CERTS" >/dev/null 2>&1
fi
export NODE_EXTRA_CA_CERTS="$TOOLS/.certs/keychain.pem"
