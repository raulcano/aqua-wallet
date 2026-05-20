#!/usr/bin/env bash
# Project-local Flutter/Dart toolchain for aqua-wallet.
# Does not modify your global Flutter install or default PUB_CACHE.
#
# Usage:
#   source scripts/aqua-dev-env.sh
#   flutter pub get
#   flutter run -d <device-id>

_aqua_dev_env_script="${BASH_SOURCE[0]:-$0}"
_aqua_project_root="$(cd "$(dirname "$_aqua_dev_env_script")/.." && pwd)"

export AQUA_FLUTTER_ROOT="${AQUA_FLUTTER_ROOT:-$HOME/development/flutter-3.22.3}"
export AQUA_PUB_CACHE="${AQUA_PUB_CACHE:-$HOME/development/pub-cache-aqua-wallet}"
export AQUA_JAVA_HOME="${AQUA_JAVA_HOME:-$HOME/.local/toolchains/jdk-17.0.18+8}"
export AQUA_GRADLE_USER_HOME="${AQUA_GRADLE_USER_HOME:-$HOME/development/gradle-home-aqua-wallet}"
export AQUA_XDG_CONFIG_HOME="${AQUA_XDG_CONFIG_HOME:-$HOME/development/xdg-config-aqua-wallet}"

if [[ ! -x "${AQUA_FLUTTER_ROOT}/bin/flutter" ]]; then
  echo "aqua-dev-env: Flutter not found at ${AQUA_FLUTTER_ROOT}/bin/flutter" >&2
  echo "Install with: git clone https://github.com/flutter/flutter.git --branch 3.22.3 --depth 1 ${AQUA_FLUTTER_ROOT}" >&2
  return 1 2>/dev/null || exit 1
fi

mkdir -p "${AQUA_PUB_CACHE}" "${AQUA_GRADLE_USER_HOME}" "${AQUA_XDG_CONFIG_HOME}/flutter"

# Isolate Flutter CLI settings (jdk-dir, android-sdk) from ~/.config/flutter.
export XDG_CONFIG_HOME="${AQUA_XDG_CONFIG_HOME}"
_aqua_android_sdk="${ANDROID_HOME:-}"
if [[ -z "${_aqua_android_sdk}" && -d "${HOME}/Android/Sdk" ]]; then
  _aqua_android_sdk="${HOME}/Android/Sdk"
fi
_aqua_flutter_settings="${AQUA_XDG_CONFIG_HOME}/flutter/settings"
if [[ ! -f "${_aqua_flutter_settings}" ]]; then
  printf '%s\n' "{" \
    "  \"android-sdk\": \"${_aqua_android_sdk}\"," \
    "  \"jdk-dir\": \"${AQUA_JAVA_HOME}\"" \
    "}" > "${_aqua_flutter_settings}"
fi

export PATH="${AQUA_FLUTTER_ROOT}/bin:${PATH}"
export PUB_CACHE="${AQUA_PUB_CACHE}"
export GRADLE_USER_HOME="${AQUA_GRADLE_USER_HOME}"

if [[ -d "${AQUA_JAVA_HOME}" ]]; then
  export JAVA_HOME="${AQUA_JAVA_HOME}"
  export PATH="${JAVA_HOME}/bin:${PATH}"
fi

if [[ -n "${_aqua_android_sdk}" ]]; then
  export ANDROID_HOME="${_aqua_android_sdk}"
  export ANDROID_SDK_ROOT="${ANDROID_HOME}"
fi

cd "${_aqua_project_root}" || return 1 2>/dev/null || exit 1
