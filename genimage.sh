#!/usr/bin/env bash
# shellcheck disable=SC1090
# shellcheck disable=SC1091

set -e # exit if any command fails

# Set defaults for configurable behavior

# Controls production of a bz2-compressed image
compress_bz2=1

# Controls production of an xz-compressed image
compress_xz=1

# If a configuration file exists, import its settings
if [ -r buildroot.conf ]; then
	source <(tr -d "\015" < buildroot.conf)
fi

build_dir=build_dir

version_tag="$(git describe --exact-match --tags HEAD 2>/dev/null || true)"
version_commit="$(git rev-parse --short "@{0}" 2>/dev/null || true)"
if [ -n "${version_tag}" ]; then
	imagename="raspberrypi-ua-netinst-${version_tag}"
elif [ -n "${version_commit}" ]; then
	imagename="raspberrypi-ua-netinst-git-${version_commit}"
else
	imagename="raspberrypi-ua-netinst-$(date +%Y%m%d)"
fi
export imagename

image="${build_dir}/${imagename}.img"

# Prepare
cat > "${build_dir}/genimage.cfg" <<'EOF'
image raspberrypi-ua-netinst.img {
  hdimage {
    partition-table-type = "dos"
  }

  partition boot {
    partition-type = 0x0c
    bootable = true
    image = "boot.vfat"
  }
}

image boot.vfat {
  size = 128M
  vfat {
  	label = "RPI-NETINST"
  }
}
EOF

# Create image
genimage \
	--rootpath "${build_dir}/bootfs" \
	--outputpath "${build_dir}" \
	--config "${build_dir}/genimage.cfg"

mv "${build_dir}/raspberrypi-ua-netinst.img" "${image}"

# Create archives

if [ "$compress_xz" = "1" ]; then
	rm -f "${image}.xz"
	if ! xz -9v --keep "${image}"; then
		echo "WARNING: Could not create '${image}.xz' variant." >&2
	fi
	rm -f "${imagename}.img.xz"
	mv "${image}.xz" ./
fi

if [ "$compress_bz2" = "1" ]; then
	rm -f "${imagename}.img.bz2"
	( bzip2 -9v > "${imagename}.img.bz2" ) < "${image}"
fi

# Cleanup

if [ "$compress_xz" = "1" ] || [ "$compress_bz2" = "1" ]; then
	rm -f "${image}" "${build_dir}/boot.vfat"
fi
