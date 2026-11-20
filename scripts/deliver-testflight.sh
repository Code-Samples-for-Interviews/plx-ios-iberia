#!/bin/bash
set -euo pipefail

# Firma manual, archivo Release y subida a TestFlight.
# Este script se ejecuta desde la raíz del repositorio en un runner efímero de GitHub.
if [[ "${GITHUB_ACTIONS:-}" != "true" ]]; then
  echo "La entrega está preparada para ejecutarse en GitHub Actions." >&2
  exit 1
fi

for name in APPLE_TEAM_ID APP_BUNDLE_ID ASC_KEY_ID ASC_ISSUER_ID \
  IOS_CERTIFICATE_BASE64 IOS_CERTIFICATE_PASSWORD IOS_PROFILE_BASE64 ASC_PRIVATE_KEY; do
  if [[ -z "${!name:-}" ]]; then
    echo "Falta configurar $name. Consulta la sección TestFlight del README." >&2
    exit 1
  fi
done

# PENDIENTE [ENTREGA]: Añadir el icono antes de habilitar la primera subida.
if [[ ! -d AlbumSearch/AlbumSearch/Assets.xcassets/AppIcon.appiconset ]]; then
  echo "Falta el AppIcon. Configúralo en el catálogo y en el target antes de activar la entrega." >&2
  exit 1
fi

umask 077
work_dir=$(mktemp -d "$RUNNER_TEMP/album-delivery.XXXXXX")
keychain_path="$work_dir/signing.keychain-db"
profile_path=""

cleanup() {
  security delete-keychain "$keychain_path" >/dev/null 2>&1 || true
  if [[ -n "$profile_path" ]]; then rm -f "$profile_path"; fi
  rm -rf "$work_dir"
}
# Borramos los archivos privados también cuando falle el archivo o la subida.
trap cleanup EXIT

prepare_signing() {
  printf '%s' "$IOS_CERTIFICATE_BASE64" | base64 --decode > "$work_dir/certificate.p12"
  printf '%s' "$IOS_PROFILE_BASE64" | base64 --decode > "$work_dir/profile.mobileprovision"
  printf '%s' "$ASC_PRIVATE_KEY" > "$work_dir/AuthKey.p8"
  local password
  password=$(openssl rand -hex 32)
  security create-keychain -p "$password" "$keychain_path"
  security set-keychain-settings -lut 3600 "$keychain_path"
  security unlock-keychain -p "$password" "$keychain_path"
  security import "$work_dir/certificate.p12" -P "$IOS_CERTIFICATE_PASSWORD" \
    -k "$keychain_path" -T /usr/bin/codesign -T /usr/bin/security
  security set-key-partition-list -S apple-tool:,apple:,codesign: -k "$password" "$keychain_path" >/dev/null
  security list-keychains -d user -s "$keychain_path" "$HOME/Library/Keychains/login.keychain-db"
  security cms -D -i "$work_dir/profile.mobileprovision" > "$work_dir/profile.plist"
}

prepare_export() {
  export PROFILE_UUID
  PROFILE_UUID=$(/usr/libexec/PlistBuddy -c 'Print :UUID' "$work_dir/profile.plist")
  # Xcode 26 usa este directorio para los perfiles de aprovisionamiento.
  local profiles_dir="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
  mkdir -p "$profiles_dir"
  profile_path="$profiles_dir/$PROFILE_UUID.mobileprovision"
  cp "$work_dir/profile.mobileprovision" "$profile_path"
  python3 - "$work_dir/ExportOptions.plist" <<'EXPORT'
import os, plistlib, sys
options = {
    "method": "app-store-connect", "destination": "upload",
    "signingStyle": "manual", "signingCertificate": "Apple Distribution",
    "teamID": os.environ["APPLE_TEAM_ID"], "manageAppVersionAndBuildNumber": False,
    "provisioningProfiles": {os.environ["APP_BUNDLE_ID"]: os.environ["PROFILE_UUID"]},
}
with open(sys.argv[1], "wb") as file:
    plistlib.dump(options, file)
EXPORT
}

archive_app() {
  xcodebuild archive \
    -project AlbumSearch/AlbumSearch.xcodeproj -scheme AlbumSearch \
    -configuration Release -destination 'generic/platform=iOS' \
    -archivePath "$work_dir/AlbumSearch.xcarchive" \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY='Apple Distribution' \
    DEVELOPMENT_TEAM="$APPLE_TEAM_ID" PRODUCT_BUNDLE_IDENTIFIER="$APP_BUNDLE_ID" \
    PROVISIONING_PROFILE_SPECIFIER="$PROFILE_UUID" \
    CURRENT_PROJECT_VERSION="$GITHUB_RUN_NUMBER.$GITHUB_RUN_ATTEMPT"
}

upload_archive() {
  xcodebuild -exportArchive -archivePath "$work_dir/AlbumSearch.xcarchive" \
    -exportOptionsPlist "$work_dir/ExportOptions.plist" \
    -exportPath "$work_dir/export" \
    -authenticationKeyPath "$work_dir/AuthKey.p8" \
    -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID"
}

prepare_signing
prepare_export
archive_app
upload_archive
# La aceptación del envío no implica que Apple haya terminado de procesar el build.
echo "Envío completado. Revisa el procesamiento y los grupos de testers en App Store Connect."
