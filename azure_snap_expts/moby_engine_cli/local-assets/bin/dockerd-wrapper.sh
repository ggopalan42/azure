#!/bin/bash -e
# This wrapper script appears to be from here: https://github.com/docker-archive/docker-snap

default_socket_group=docker

aa_profile_reloaded="$SNAP_COMMON/profile_reloaded"

workaround_apparmor_profile_reload() {
    #https://github.com/docker/docker-snap/issues/4
    if [ ! -f "$aa_profile_refreshed" ]; then
        if [ "$(grep -c 'docker-default (enforce)' /sys/kernel/security/apparmor/profiles)" -ge 1 ]; then
            export DOCKER_AA_RELOAD=1
            touch "$aa_profile_reloaded"
        fi
    fi
}

workaround_lp1606510() {
    # ensure there's at least one member in the group.
    if [ $(getent group docker-snap | awk -F':' '{print $NF}') ]; then
        default_socket_group=docker-snap
    fi
}

yolo() {
	"$@" > /dev/null 2>&1 || :
}

force_umount() {
	yolo umount    "$@"
	yolo umount -f "$@"
	yolo umount -l "$@"
}

dir="$(mktemp -d)"
trap "force_umount --no-mtab '$dir'; rm -rf '$dir'" EXIT
# try mounting a few FS types to force the kernel to try loading modules
for t in aufs overlay zfs; do
	yolo mount --no-mtab -t "$t" /dev/null "$dir"
	force_umount --no-mtab "$dir"
done
# inside our snap, we can't "modprobe" for whatever reason (probably no access to the .ko files)
# so this forces the kernel itself to "modprobe" for these filesystems so that the modules we need are available to Docker
rm -rf "$dir"
trap - EXIT

# modify XDG_RUNTIME_DIR to be a snap writable dir underneath $SNAP_COMMON 
# until LP #1656340 is fixed
export XDG_RUNTIME_DIR=$SNAP_COMMON/run

# use SNAP_DATA for most "data" bits
mkdir -p \
	"$SNAP_DATA/run" \
	"$SNAP_DATA/run/docker" \
	"$SNAP_COMMON/var-lib-docker" \
	"$XDG_RUNTIME_DIR"

workaround_lp1606510

workaround_apparmor_profile_reload

exec dockerd \
	-G $default_socket_group \
	-H "unix://$SNAP_COMMON/run/docker.sock" \
	--exec-root="$SNAP_DATA/run/docker" \
	--data-root="$SNAP_COMMON/var-lib-docker" \
	--pidfile="$SNAP_DATA/run/docker.pid" \
	# --config-file="$SNAP_DATA/config/daemon.json" \
	"$@"
