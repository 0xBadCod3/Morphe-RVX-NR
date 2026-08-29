#!/bin/bash
# Mapping of filename prefixes to Release Tags
declare -A APP_MAP
APP_MAP=(
    ["cloudflare-1.1.1.1"]="Cloudflare-1.1.1.1"
    ["cloudflare-one"]="Cloudflare-One"
    ["adobescan"]="AdobeScan"
)

# Function to get app tag from filename
get_app_tag() {
    local filename=$1
    local lower_filename=$(echo "$filename" | tr '[:upper:]' '[:lower:]')

    local prefixes=($(for k in "${!APP_MAP[@]}"; do echo "$k"; done | awk '{ print length, $0 }' | sort -rn | cut -d" " -f2-))

    for prefix in "${prefixes[@]}"; do
        local lower_prefix=$(echo "$prefix" | tr '[:upper:]' '[:lower:]')
        if [[ $lower_filename == $lower_prefix* ]]; then
            echo "${APP_MAP[$prefix]}"
            return
        fi
    done

    echo "Other"
}

echo "[+] Starting Individual App Release process..."

echo "[+] Downloading assets from 'all' release..."
mkdir -p ./all-assets
gh release download all --dir ./all-assets --clobber --pattern "*.apk" || {
    echo "[-] No assets found in 'all' release or release does not exist."
    exit 0
}

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

    app_tag=$(get_app_tag "$filename")
    echo "[+] Mapped to tag: $app_tag"

    app_version=$($AAPT dump badging "$apk" | grep "versionName=" | sed -e "s/.*versionName='//" -e "s/' .*//")
    if [ -z "$app_version" ]; then
        echo "[!] Warning: Could not extract version for $apk. Skipping."
        continue
    fi
    echo "[+] Extracted version: $app_version"

    release_title="$app_tag v$app_version"
    release_notes="Automated release for $app_tag version $app_version."

    echo "[+] Checking if release $app_tag exists..."
    if gh release view "$app_tag" > /dev/null 2>&1; then
        echo "[+] Release $app_tag exists. Updating title and uploading asset..."
        gh release edit "$app_tag" --title "$release_title" --notes "$release_notes"
        gh release upload "$app_tag" "$apk" --clobber
    else
        echo "[+] Creating new release $app_tag..."
        gh release create "$app_tag" "$apk" --title "$release_title" --notes "$release_notes"
    fi
done

echo "[+] Individual App Release process completed."
