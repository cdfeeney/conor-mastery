#!/bin/bash
# Signs and uploads an internal TestFlight build. Runs only in release.yml's testflight job, after the gate passed.
# Adapted from ConorHealth's Scripts/testflight.sh: temporary keychain, profiles installed for this run only,
# everything deleted on exit, no secret ever echoed.
set +x
set -euo pipefail
umask 077

: "${RUNNER_TEMP:?}" "${ASC_KEY_ID:?}" "${ASC_ISSUER_ID:?}" "${ASC_PRIVATE_KEY:?}"
: "${BUILD_CERTIFICATE_BASE64:?}" "${P12_PASSWORD:?}" "${GITHUB_RUN_NUMBER:?}"
: "${PROFILE_APP_BASE64:?}" "${PROFILE_WIDGETS_BASE64:?}" "${PROFILE_MONITOR_BASE64:?}"
[[ "$ASC_KEY_ID" =~ ^[A-Z0-9]{10}$ ]]
[[ "$ASC_ISSUER_ID" =~ ^[a-fA-F0-9-]{36}$ ]]
# ponytail: the run number is the build number; switch to a counter before run 10000.
[[ "$GITHUB_RUN_NUMBER" =~ ^[1-9][0-9]{0,3}$ ]]
[[ "$(xcrun --sdk iphoneos --show-sdk-version)" == 26.* ]]

TEAM_ID=6VBFL287PT
STATE=$(mktemp -d "$RUNNER_TEMP/mastery-signing.XXXXXX")
export STATE
KEYCHAIN="$STATE/signing.keychain-db"
PROFILE_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
INSTALLED=()
cleanup() {
  status=$?
  trap - EXIT
  set +e
  security delete-keychain "$KEYCHAIN" >/dev/null 2>&1
  # macOS bash 3.2 + set -u: an empty array expands only through the +word form.
  for p in ${INSTALLED[@]+"${INSTALLED[@]}"}; do rm -f "$p"; done
  rm -rf "$STATE"
  exit "$status"
}
trap cleanup EXIT

# Decode secrets to files (python, so nothing passes through argv or the log).
python3 - <<'PY'
import base64, os
from pathlib import Path
d = Path(os.environ['STATE'])
for var, name in [('BUILD_CERTIFICATE_BASE64', 'certificate.p12'), ('PROFILE_APP_BASE64', 'app.mobileprovision'),
                  ('PROFILE_WIDGETS_BASE64', 'widgets.mobileprovision'), ('PROFILE_MONITOR_BASE64', 'monitor.mobileprovision')]:
    (d / name).write_bytes(base64.b64decode(os.environ[var], validate=True))
keys = d / 'private_keys'; keys.mkdir()
(keys / f"AuthKey_{os.environ['ASC_KEY_ID']}.p8").write_text(os.environ['ASC_PRIVATE_KEY'], encoding='utf-8')
PY
unset BUILD_CERTIFICATE_BASE64 PROFILE_APP_BASE64 PROFILE_WIDGETS_BASE64 PROFILE_MONITOR_BASE64 ASC_PRIVATE_KEY

# Each profile must be an App Store profile for the expected bundle ID; collect UUIDs for the export options.
for p in app widgets monitor; do security cms -D -i "$STATE/$p.mobileprovision" > "$STATE/$p.plist"; done
python3 - "$TEAM_ID" <<'PY'
import os, plistlib, sys
from pathlib import Path
d, team = Path(os.environ['STATE']), sys.argv[1]
expected = {'app': 'com.conorfee.conormastery', 'widgets': 'com.conorfee.conormastery.widgets',
            'monitor': 'com.conorfee.conormastery.monitor'}
mapping = {}
for name, bundle in expected.items():
    profile = plistlib.loads((d / f'{name}.plist').read_bytes())
    ent = profile['Entitlements']
    assert ent['application-identifier'] == f'{team}.{bundle}', (name, ent['application-identifier'])
    assert ent.get('get-task-allow') is False, f'{name}: not a distribution profile'
    assert not profile.get('ProvisionedDevices'), f'{name}: ad hoc profile, expected App Store'
    mapping[bundle] = profile['UUID']
    (d / f'{name}.uuid').write_text(profile['UUID'])
options = {'method': 'app-store-connect', 'destination': 'export', 'teamID': team, 'signingStyle': 'manual',
           'signingCertificate': 'Apple Distribution', 'provisioningProfiles': mapping,
           'manageAppVersionAndBuildNumber': False, 'testFlightInternalTestingOnly': True}
(d / 'ExportOptions.plist').write_bytes(plistlib.dumps(options))
print('profiles ok:', ', '.join(sorted(mapping)))
PY

KEYCHAIN_PASSWORD=$(openssl rand -hex 32)
echo "::add-mask::$KEYCHAIN_PASSWORD"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 1800 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security import "$STATE/certificate.p12" -k "$KEYCHAIN" -P "$P12_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security >/dev/null
unset P12_PASSWORD
security set-key-partition-list -S apple-tool:,apple:,codesign: -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
security list-keychains -d user -s "$KEYCHAIN" "$HOME/Library/Keychains/login.keychain-db"
security find-identity -v -p codesigning "$KEYCHAIN" | grep -q "Apple Distribution"
mkdir -p "$PROFILE_DIR"
for p in app widgets monitor; do
  dest="$PROFILE_DIR/$(cat "$STATE/$p.uuid").mobileprovision"
  cp "$STATE/$p.mobileprovision" "$dest"
  INSTALLED+=("$dest")
done

# Per-target profiles come from project.yml's Release settings; style and identity go on the command line because
# XcodeGen's per-target iOS defaults override project-level ones (run 39176590275 looked for "iOS Development").
# The build number is the run number.
xcodebuild -project ConorMastery.xcodeproj -scheme ConorMastery -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$STATE/ConorMastery.xcarchive" \
  -derivedDataPath "$STATE/DerivedData" \
  DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Apple Distribution" \
  CURRENT_PROJECT_VERSION="$GITHUB_RUN_NUMBER" MASTERY_SCREEN_TIME=NO archive

xcodebuild -exportArchive -archivePath "$STATE/ConorMastery.xcarchive" \
  -exportPath "$STATE/export" -exportOptionsPlist "$STATE/ExportOptions.plist"
IPA=$(ls "$STATE"/export/*.ipa)
test -f "$IPA"
# altool finds AuthKey_<ID>.p8 in ./private_keys.
(
  cd "$STATE"
  xcrun altool --validate-app -f "$IPA" -t ios --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
  xcrun altool --upload-app -f "$IPA" -t ios --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
)
echo "Build $GITHUB_RUN_NUMBER sent to Apple for processing (internal TestFlight). Screen Time blocking is off in this build." >> "$GITHUB_STEP_SUMMARY"
