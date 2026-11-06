# ucore-images

BlueBuild recipes for the home fleet's [uCore](https://github.com/ublue-os/ucore)
images. One repo, one CI pipeline, one shared base — thin per-host images on top.

## Images

| Image | Base | For |
|---|---|---|
| `ucore-common` | `ghcr.io/ublue-os/ucore:stable` | Shared fleet base: extra packages, hardening files, common unit state |
| `ucore-joey` | `ghcr.io/gbagnoli/ucore-common:latest` | joey (was: boxy) |
| `ucore-clamps` | `ghcr.io/gbagnoli/ucore-common:latest` | clamps, the home server (Beelink Mini S13) |
| `ucore-donbot` | `ghcr.io/gbagnoli/ucore-common:latest` | donbot (future host; was: calculon) |

All images are published to `ghcr.io/gbagnoli/<name>` and signed with cosign.

### What lives here (the OS layer)

- **Packages** (`dnf` module in `ucore-common`): `wol` (Wake-on-LAN sender —
  the old wrapper script is gone, the distro tool replaces it), `et`
  (EternalTerminal server; package name is `et` in Fedora), `glibc-langpack-en`
  (English UTF-8 login/SSH locales), and `btrbk`
  (Btrfs snapshot tool, configured only by hosts that opt in through Skillet),
  `nut` and `nut-client` (native UPS protection for opted-in hosts),
  `postfix` (native SMTP relay), and `cyrus-sasl-plain` (SMTP authentication).
- **Static files** (`files/system/` → `/`): sysctl hardening
  (`etc/sysctl.d/99-hardening.conf`), SSH server/client hardening
  (`etc/ssh/sshd_config`, `etc/ssh/ssh_config`).
- **Unit state** (`systemd` module): `et.service` and `podman-auto-update.timer`
  enabled everywhere. An ET drop-in persists and activates TCP 2022 grants only
  for the standard Tailscale IPv4/IPv6 source ranges in the default firewall zone,
  without a firewall reload; Skillet additionally derives ET LAN grants from
  active hardware NIC addresses/netmasks. SSH TCP 22 retains the base zone's
  source-unrestricted allowance independently of Tailscale, and ET still requires
  SSH authentication. Existing grants
  are retained if policy changes, so remove obsolete grants explicitly. The
  package's daily `btrbk.timer` is masked so opted-in
  hosts use Skillet's guarded hourly timer; `systemd-resolved` masked on clamps and joey
  so Pi-hole owns port 53. `postfix.service` is disabled until Skillet delivers
  and applies encrypted SMTP configuration; a preset preserves that default.
  NUT services and driver enumeration are disabled by default. Skillet owns
  `/etc/ups`, per-host USB selection, loopback listeners and activation.

Donbot additionally ships `gpth` (Google Photos Takeout Helper), `rclone`, `jq`,
GNU Parallel, `rsync`, `tar`, `gzip`, `findutils`, `grep`, `file` and `wget` for
Takeout download/processing scripts. Bash and coreutils come from the base.
The x86_64 upstream `gpth` release and SHA-256 are pinned in
`files/scripts/install-gpth.sh`; update both together. Run `gpth --help` as the
ordinary user to process a Takeout export. No automatic photo processing occurs.
Scripts using a bundled `bin/gpth` continue to use that copy; select `/usr/bin/gpth`
or invoke `gpth` through PATH to use the image version. Configure rclone remotes
and credentials separately as the login user.

### What does NOT live here

Everything with a secret, a hostname, or a fast iteration loop stays in
**skillet**: credentials → podman secrets, per-host values (LAN IPs, domains,
DNS records), quadlets/containers, and private service configuration (Caddy routes, DNS records). Skillet is idempotent, so files baked into the image that it
also manages (sysctl, sshd) simply become no-ops there.

## Pinned Skillet artifacts

`skillet-release.json` locks a Skillet semantic version and full source commit.
Select a published annotated `skillet-v<version>` release. CI requires matching
publication, tag, Cargo version and commit, then builds from that exact commit.
Do not move/reuse published tags or select a moving version range. Follow the
[source release guide](https://github.com/gbagnoli/devmachine/blob/master/ublue/skillet/crates/workstation/docs/releases.md)
to generate the lock; publish the devmachine release before pushing this repository.
CI builds matching clean static binaries, renders public per-host trees, preserves
their modes in tar archives, and verifies each bundle before building its host image.
Generated `files/skillet-<host>` trees are ignored and must not be committed.

Host images receive `/usr/bin/skillet`, `/usr/bin/skillet-<host>`, caller-selected
btrbk config/ownership marker under `/usr/share/skillet/btrbk`, and vendor
`skillet-btrbk.service`/`.timer` under `/usr/lib/systemd/system`.
`/usr/share/skillet/release.json` records all artifact hashes and modes. General
`/var/usrlocal/bin` delivery and boot-unit references retain operational ownership.
The btrbk module explicitly retires verified legacy overrides and repoints timer
enablement; retain the migration-capable mutable caller for rollback reconciliation.
See the [migration guide](https://github.com/gbagnoli/devmachine/blob/master/ublue/skillet/crates/btrbk/README.md).
Private inputs remain runtime-owned.

For local host image builds, first generate the matching `files/skillet-<host>`
tree using the locked release's
[image bundle guide](https://github.com/gbagnoli/devmachine/blob/master/ublue/skillet/crates/workstation/docs/image-bundles.md),
then run `bluebuild build recipes/ucore-<host>.yml`. Common image builds need no
Skillet bundle. Missing host bundles intentionally fail rather than silently
building an image without its declared artifacts.

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
   (`FROM ghcr.io/gbagnoli/ucore-common:latest`). `build-common` and the pinned
   Skillet artifact build may run concurrently; `build-hosts` waits for both, so
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
