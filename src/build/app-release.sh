#!/bin/bash

# Mapping of filename prefixes to Release Tags
declare -A APP_MAP
APP_MAP=(
    ["youtube-music"]="YouTubeMusic"
    ["youtube"]="YouTube"
    ["reddit"]="Reddit"
    ["twitter"]="Twitter"
    ["instagram"]="Instagram"
    ["facebook"]="Facebook"
    ["messenger"]="Messenger"
    ["tiktok"]="TikTok"
    ["twitch"]="Twitch"
    ["soundcloud"]="SoundCloud"
    ["telegram"]="Telegram"
    ["viber"]="Viber"
    ["bilibili"]="BiliBili"
    ["adguard"]="AdGuard"
    ["duolingo"]="Duolingo"
    ["protonmail"]="ProtonMail"
    ["protonvpn"]="ProtonVPN"
    ["wps-office"]="WPSOffice"
    ["prime-video"]="PrimeVideo"
    ["discord"]="Discord"
    ["google-news"]="GoogleNews"
    ["google-photos"]="GooglePhotos"
    ["gg-photos"]="GooglePhotos"
    ["google-recorder"]="GoogleRecorder"
    ["googlenews"]="GoogleNews"
    ["photomath"]="Photomath"
    ["rar"]="RAR"
    ["nova-launcher"]="NovaLauncher"
    ["truecaller"]="Truecaller"
    ["tumblr"]="Tumblr"
    ["smart-launcher"]="SmartLauncher"
    ["pixiv"]="Pixiv"
    ["fx-file-explorer"]="FXFileExplorer"
    ["solid-explorer"]="SolidExplorer"
    ["strava"]="Strava"
    ["eyecon"]="Eyecon"
    ["crunchyroll"]="Crunchyroll"
    ["spotify"]="Spotify"
    ["spotjfy"]="Spotify"
    ["myfitnesspal"]="MyFitnessPal"
    ["threads"]="Threads"
    ["tasker"]="Tasker"
    ["lightroom"]="Lightroom"
)

# Function to get app tag from filename
get_app_tag() {
    local filename=$1
    local lower_filename=$(echo "$filename" | tr '[:upper:]' '[:lower:]')

    # Sort prefixes by length descending to match more specific ones first (e.g. youtube-music before youtube)
    local prefixes=($(for k in "${!APP_MAP[@]}"; do echo "$k"; done | awk '{ print length, $0 }' | sort -rn | cut -d" " -f2-))

    for prefix in "${prefixes[@]}"; do
        local lower_prefix=$(echo "$prefix" | tr '[:upper:]' '[:lower:]')
        if [[ $lower_filename == $lower_prefix* ]]; then
            echo "${APP_MAP[$prefix]}"
            return
        fi
    done

    # Fallback: Put unmatched apps into the "Other" tag
    echo "Other"
}

echo "[+] Starting Individual App Release process..."

# Ensure gh is logged in (handled by GITHUB_TOKEN in workflow)
# Download assets from 'all' release
echo "[+] Downloading assets from 'all' release..."
mkdir -p ./all-assets
gh release download all --dir ./all-assets --clobber --pattern "*.apk" || {
    echo "[-] No assets found in 'all' release or release does not exist."
    exit 0
}

# Find aapt
AAPT=$(command -v aapt)
if [ -z "$AAPT" ]; then
    echo "[!] aapt not found in PATH, searching in Android SDK..."
    AAPT=$(find /usr/local/lib/android/sdk/build-tools -name aapt | sort -r | head -n 1)
fi

if [ -z "$AAPT" ]; then
    echo "[-] Error: aapt not found. Cannot extract version."
    exit 1
fi
echo "[+] Using aapt: $AAPT"

cd ./all-assets
for apk in *.apk; do
    [ -e "$apk" ] || continue

    filename=$(basename "$apk" .apk)
    echo "[+] Processing $filename..."

    # Get version
    version=$($AAPT dump badging "$apk" | grep versionName | sed -n "s/.*versionName='\([^']*\)'.*/\1/p" | head -n 1)

    if [ -z "$version" ]; then
        echo "[!] Could not get version for $apk, skipping."
        continue
    fi

    tag=$(get_app_tag "$filename")
    new_name="${filename}-v${version}.apk"

    echo "[+] App: $tag, Version: $version, New Name: $new_name"

    # Check if this exact file already exists in the release
    echo "[+] Checking if $new_name already exists in release '$tag'..."
    existing_assets=$(gh release view "$tag" --json assets --jq '.assets[].name' 2>/dev/null || true)

    if echo "$existing_assets" | grep -q "^${new_name}$"; then
        echo "[*] $new_name already exists in release '$tag', skipping update."
        continue
    fi

    cp "$apk" "../$new_name"

    # Create release if it doesn't exist (ensure it is NOT marked as latest)
    gh release create "$tag" --title "$tag" --notes "Individual release for $tag" --latest=false 2>/dev/null || true

    # Ensure it is NOT marked as latest even if it existed
    gh release edit "$tag" --latest=false || true

    # Delete only the existing asset for this SPECIFIC variant to keep only the latest version
    echo "[+] Checking for old versions of variant '$filename' in release '$tag'..."
    existing_assets=$(gh release view "$tag" --json assets --jq '.assets[].name' 2>/dev/null || true)
    if [ -n "$existing_assets" ]; then
        for asset in $existing_assets; do
            # Regex match: Ensure the asset name exactly matches {filename}-v{version}.apk
            # This prevents deleting 'youtube-music' when processing 'youtube'
            if [[ "$asset" =~ ^${filename}-v.*\.apk$ ]]; then
                echo "[+] Deleting old variant asset: $asset"
                gh release delete-asset "$tag" "$asset" --yes || true
            fi
        done
    fi

    # Upload file
    echo "[+] Uploading to release '$tag'..."
    gh release upload "$tag" "../$new_name" --clobber
done
cd ..

echo "[+] Ensuring 'all' release is marked as latest..."
gh release edit all --latest || true

echo "[+] Individual App Release process completed."
