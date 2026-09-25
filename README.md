# ucore-images

BlueBuild recipes for the home fleet's [uCore](https://github.com/ublue-os/ucore)
images. One repo, one CI pipeline, one shared base — thin per-host images on top.

## Images

| Image | Base | For |
|---|---|---|
| `ucore-common` | `ghcr.io/ublue-os/ucore:stable` | Shared fleet base: extra packages, hardening files, common unit state |
| `ucore-beelzebot` | `ghcr.io/gbagnoli/ucore-common:latest` | beelzebot (was: boxy) |
| `ucore-clamps` | `ghcr.io/gbagnoli/ucore-common:latest` | clamps, the home server (Beelink Mini S13) |
| `ucore-bender` | `ghcr.io/gbagnoli/ucore-common:latest` | bender (future host; was: calculon) |

All images are published to `ghcr.io/gbagnoli/<name>` and signed with cosign.

### What lives here (the OS layer)

- **Packages** (`dnf` module in `ucore-common`): `wol` (Wake-on-LAN sender —
  the old wrapper script is gone, the distro tool replaces it), `et`
  (EternalTerminal server; package name is `et` in Fedora).
- **Static files** (`files/system/` → `/`): sysctl hardening
  (`etc/sysctl.d/99-hardening.conf`), SSH server/client hardening
  (`etc/ssh/sshd_config`, `etc/ssh/ssh_config`).
- **Unit state** (`systemd` module): `et.service` and `podman-auto-update.timer`
  enabled everywhere; `systemd-resolved` masked on clamps so Pi-hole owns port 53.

### What does NOT live here

Everything with a secret, a hostname, or a fast iteration loop stays in
**skillet**: credentials → podman secrets, per-host values (LAN IPs, domains,
DNS records), quadlets/containers, and config that changes often (nginx vhosts,
btrbk config). Skillet is idempotent, so files baked into the image that it
also manages (sysctl, sshd) simply become no-ops there.

## Setup

1. **Create the GitHub repo** (e.g. `gbagnoli/ucore-images`) and push this.
   Based on [blue-build/template](https://github.com/blue-build/template).

2. **Signing.** Generate a cosign keypair (do this on your own machine):
   ```
   cosign generate-key-pair
   ```
   Commit `cosign.pub` at the repo root, and add the *private* key content as a
   repository secret named `SIGNING_SECRET`. Never commit the private key
   (`.gitignore` already excludes it).

3. **Build ordering.** The per-host images use `ucore-common` as their base
   (`FROM ghcr.io/gbagnoli/ucore-common:latest`). The workflow builds in two
   serialized jobs — `build-common` first, then `build-hosts` (`needs:`) — so
   dependents always build on the common image published by the same run.
   Daily scheduled builds keep everything fresh afterwards.

## Rebasing a host

On a machine already running uCore:

```
# first rebase only (installs the signing policy from the image):
sudo rpm-ostree rebase --reboot ostree-unverified-registry:ghcr.io/gbagnoli/ucore-<host>:latest
# then switch to the signed image:
sudo rpm-ostree rebase --reboot ostree-image-signed:docker://ghcr.io/gbagnoli/ucore-<host>:latest
```

After that, `rpm-ostree upgrade` picks up new builds. Secure Boot still needs
the ublue-os MOK enrolled before the first reboot (these images inherit ublue's
signed kernel/shim).

## Local builds

Install the [BlueBuild CLI](https://blue-build.org/install/), then:

```
bluebuild build recipes/ucore-common.yml
```
