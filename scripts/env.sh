#!/usr/bin/env bash
# Source this file before running Gradle:  source scripts/env.sh
# Uses a project-local toolchain so no system install or admin rights are required.
#
#   .android-sdk/   Android SDK (platform 34, build-tools 34.0.0, platform-tools) — see scripts/install-sdk.sh
#   .jdk/           optional project-local JDK 17 (Temurin/Zulu tar.gz extracted here)
#
# Fallback JDK: Homebrew openjdk@17 (user-owned, no sudo).

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -x "$ROOT/.jdk/Contents/Home/bin/java" ]; then
  export JAVA_HOME="$ROOT/.jdk/Contents/Home"
elif [ -x "$ROOT/.jdk/bin/java" ]; then
  export JAVA_HOME="$ROOT/.jdk"
elif [ -d /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home ]; then
  export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
fi

export ANDROID_HOME="$ROOT/.android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"
export PATH="$ROOT/scripts/bin:$ROOT/.flutter/bin:$PATH"
export PUB_CACHE="$ROOT/.pub-cache"
unset JAVA_TOOL_OPTIONS

# --- TLS: this machine sits behind a Cloudflare Zero Trust gateway that re-signs HTTPS.
# The JDK's own cacerts does not contain that CA, so Gradle/Maven downloads fail with
# "PKIX path building failed". Build a truststore = JDK cacerts + macOS keychain certs.
TS="$ROOT/.certs/truststore.jks"
if [ ! -f "$TS" ]; then
  mkdir -p "$ROOT/.certs"
  cp "$JAVA_HOME/lib/security/cacerts" "$TS"
  PEM="$ROOT/.certs/keychain.pem"
  security find-certificate -a -p /Library/Keychains/System.keychain > "$PEM" 2>/dev/null
  security find-certificate -a -p "$HOME/Library/Keychains/login.keychain-db" >> "$PEM" 2>/dev/null
  ( cd "$ROOT/.certs" && awk '/BEGIN CERT/{n++; f="kc"n".pem"} {print > f}' keychain.pem
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
