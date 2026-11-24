#!/bin/bash

check() {
    return 0
}

depends() {
    echo systemd
}

install() {
    inst_simple "$moddir/skillet-boot-trial.timer" "$systemdsystemunitdir/skillet-boot-trial.timer"
    inst_simple "$moddir/skillet-boot-trial-expired.service" "$systemdsystemunitdir/skillet-boot-trial-expired.service"
    inst_multiple systemctl
    mkdir -p "$initdir$systemdsystemunitdir/initrd.target.wants"
    ln -s ../skillet-boot-trial.timer "$initdir$systemdsystemunitdir/initrd.target.wants/skillet-boot-trial.timer"
}
