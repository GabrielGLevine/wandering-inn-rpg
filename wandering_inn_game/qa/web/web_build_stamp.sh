#!/usr/bin/env bash
# Record or verify the exported Web build that CI's browser legs reuse.
# Usage: qa/web/web_build_stamp.sh write|verify
# Both modes print the index.pck SHA-256. verify fails unless the build was
# exported from this exact checkout and every file matches, with none extra.
set -euo pipefail
PROJ="$(cd "$(dirname "$0")/../.." && pwd)"
HEAD_SHA="$(git -C "$PROJ" rev-parse HEAD)"
cd "$PROJ/build"
case "${1:-}" in
write)
	find web -type f | LC_ALL=C sort | xargs sha256sum >web-build.sha256
	printf '%s\n' "$HEAD_SHA" >web-build.commit
	;;
verify)
	recorded="$(cat web-build.commit)"
	if [ "$recorded" != "$HEAD_SHA" ]; then
		echo "::error::Web build was exported from $recorded, not this checkout $HEAD_SHA" >&2
		exit 1
	fi
	sha256sum --quiet --strict -c web-build.sha256
	if ! diff <(find web -type f | LC_ALL=C sort) <(awk '{print $2}' web-build.sha256) >&2; then
		echo "::error::Web build files differ from the recorded export" >&2
		exit 1
	fi
	;;
*)
	echo "usage: web_build_stamp.sh write|verify" >&2
	exit 2
	;;
esac
awk '$2 == "web/index.pck" {print $1}' web-build.sha256 | grep -E '^[0-9a-f]{64}$'
