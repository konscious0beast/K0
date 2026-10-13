#!/usr/bin/env bash
# Apple release steps of the CI jobs apple-macos and apple-ios-testflight (.github/workflows/ptd-check.yml, 02_TECH
# §12.4, README section 4 "Mit Apple-Entwicklerkonto"). One subcommand per workflow step, on a GitHub-hosted macOS
# runner. Written for the runner's /bin/bash 3.2: no mapfile, no associative arrays, no empty "${a[@]}" under set -u.
#
#   godot macos|ios              Godot (macOS editor) + that platform's export template, checked against SHA512-SUMS.txt
#   xcode                        Xcode >= 26.1 (Godot 4.7.2's iOS libraries are built with the iOS 26.1 SDK)
#   keychain devid|dist          temp keychain with the .p12 from P12_BASE64 / P12_PASSWORD; picks the "Developer ID
#                                Application" resp. "Apple Distribution" identity of APPLE_TEAM_ID
#   asc-key                      App Store Connect API key (ASC_KEY_P8_BASE64, ASC_KEY_ID) → PEM file AuthKey_<id>.p8
#   profile                      App Store Connect provisioning profile (IOS_PROFILE_BASE64): checked, installed
#   export macos|ios <out>       temp copy of game/, release values into its preset (tests/tools/apple_preset.gd),
#                                Godot export: macOS → .app without signature, iOS → Xcode project
#   sign-macos <app>             Developer ID signature: hardened runtime, secure timestamp, PrimeTimeDungeon.entitlements
#   notarize <app> <zip>         notarytool (API key, waits) + log, staple, Gatekeeper check, zip of the stapled app
#   ipa <xcodeproj> <out.ipa>    xcodebuild archive + -exportArchive (app-store-connect, manual signing)
#   upload <ipa>                 altool upload to App Store Connect (TestFlight) with the API key
#   cleanup                      delete keychain, installed profiles and key files (the jobs run it with if: always())
#
# Secrets arrive as environment variables of the step that needs them and are never printed; decoded material lives
# in $RUNNER_TEMP/ptd-apple only. Values for later steps go to $GITHUB_ENV: PTD_GODOT, PTD_KEYCHAIN, PTD_SIGN_SHA1,
# PTD_SIGN_IDENTITY, PTD_ASC_KEY, API_PRIVATE_KEYS_DIR, PTD_PROFILE_UUID, PTD_PROFILE_NAME.
# Env: GODOT_VERSION, APPLE_TEAM_ID / APPLE_BUNDLE_ID (repository variables), PTD_BUILD_NUMBER (CFBundleVersion).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAME="$(cd "$HERE/../../game" && pwd)"
TMP_ROOT="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
SECRETS="$TMP_ROOT/ptd-apple"
KEYCHAIN="$SECRETS/signing.keychain-db"
UUID_RE='^[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}$'
KEY_ID_RE='^[A-Za-z0-9]{6,20}$'
XCODE_RE='^([0-9]+)(\.([0-9]+))?'
RUNTIME_RE='flags=0x[0-9a-f]+\([^)]*runtime'

die() { echo "::error::release.sh: $*"; exit 1; }
warn() { echo "::warning::release.sh: $*"; }
step() { echo "== $*"; }

mask() {
	if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::add-mask::$1"; fi
}

# Exports a value to this process and to the following workflow steps.
set_env() {
	case "$2" in *$'\n'*) die "$1 contains a line break" ;; esac
	export "$1=$2"
	if [ -n "${GITHUB_ENV:-}" ]; then printf '%s=%s\n' "$1" "$2" >>"$GITHUB_ENV"; fi
}

need() {
	local n
	for n in "$@"; do
		[ -n "${!n:-}" ] || die "$n fehlt (Secret/Variable des Repos bzw. Ergebnis eines früheren Schritts)"
	done
}

secrets_dir() {
	mkdir -p "$SECRETS"
	chmod 700 "$SECRETS"
}

# Base64 text from a secret → file. Line breaks, CR and spaces of a pasted secret are ignored.
b64_to_file() {
	printf '%s' "$1" | tr -d ' \t\r\n' | base64 --decode >"$2" 2>/dev/null || die "$3 ist kein gültiges Base64"
	[ -s "$2" ] || die "$3 ist leer"
}

# ASC_KEY_ID / ASC_ISSUER_ID without stray whitespace (a pasted secret often ends with a line break) → ASC_ID, ASC_ISS.
load_asc_ids() {
	ASC_ID="$(printf '%s' "${ASC_KEY_ID:-}" | tr -d '[:space:]')"
	[[ "$ASC_ID" =~ $KEY_ID_RE ]] || die "ASC_KEY_ID ist keine Schlüssel-ID (App Store Connect → Integrationen)"
	mask "$ASC_ID"
	if [ "${1:-}" = issuer ]; then
		ASC_ISS="$(printf '%s' "${ASC_ISSUER_ID:-}" | tr -d '[:space:]')"
		[[ "$ASC_ISS" =~ $UUID_RE ]] || die "ASC_ISSUER_ID ist keine Issuer-ID (UUID, App Store Connect → Integrationen)"
		mask "$ASC_ISS"
	fi
}

cmd_godot() {
	local platform="${1:-}"
	case "$platform" in macos | ios) ;; *) die "godot: macos|ios erwartet" ;; esac
	need GODOT_VERSION
	local ver="$GODOT_VERSION" dir="$TMP_ROOT/godot" f v
	local base="https://github.com/godotengine/godot/releases/download/${ver}-stable"
	local editor="Godot_v${ver}-stable_macos.universal.zip" tpz="Godot_v${ver}-stable_export_templates.tpz"
	local templates="$HOME/Library/Application Support/Godot/export_templates/${ver}.stable"
	mkdir -p "$dir" "$templates"
	for f in SHA512-SUMS.txt "$editor" "$tpz"; do curl -fsSL --retry 3 -o "$dir/$f" "$base/$f"; done
	awk -v a="$editor" -v b="$tpz" '$2 == a || $2 == b' "$dir/SHA512-SUMS.txt" >"$dir/sums.txt"
	[ "$(wc -l <"$dir/sums.txt" | tr -d ' ')" = 2 ] || die "SHA512-SUMS.txt nennt $editor / $tpz nicht"
	(cd "$dir" && shasum -a 512 -c sums.txt)
	rm -rf "$dir/Godot.app"
	ditto -x -k "$dir/$editor" "$dir"
	unzip -q -o -j "$dir/$tpz" "templates/${platform}.zip" "templates/version.txt" -d "$templates"
	rm -f "$dir/$editor" "$dir/$tpz"
	v="$("$dir/Godot.app/Contents/MacOS/Godot" --headless --version | tail -n 1)"
	case "$v" in "${ver}.stable"*) ;; *) die "Godot meldet \"$v\", erwartet $ver" ;; esac
	echo "Godot $v, Vorlage ${platform}.zip in $templates"
	set_env PTD_GODOT "$dir/Godot.app/Contents/MacOS/Godot"
}

cmd_xcode() {
	local v
	v="$(xcodebuild -version | awk 'NR == 1 { print $2 }')"
	[[ "$v" =~ $XCODE_RE ]] || die "Xcode-Version nicht lesbar: $v"
	if [ "${BASH_REMATCH[1]}" -lt 26 ] || { [ "${BASH_REMATCH[1]}" -eq 26 ] && [ "${BASH_REMATCH[3]:-0}" -lt 1 ]; }; then
		die "Xcode $v ist zu alt: Godot 4.7.2 (iOS) braucht Xcode 26.1 oder neuer"
	fi
	echo "Xcode $v ($(xcode-select -p)), iOS SDK $(xcrun --sdk iphoneos --show-sdk-version)"
}

cmd_keychain() {
	local kind="${1:-}" want label
	case "$kind" in
	devid) want='^Developer ID Application: ' label="Developer ID Application" ;;
	dist) want='^(Apple|iPhone|iOS) Distribution: ' label="Apple Distribution" ;;
	*) die "keychain: devid|dist erwartet" ;;
	esac
	need P12_BASE64 P12_PASSWORD APPLE_TEAM_ID
	secrets_dir
	local p12="$SECRETS/signing.p12" pw c k line sha name found_sha="" found_name="" seen=""
	pw="$(openssl rand -hex 24)"
	mask "$pw"
	b64_to_file "$P12_BASE64" "$p12" "Die .p12 (*_P12_BASE64)"
	security create-keychain -p "$pw" "$KEYCHAIN"
	security set-keychain-settings -lut 21600 "$KEYCHAIN"
	security unlock-keychain -p "$pw" "$KEYCHAIN"
	if ! security import "$p12" -k "$KEYCHAIN" -P "$P12_PASSWORD" -A -t cert -f pkcs12 </dev/null >/dev/null; then
		rm -f "$p12"
		die "Import der .p12 gescheitert: Passwort (*_P12_PASSWORD) falsch oder Datei ohne privaten Schlüssel (in der Schlüsselbundverwaltung Zertifikat samt Schlüssel als .p12 exportieren)"
	fi
	rm -f "$p12"
	# Apple's intermediate certificates complete the chain; the runner image only brings WWDR G3 and Developer ID G2.
	for c in AppleWWDRCAG3 AppleWWDRCAG4 AppleWWDRCAG5 AppleWWDRCAG6 DeveloperIDG2CA; do
		if curl -fsSL --retry 2 -o "$SECRETS/$c.cer" "https://www.apple.com/certificateauthority/$c.cer"; then
			security import "$SECRETS/$c.cer" -k "$KEYCHAIN" >/dev/null 2>&1 || true
		fi
	done
	security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$pw" "$KEYCHAIN" >/dev/null
	# Search list: this keychain first, then the existing ones (codesign and xcodebuild look identities up there).
	local list=("$KEYCHAIN")
	while IFS= read -r k; do
		k="${k#"${k%%[![:space:]]*}"}"
		k="${k#\"}"
		k="${k%\"}"
		if [ -n "$k" ] && [ "$k" != "$KEYCHAIN" ]; then list+=("$k"); fi
	done < <(security list-keychains -d user)
	security list-keychains -d user -s "${list[@]}"
	while IFS= read -r line; do
		sha="${line%% *}"
		name="${line#* }"
		seen="$seen; $name"
		if [ -z "$found_sha" ] && [[ "$name" =~ $want ]] && [[ "$name" == *"($APPLE_TEAM_ID)" ]]; then
			found_sha="$sha"
			found_name="$name"
		fi
	done < <(security find-identity -v -p codesigning "$KEYCHAIN" |
		sed -n 's/^ *[0-9][0-9]*) \([0-9A-F]\{40\}\) "\(.*\)"$/\1 \2/p')
	if [ -z "$found_sha" ]; then
		security find-identity -p codesigning "$KEYCHAIN" || true # also lists invalid identities with the reason
		die "keine gültige $label-Identität des Teams $APPLE_TEAM_ID in der .p12 (gültig: ${seen#; }); Zertifikatstyp, privaten Schlüssel in der .p12 und APPLE_TEAM_ID prüfen"
	fi
	echo "Signier-Identität: $found_name ($found_sha)"
	set_env PTD_KEYCHAIN "$KEYCHAIN"
	set_env PTD_SIGN_SHA1 "$found_sha"
	set_env PTD_SIGN_IDENTITY "$found_name"
}

cmd_asc_key() {
	need ASC_KEY_P8_BASE64 ASC_KEY_ID
	load_asc_ids
	secrets_dir
	mkdir -p "$SECRETS/private_keys"
	local raw="$SECRETS/asc_key.raw" pem="$SECRETS/private_keys/AuthKey_${ASC_ID}.p8"
	if [[ "$ASC_KEY_P8_BASE64" == *"-----BEGIN"* ]]; then
		printf '%s\n' "$ASC_KEY_P8_BASE64" | tr -d '\r' >"$raw" # the .p8 text itself was stored as the secret
	else
		b64_to_file "$ASC_KEY_P8_BASE64" "$raw" "ASC_KEY_P8_BASE64"
	fi
	# altool and notarytool read a PEM (PKCS#8) file; a key stored as DER makes altool fail with
	# "Failed to generate JWT token … (259)". openssl normalises both; -passin keeps it from waiting for a pass phrase
	# when the secret holds something encrypted (a .p12 by mistake).
	if ! (umask 077 && { openssl pkey -passin pass: -in "$raw" -out "$pem" </dev/null 2>/dev/null ||
		openssl pkey -passin pass: -inform DER -in "$raw" -out "$pem" </dev/null 2>/dev/null; }); then
		rm -f "$raw" "$pem"
		die "ASC_KEY_P8_BASE64 enthält keinen privaten Schlüssel (erwartet: base64 -i AuthKey_<Key-ID>.p8)"
	fi
	rm -f "$raw"
	[ "$(head -n 1 "$pem")" = "-----BEGIN PRIVATE KEY-----" ] || die "API-Schlüssel ist kein PKCS#8-Schlüssel"
	echo "App Store Connect API-Schlüssel bereit (PEM, AuthKey_<Key-ID>.p8)"
	set_env PTD_ASC_KEY "$pem"
	set_env API_PRIVATE_KEYS_DIR "$SECRETS/private_keys"
}

# Facts of a decoded provisioning profile (no secrets), one "key=value" per line.
profile_facts() {
	python3 -I - "$1" <<'PY'
import datetime, hashlib, plistlib, sys

with open(sys.argv[1], "rb") as f:
    p = plistlib.load(f)
ent = p.get("Entitlements", {})
exp = p.get("ExpirationDate")
now = datetime.datetime.now(datetime.timezone.utc)
print("uuid=" + str(p.get("UUID", "")))
print("name=" + " ".join(str(p.get("Name", "")).split()))
print("team=" + ",".join(p.get("TeamIdentifier", [])))
print("appid=" + str(ent.get("application-identifier", "")))
print("get_task_allow=" + ("yes" if ent.get("get-task-allow") else "no"))
print("devices=" + ("yes" if p.get("ProvisionedDevices") else "no"))
print("all_devices=" + ("yes" if p.get("ProvisionsAllDevices") else "no"))
print("expires=" + (exp.strftime("%Y-%m-%d") if exp else ""))
print("expired=" + ("yes" if exp is not None and exp.replace(tzinfo=datetime.timezone.utc) < now else "no"))
print("certs=" + ",".join(hashlib.sha1(c).hexdigest().upper() for c in p.get("DeveloperCertificates", [])))
PY
}

cmd_profile() {
	need IOS_PROFILE_BASE64 APPLE_TEAM_ID APPLE_BUNDLE_ID PTD_SIGN_SHA1
	secrets_dir
	local prof="$SECRETS/profile.mobileprovision" plist="$SECRETS/profile.plist" k v d
	local uuid="" name="" team="" appid="" gta="" devices="" all="" expires="" expired="" certs=""
	b64_to_file "$IOS_PROFILE_BASE64" "$prof" "IOS_PROFILE_BASE64"
	security cms -D -i "$prof" -o "$plist" 2>/dev/null || die "IOS_PROFILE_BASE64 ist kein Provisioning-Profil (.mobileprovision)"
	while IFS='=' read -r k v; do
		case "$k" in
		uuid) uuid="$v" ;; name) name="$v" ;; team) team="$v" ;; appid) appid="$v" ;; get_task_allow) gta="$v" ;;
		devices) devices="$v" ;; all_devices) all="$v" ;; expires) expires="$v" ;; expired) expired="$v" ;;
		certs) certs="$v" ;;
		esac
	done < <(profile_facts "$plist")
	echo "Profil: \"$name\" ($uuid), Team $team, App-ID $appid, gültig bis $expires"
	[[ "$uuid" =~ $UUID_RE ]] || die "Profil ohne UUID"
	[ "$team" = "$APPLE_TEAM_ID" ] || die "Profil gehört zu Team $team, APPLE_TEAM_ID ist $APPLE_TEAM_ID"
	if [ "$devices" = yes ] || [ "$gta" = yes ] || [ "$all" = yes ]; then
		die "\"$name\" ist ein Development-, Ad-hoc- oder Enterprise-Profil; TestFlight braucht ein Profil vom Typ \"App Store Connect\""
	fi
	[ "$expired" = no ] || die "Profil \"$name\" ist abgelaufen ($expires); im Developer-Portal neu erzeugen"
	if [ "$appid" != "$APPLE_TEAM_ID.$APPLE_BUNDLE_ID" ]; then
		[ "$appid" = "$APPLE_TEAM_ID.*" ] || die "Profil gilt für $appid, gebraucht wird $APPLE_TEAM_ID.$APPLE_BUNDLE_ID (APPLE_BUNDLE_ID)"
		warn "Wildcard-Profil ($appid): App Store Connect verlangt meist eine explizite App-ID"
	fi
	case ",$certs," in
	*",$PTD_SIGN_SHA1,"*) ;;
	*) die "Profil \"$name\" enthält das Distributionszertifikat aus IOS_DIST_P12_BASE64 nicht; Profil mit diesem Zertifikat neu erzeugen" ;;
	esac
	# Xcode 16+ reads UserData/Provisioning Profiles, older versions MobileDevice/Provisioning Profiles.
	for d in "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles" "$HOME/Library/MobileDevice/Provisioning Profiles"; do
		mkdir -p "$d"
		cp "$prof" "$d/$uuid.mobileprovision"
		echo "$d/$uuid.mobileprovision" >>"$SECRETS/installed-profiles"
	done
	rm -f "$plist"
	set_env PTD_PROFILE_UUID "$uuid"
	set_env PTD_PROFILE_NAME "$name"
}

# Facts of an exported app's Info.plist (Godot writes XML): bundle id, short version, build number.
plist_versions() {
	python3 -I - "$1" <<'PY'
import plistlib, sys

with open(sys.argv[1], "rb") as f:
    p = plistlib.load(f)
print(p.get("CFBundleIdentifier", ""), p.get("CFBundleShortVersionString", ""), p.get("CFBundleVersion", ""))
PY
}

cmd_export() {
	local platform="${1:-}" out="${2:-}" preset work pbx bundle short build
	case "$platform" in macos) preset=macOS ;; ios) preset=iOS ;; *) die "export: macos|ios <Ziel> erwartet" ;; esac
	[ -n "$out" ] || die "export: Ziel fehlt"
	need PTD_GODOT APPLE_TEAM_ID APPLE_BUNDLE_ID PTD_BUILD_NUMBER
	if [ "$platform" = ios ]; then need PTD_SIGN_IDENTITY PTD_PROFILE_UUID; fi
	# The release values go into a temp copy: the committed export_presets.cfg keeps its placeholders.
	work="$(mktemp -d "$TMP_ROOT/ptd-game.XXXXXX")"
	cp -R "$GAME/." "$work/"
	rm -rf "$work/.godot"
	step "import"
	"$PTD_GODOT" --headless --path "$work" --import || die "Godot-Import gescheitert"
	step "release values → preset \"$preset\""
	if ! "$PTD_GODOT" --headless --path "$work" -s res://tests/tools/apple_preset.gd -- --platform="$platform" \
		>"$work/apple_preset.log" 2>&1; then
		cat "$work/apple_preset.log"
		die "apple_preset.gd hat die Werte abgelehnt (Meldung oben)"
	fi
	grep '^APPLE_PRESET: ' "$work/apple_preset.log" || die "apple_preset.gd lief nicht"
	step "export \"$preset\" → $out"
	mkdir -p "$(dirname "$out")"
	rm -rf "$out"
	"$PTD_GODOT" --headless --path "$work" --export-release "$preset" "$out" || die "Godot-Export \"$preset\" gescheitert"
	rm -rf "$work"
	if [ "$platform" = macos ]; then
		[ -f "$out/Contents/Info.plist" ] || die "Export lieferte keine .app: $out"
		read -r bundle short build <<<"$(plist_versions "$out/Contents/Info.plist")"
	else
		[ -f "$out/project.pbxproj" ] && [ -s "$(dirname "$out")/$(basename "$out" .xcodeproj).pck" ] ||
			die "Export lieferte kein vollständiges Xcode-Projekt: $out"
		pbx="$out/project.pbxproj"
		grep -q 'CODE_SIGN_STYLE = "Manual";' "$pbx" || die "Xcode-Projekt ohne manuelle Signatur"
		grep -q "DEVELOPMENT_TEAM = $APPLE_TEAM_ID;" "$pbx" || die "Xcode-Projekt ohne das Team $APPLE_TEAM_ID"
		grep -q "PROVISIONING_PROFILE_SPECIFIER = \"$PTD_PROFILE_UUID\";" "$pbx" || die "Xcode-Projekt ohne das Profil"
		bundle="$(sed -n 's/^[[:space:]]*PRODUCT_BUNDLE_IDENTIFIER = \(.*\);$/\1/p' "$pbx" | sort -u | tr '\n' ' ')"
		short="$(sed -n 's/^[[:space:]]*MARKETING_VERSION = \(.*\);$/\1/p' "$pbx" | sort -u | tr '\n' ' ')"
		build="$(sed -n 's/^[[:space:]]*CURRENT_PROJECT_VERSION = \(.*\);$/\1/p' "$pbx" | sort -u | tr '\n' ' ')"
		bundle="${bundle% }" short="${short% }" build="${build% }"
	fi
	echo "exportiert: $bundle $short ($build)"
	[ "$bundle" = "$APPLE_BUNDLE_ID" ] || die "Export trägt die Bundle-ID \"$bundle\" statt $APPLE_BUNDLE_ID"
	[ "$build" = "$PTD_BUILD_NUMBER" ] || die "Export trägt die Build-Nummer \"$build\" statt $PTD_BUILD_NUMBER"
}

cmd_sign_macos() {
	local app="${1:-}" ent="$HERE/PrimeTimeDungeon.entitlements" main f info
	[ -f "$app/Contents/Info.plist" ] || die "sign-macos: keine .app: $app"
	need PTD_KEYCHAIN PTD_SIGN_SHA1 APPLE_TEAM_ID
	plutil -lint "$ent" >/dev/null || die "$ent ist keine gültige Property List"
	main="$app/Contents/MacOS/$(plutil -extract CFBundleExecutable raw -o - "$app/Contents/Info.plist")"
	sign() { codesign --force --timestamp --options runtime --keychain "$PTD_KEYCHAIN" --sign "$PTD_SIGN_SHA1" "$@"; }
	# Nested code first, inside out (Godot 4.7.2's template has none; GDExtension libraries would land in Frameworks/).
	while IFS= read -r -d '' f; do
		case "$f" in "$main" | *.framework/*) continue ;; esac
		if [[ "$(file -b "$f")" == Mach-O* ]]; then sign "$f"; fi
	done < <(find "$app/Contents" -type f -print0)
	while IFS= read -r -d '' f; do sign "$f"; done < <(find "$app/Contents" -depth -type d -name '*.framework' -print0)
	sign --entitlements "$ent" "$app"
	codesign --verify --deep --strict --verbose=2 "$app" || die "codesign --verify lehnt die Signatur ab (Meldung oben)"
	info="$(codesign -dvv "$app" 2>&1)"
	echo "$info" | grep -E '^(Identifier|Format|CodeDirectory|Authority|Timestamp|TeamIdentifier)=' || true
	[[ "$info" =~ $RUNTIME_RE ]] || die "Signatur ohne Hardened Runtime"
	[[ "$info" == *"Timestamp="* ]] || die "Signatur ohne sicheren Zeitstempel"
	[[ "$info" == *"Authority=Developer ID Application: "* ]] || die "nicht mit einem Developer-ID-Application-Zertifikat signiert"
	[[ "$info" == *"TeamIdentifier=$APPLE_TEAM_ID"* ]] || die "Signatur gehört nicht zu Team $APPLE_TEAM_ID"
}

# "<id> <status>" from notarytool's JSON output (the last JSON object if there is more than one line).
notary_result() {
	python3 -I - "$1" <<'PY'
import json, sys

text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
doc = {}
for chunk in [text] + text.splitlines()[::-1]:
    try:
        doc = json.loads(chunk)
        break
    except ValueError:
        continue
if not isinstance(doc, dict):
    doc = {}
print(doc.get("id") or "-", doc.get("status") or "-")
PY
}

cmd_notarize() {
	local app="${1:-}" zip="${2:-}" sub="$TMP_ROOT/ptd-notarize.zip" result="$TMP_ROOT/ptd-notary.json"
	local rc=0 sid status n gk
	[ -d "$app" ] && [ -n "$zip" ] || die "notarize: <app> <zip> erwartet"
	need PTD_ASC_KEY
	load_asc_ids issuer
	ditto -c -k --keepParent "$app" "$sub"
	step "notarytool submit --wait (meist unter 15 Minuten)"
	xcrun notarytool submit "$sub" --key "$PTD_ASC_KEY" --key-id "$ASC_ID" --issuer "$ASC_ISS" \
		--wait --timeout 45m --output-format json </dev/null >"$result" || rc=$?
	read -r sid status <<<"$(notary_result "$result")"
	[ "$sid" != - ] || sid=""
	echo "notarytool: exit $rc, Submission ${sid:-?}, Status $status"
	if [ -n "$sid" ]; then
		# Apple: always read the log, it lists warnings even for an accepted submission.
		if xcrun notarytool log "$sid" --key "$PTD_ASC_KEY" --key-id "$ASC_ID" --issuer "$ASC_ISS" \
			"$TMP_ROOT/ptd-notary-log.json" >/dev/null; then
			cat "$TMP_ROOT/ptd-notary-log.json"
			echo
		fi
	fi
	[ "$status" = Accepted ] || die "Notarisierung: Status ${status:-unbekannt} (Log oben). Bei \"In Progress\": Apple braucht länger, später mit xcrun notarytool info ${sid:-<id>} prüfen und den Job neu starten"
	rm -f "$sub"
	step "stapler staple"
	for n in 1 2 3 4 5 6; do
		if xcrun stapler staple "$app"; then break; fi
		[ "$n" -lt 6 ] || die "stapler staple scheiterte sechsmal (Ticket noch nicht abrufbar?)"
		sleep 20
	done
	xcrun stapler validate "$app"
	if [[ "$(spctl --status 2>&1)" == *"assessments enabled"* ]]; then
		gk="$(spctl --assess --type execute --verbose=4 "$app" 2>&1)" || { echo "$gk"; die "Gatekeeper lehnt die App ab"; }
		echo "$gk"
		[[ "$gk" == *"source=Notarized Developer ID"* ]] || die "Gatekeeper sieht keine notarisierte Developer-ID-App"
	else
		echo "Gatekeeper ist auf diesem Runner aus; geprüft sind Signatur (codesign) und Ticket (stapler validate)"
	fi
	mkdir -p "$(dirname "$zip")"
	rm -f "$zip"
	ditto -c -k --keepParent "$app" "$zip"
	echo "notarisiert und geheftet: $zip"
}

# ExportOptions.plist for -exportArchive: <path> <team> <bundle id> <profile uuid> <certificate sha1>.
export_options() {
	python3 -I - "$@" <<'PY'
import plistlib, sys

path, team, bundle, profile, cert = sys.argv[1:6]
with open(path, "wb") as f:
    plistlib.dump({
        "method": "app-store-connect",            # TestFlight / App Store
        "destination": "export",                  # write the IPA; `release.sh upload` sends it with altool
        "teamID": team,
        "signingStyle": "manual",
        "signingCertificate": cert,               # SHA-1 of the Apple Distribution identity
        "provisioningProfiles": {bundle: profile},
        "manageAppVersionAndBuildNumber": False,  # CFBundleVersion stays the CI build number
        "uploadSymbols": True,
    }, f)
PY
}

# "<bundle id> <short version> <build> <yes|no: embedded profile>" of an IPA.
ipa_facts() {
	python3 -I - "$1" <<'PY'
import plistlib, sys, zipfile

z = zipfile.ZipFile(sys.argv[1])
names = z.namelist()
apps = sorted({n.split("/")[1] for n in names if n.startswith("Payload/") and n.split("/")[1].endswith(".app")})
if len(apps) != 1:
    sys.exit("IPA: expected one Payload/*.app, found %s" % apps)
app = "Payload/%s/" % apps[0]
info = plistlib.loads(z.read(app + "Info.plist"))
print(info.get("CFBundleIdentifier", ""), info.get("CFBundleShortVersionString", ""), info.get("CFBundleVersion", ""),
      "yes" if app + "embedded.mobileprovision" in names else "no")
PY
}

cmd_ipa() {
	local proj="${1:-}" out="${2:-}" scheme work ipa got bundle short build embedded
	[ -f "$proj/project.pbxproj" ] && [ -n "$out" ] || die "ipa: <Projekt.xcodeproj> <Ziel.ipa> erwartet"
	need PTD_KEYCHAIN PTD_SIGN_SHA1 PTD_SIGN_IDENTITY PTD_PROFILE_UUID APPLE_TEAM_ID APPLE_BUNDLE_ID PTD_BUILD_NUMBER
	scheme="$(basename "$proj" .xcodeproj)"
	work="$TMP_ROOT/ptd-ios-archive"
	rm -rf "$work"
	mkdir -p "$work"
	step "xcodebuild archive ($scheme, Release, manuelle Signatur)"
	xcodebuild -project "$proj" -scheme "$scheme" -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
		-archivePath "$work/$scheme.xcarchive" -derivedDataPath "$work/DerivedData" archive \
		CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="$APPLE_TEAM_ID" CODE_SIGN_IDENTITY="$PTD_SIGN_IDENTITY" \
		PROVISIONING_PROFILE_SPECIFIER="$PTD_PROFILE_UUID" OTHER_CODE_SIGN_FLAGS="--keychain $PTD_KEYCHAIN" ||
		die "xcodebuild archive gescheitert (Meldung oben)"
	export_options "$work/ExportOptions.plist" "$APPLE_TEAM_ID" "$APPLE_BUNDLE_ID" "$PTD_PROFILE_UUID" "$PTD_SIGN_SHA1"
	step "xcodebuild -exportArchive (app-store-connect)"
	xcodebuild -exportArchive -archivePath "$work/$scheme.xcarchive" -exportPath "$work/export" \
		-exportOptionsPlist "$work/ExportOptions.plist" || die "xcodebuild -exportArchive gescheitert (Meldung oben)"
	local ipas=("$work/export"/*.ipa)
	[ "${#ipas[@]}" -eq 1 ] && [ -s "${ipas[0]}" ] || die "der Export enthält nicht genau eine .ipa"
	ipa="${ipas[0]}"
	got="$(ipa_facts "$ipa")" || die "die IPA lässt sich nicht lesen: $ipa"
	read -r bundle short build embedded <<<"$got"
	echo "IPA: $bundle $short ($build), Profil eingebettet: $embedded"
	[ "$bundle" = "$APPLE_BUNDLE_ID" ] && [ "$build" = "$PTD_BUILD_NUMBER" ] && [ "$embedded" = yes ] ||
		die "IPA passt nicht: $got (erwartet $APPLE_BUNDLE_ID, Build $PTD_BUILD_NUMBER, eingebettetes Profil)"
	mkdir -p "$(dirname "$out")"
	cp "$ipa" "$out"
}

cmd_upload() {
	local ipa="${1:-}" log="$TMP_ROOT/ptd-altool.log" rc=0
	[ -s "$ipa" ] || die "upload: IPA fehlt: $ipa"
	need API_PRIVATE_KEYS_DIR
	load_asc_ids issuer
	[ -s "$API_PRIVATE_KEYS_DIR/AuthKey_${ASC_ID}.p8" ] || die "API-Schlüssel fehlt (Schritt asc-key)"
	step "altool --upload-app (App Store Connect → TestFlight)"
	xcrun altool --upload-app -f "$ipa" -t ios --apiKey "$ASC_ID" --apiIssuer "$ASC_ISS" </dev/null >"$log" 2>&1 || rc=$?
	cat "$log"
	if [ "$rc" -ne 0 ] || grep -qE 'ERROR ITMS-|\*\*\* Error' "$log"; then
		die "Upload zu App Store Connect gescheitert (exit $rc, Meldung oben). Die IPA liegt als Artefakt bereit und lässt sich auch mit der App Transporter hochladen"
	fi
}

cmd_cleanup() {
	local p
	if [ -f "$KEYCHAIN" ]; then security delete-keychain "$KEYCHAIN" || warn "Keychain ließ sich nicht löschen"; fi
	if [ -f "$SECRETS/installed-profiles" ]; then
		while IFS= read -r p; do rm -f "$p"; done <"$SECRETS/installed-profiles"
	fi
	rm -rf "$SECRETS" "$TMP_ROOT/ptd-ios-archive" "$TMP_ROOT/ptd-notarize.zip"
	echo "Keychain, Profile und Schlüssel entfernt"
}

cmd="${1:-}"
if [ $# -gt 0 ]; then shift; fi
case "$cmd" in
godot) cmd_godot "$@" ;;
xcode) cmd_xcode ;;
keychain) cmd_keychain "$@" ;;
asc-key) cmd_asc_key ;;
profile) cmd_profile ;;
export) cmd_export "$@" ;;
sign-macos) cmd_sign_macos "$@" ;;
notarize) cmd_notarize "$@" ;;
ipa) cmd_ipa "$@" ;;
upload) cmd_upload "$@" ;;
cleanup) cmd_cleanup ;;
*)
	echo "usage: release.sh godot|xcode|keychain|asc-key|profile|export|sign-macos|notarize|ipa|upload|cleanup …" >&2
	exit 2
	;;
esac
