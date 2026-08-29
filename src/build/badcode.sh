#!/bin/bash
# BadCode Morphe build
source ./src/build/utils.sh

badcode_dl() {
	dl_gh "morphe-desktop" "MorpheApp" "latest"
	dl_gh "badcode-patches" "0xBadCod3" "latest"
}

1() {
	badcode_dl
	# Patch Cloudflare 1.1.1.1
	get_patches_key "cloudflare-1.1.1.1-badcode"
	get_apk "com.cloudflare.onedotonedotonedotone" "cloudflare-1.1.1.1" "apk"
	patch "cloudflare-1.1.1.1" "badcode"
}

2() {
	badcode_dl
	# Patch Cloudflare One Agent
	get_patches_key "cloudflare-one-badcode"
	get_apk "com.cloudflare.cloudflareoneagent" "cloudflare-one" "apk"
	patch "cloudflare-one" "badcode"
}

case "$1" in
	1)
		1
		;;
	2)
		2
		;;
esac
