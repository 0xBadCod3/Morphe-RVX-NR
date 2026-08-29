#!/bin/bash
# rushiranpise Morphe build
source ./src/build/utils.sh

rushiranpise_dl() {
	dl_gh "morphe-desktop" "MorpheApp" "latest"
	dl_gh "morphe-patches" "rushiranpise" "latest"
}

1() {
	rushiranpise_dl
	# Patch Adobe Scan
	get_patches_key "adobescan-rushiranpise"
	get_apk "com.adobe.scan.android" "adobescan" "bundle"
	patch "adobescan" "rushiranpise"
}

case "$1" in
	1)
		1
		;;
esac
