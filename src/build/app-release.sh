#!/bin/bash
# Mapping of filename prefixes to Release Tags
declare -A APP_MAP
APP_MAP=(
    ["cloudflare-1.1.1.1"]="Cloudflare-1.1.1.1"
    ["cloudflare-one"]="Cloudflare-One"
    ["adobescan"]="AdobeScan"
    ["adobe-scan"]="AdobeScan"
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

    echo ""
}

echo "[+] Starting Individual App Release process for custom branch..."

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

    tag=$(get_app_tag "$filename")
    if [ -z "$tag" ]; then
        continue
    fi

    echo "[+] Processing custom app $filename for tag '$tag'..."

    # Get version
    version=$($AAPT dump badging "$apk" | grep versionName | sed -n "s/.*versionName='\([^']*\)'.*/\1/p" | head -n 1)
    if [ -z "$version" ]; then
        echo "[!] Could not get version for $apk, skipping."
        continue
    fi

    new_name="${filename}-v${version}.apk"
    echo "[+] App: $tag, Version: $version, Release Asset: $new_name"

    # Check if exact asset already exists in release
    existing_assets=$(gh release view "$tag" --json assets --jq '.assets[].name' 2>/dev/null || true)
    if echo "$existing_assets" | grep -q "^${new_name}$"; then
        echo "[*] $new_name already exists in release '$tag', skipping update."
        continue
    fi

    cp "$apk" "../$new_name"

    # Create release if not existing with Title and Tag matching app name
    gh release create "$tag" --title "$tag" --notes "Individual release for $tag" --latest=false 2>/dev/null || true
    gh release edit "$tag" --latest=false || true

    # Delete old versions of this specific variant
    if [ -n "$existing_assets" ]; then
        for asset in $existing_assets; do
            if [[ "$asset" =~ ^${filename}-v.*\.apk$ ]]; then
                echo "[+] Deleting old variant asset: $asset"
                gh release delete-asset "$tag" "$asset" --yes || true
            fi
        done
    fi

    # Upload release asset with version format
    echo "[+] Uploading $new_name to release '$tag'..."
    gh release upload "$tag" "../$new_name" --clobber
    rm -f "../$new_name"
done
cd ..

echo "[+] Ensuring 'all' release is marked as latest..."
gh release edit all --latest || true

echo "[+] Individual App Release process completed."
