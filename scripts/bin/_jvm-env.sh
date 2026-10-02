# Sourced by scripts/bin/flutter and scripts/bin/dart. Requires ROOT (repo root).
# Keeps Dart, Flutter, Gradle and Android writing only inside the repo (no admin rights).
export HOME="$ROOT/.home" PUB_CACHE="$ROOT/.pub-cache"
export ANDROID_HOME="$ROOT/.android-sdk" ANDROID_SDK_ROOT="$ROOT/.android-sdk"
export ANDROID_USER_HOME="$ROOT/.home/.android" GRADLE_USER_HOME="$ROOT/.home/.gradle"
export ANDROID_AVD_HOME="$ROOT/.home/.android/avd"
export FLUTTER_SUPPRESS_ANALYTICS=true

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
if [ -z "${JAVA_HOME:-}" ] || [ ! -x "$JAVA_HOME/bin/java" ]; then
  for j in "$ROOT/.jdk/Contents/Home" "$ROOT/.jdk" /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home /usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home "$(/usr/libexec/java_home -v 17 2>/dev/null)"; do
    [ -n "$j" ] && [ -x "$j/bin/java" ] && { export JAVA_HOME="$j"; break; }
  done
  unset j
fi
mkdir -p "$ROOT/.home/tmp" "$GRADLE_USER_HOME"

JOPTS=""
[ -f "$ROOT/.certs/truststore.jks" ] && JOPTS="-Djavax.net.ssl.trustStore=$ROOT/.certs/truststore.jks -Djavax.net.ssl.trustStorePassword=changeit"

# Proxy: host and port go to every JVM (Java ignores HTTPS_PROXY). Credentials go ONLY to
# $GRADLE_USER_HOME/gradle.properties (mode 600): JAVA_TOOL_OPTIONS is echoed by every JVM
# ("Picked up JAVA_TOOL_OPTIONS: ...") and visible in `ps`, so it must never hold a password.
PROPS="$GRADLE_USER_HOME/gradle.properties"
P="${HTTPS_PROXY:-${https_proxy:-}}"
if [ -n "$P" ]; then
  P="${P#*://}"; AUTH=""; HOSTPORT="$P"
  case "$P" in *@*) AUTH="${P%@*}"; HOSTPORT="${P##*@}";; esac
  HOSTPORT="${HOSTPORT%%/*}"; HOST="${HOSTPORT%%:*}"; PORT="${HOSTPORT##*:}"
  [ "$HOST" = localhost ] && HOST=127.0.0.1
  JOPTS="$JOPTS -Dhttp.proxyHost=$HOST -Dhttp.proxyPort=$PORT -Dhttps.proxyHost=$HOST -Dhttps.proxyPort=$PORT"
  JOPTS="$JOPTS -Dhttp.nonProxyHosts=localhost|127.0.0.1 -Djdk.http.auth.tunneling.disabledSchemes= -Djdk.http.auth.proxying.disabledSchemes="
  touch "$PROPS"; chmod 600 "$PROPS"
  TMPP="$(mktemp "$ROOT/.home/tmp/props.XXXXXX")"
  /usr/bin/grep -vE '^systemProp\.https?\.proxy(User|Password)=' "$PROPS" > "$TMPP" || true
  if [ -n "$AUTH" ]; then
    _dec() { printf '%b' "$(printf '%s' "$1" | sed 's/+/ /g; s/%\([0-9A-Fa-f][0-9A-Fa-f]\)/\\x\1/g')"; }
    U="$(_dec "${AUTH%%:*}")"; W="$(_dec "${AUTH#*:}")"
    printf 'systemProp.http.proxyUser=%s\nsystemProp.http.proxyPassword=%s\nsystemProp.https.proxyUser=%s\nsystemProp.https.proxyPassword=%s\n' "$U" "$W" "$U" "$W" >> "$TMPP"
    unset U W
  fi
  cat "$TMPP" > "$PROPS"; rm -f "$TMPP"
fi
export JAVA_TOOL_OPTIONS="-Djava.net.preferIPv4Stack=true -Duser.home=$ROOT/.home -Djava.io.tmpdir=$ROOT/.home/tmp $JOPTS"
unset JOPTS P AUTH HOSTPORT HOST PORT PROPS
