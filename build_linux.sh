#!/usr/bin/env bash
# Build ArmorPaint for Linux and package it as a downloadable tarball.
#
# Usage: ./build_linux.sh [--deps] [--test] [--debug]
#   --deps   install build (and, with --test, headless test) packages via apt
#   --test   smoke-test the build headless (Xvfb + Mesa lavapipe software Vulkan)
#   --debug  debug build instead of release
#
# Output: dist/ArmorPaint-linux-<arch>-<version>.tar.gz

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DEPS=0
TEST=0
MAKE_ARGS=(--compile)

for arg in "$@"; do
	case "$arg" in
		--deps) DEPS=1 ;;
		--test) TEST=1 ;;
		--debug) MAKE_ARGS+=(--debug) ;;
		-h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*) echo "Unknown option: $arg" >&2; exit 1 ;;
	esac
done

case "$(uname -m)" in
	x86_64) ARCH=x64 ;;
	aarch64*) ARCH=arm64 ;;
	*) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
	SUDO="sudo"
fi

if [ "$DEPS" -eq 1 ]; then
	echo "==> Installing dependencies"
	PKGS=(make clang libvulkan-dev libgtk-3-dev libssl-dev libxi-dev libxrandr-dev libxcursor-dev libasound2-dev)
	if [ "$TEST" -eq 1 ]; then
		PKGS+=(xvfb mesa-vulkan-drivers)
	fi
	# Unrelated third-party repos may fail to update; the install below is what matters
	$SUDO apt-get update || true
	$SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y "${PKGS[@]}"
fi

echo "==> Compiling"
cd "$ROOT/paint"
../base/make "${MAKE_ARGS[@]}"

OUT="$ROOT/paint/build/out"
if [ ! -x "$OUT/ArmorPaint" ]; then
	echo "Build failed: $OUT/ArmorPaint not found" >&2
	exit 1
fi

MISSING="$(ldd "$OUT/ArmorPaint" | grep "not found" || true)"
if [ -n "$MISSING" ]; then
	echo "Missing shared libraries:" >&2
	echo "$MISSING" >&2
	exit 1
fi

if [ "$TEST" -eq 1 ]; then
	echo "==> Smoke test (headless, 30s)"
	set +e
	(cd "$OUT" && timeout 30 xvfb-run -a -s "-screen 0 1920x1080x24" ./ArmorPaint)
	CODE=$?
	set -e
	# 124 = still running when timeout stopped it, which means it started fine
	if [ "$CODE" -ne 124 ]; then
		echo "Smoke test failed: ArmorPaint exited with code $CODE" >&2
		exit 1
	fi
	echo "Smoke test passed"
fi

echo "==> Packaging"
VERSION="$(git -C "$ROOT" describe --tags --always --dirty 2>/dev/null || echo dev)"
NAME="ArmorPaint-linux-$ARCH-$VERSION"
STAGE="$ROOT/dist/$NAME"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -r "$OUT/." "$STAGE/"

# The app loads data/ relative to the working directory, so launch from its own folder
cat > "$STAGE/armorpaint.sh" <<'EOF'
#!/usr/bin/env bash
cd "$(dirname "$(readlink -f "$0")")" && exec ./ArmorPaint "$@"
EOF
chmod +x "$STAGE/armorpaint.sh"

tar -C "$ROOT/dist" -czf "$ROOT/dist/$NAME.tar.gz" "$NAME"
rm -rf "$STAGE"

echo "==> Done: dist/$NAME.tar.gz"
