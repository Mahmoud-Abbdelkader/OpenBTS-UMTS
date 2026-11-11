#!/bin/sh

set -u

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
failures=0

check_command() {
	if command -v "$1" >/dev/null 2>&1; then
		printf 'OK      command: %s\n' "$1"
	else
		printf 'MISSING command: %s\n' "$1"
		failures=$((failures + 1))
	fi
}

check_module() {
	if pkg-config --exists "$1"; then
		printf 'OK      library: %s (%s)\n' "$1" "$(pkg-config --modversion "$1")"
	else
		printf 'MISSING library: %s\n' "$1"
		failures=$((failures + 1))
	fi
}

printf 'OpenBTS-UMTS preflight (no radio transmission is performed)\n'
printf 'Repository: %s\n\n' "$ROOT_DIR"

for command_name in autoconf automake aclocal libtoolize pkg-config make g++ sqlite3 uhd_find_devices; do
	check_command "$command_name"
done

if command -v pkg-config >/dev/null 2>&1; then
	for module_name in uhd libzmq libosip2 ortp libusb-1.0; do
		check_module "$module_name"
	done
fi

printf '\nBuild configuration:\n'
if [ -f "$ROOT_DIR/config.h" ]; then
	if grep -Fqx '#define HAVE_UHD 1' "$ROOT_DIR/config.h"; then
		printf 'OK      HAVE_UHD is enabled in config.h\n'
	else
		printf 'MISSING HAVE_UHD in config.h; rerun ./configure after installing UHD development files\n'
		failures=$((failures + 1))
	fi
else
	printf 'INFO    config.h not found; run ./autogen.sh and ./configure after installing dependencies\n'
fi

if [ -x "$ROOT_DIR/apps/OpenBTS-UMTS" ] && [ -x "$ROOT_DIR/TransceiverUHD/transceiver" ]; then
	printf 'OK      OpenBTS-UMTS and UHD transceiver binaries are present\n'
else
	printf 'INFO    build outputs are missing; run make after configuring the project\n'
fi

printf '\nUHD device discovery (read-only):\n'
if command -v uhd_find_devices >/dev/null 2>&1; then
	if uhd_find_devices; then
		printf 'INFO    If a USRP is listed, confirm its UHD name/model before attempting hardware use\n'
	else
		printf 'INFO    No device was detected or UHD discovery failed; hardware is optional for this preflight\n'
	fi
else
	printf 'INFO    Skipping device discovery because uhd_find_devices is not installed\n'
fi

if [ "$failures" -gt 0 ]; then
	printf '\nPreflight found %s missing requirement(s).\n' "$failures"
	exit 1
fi

printf '\nSoftware preflight passed. Hardware compatibility remains unverified until the USRP is connected.\n'
