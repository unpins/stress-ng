# stress-ng

[stress-ng](https://github.com/ColinIanKing/stress-ng) — stress tests a computer system with hundreds of CPU, memory, I/O, filesystem, network and kernel-interface stressors. A single self-contained binary, built natively for Linux and macOS.

[![CI](https://github.com/unpins/stress-ng/actions/workflows/stress-ng.yml/badge.svg)](https://github.com/unpins/stress-ng/actions)
![Linux](https://img.shields.io/badge/Linux-✓-success?logo=linux&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-✓-success?logo=apple&logoColor=white)

Part of the [unpins](https://unpins.org) catalog; install it with [`unpin`](https://github.com/unpins/unpin): `unpin install stress-ng`.

## Usage

Run the `stress-ng` program with [unpin](https://github.com/unpins/unpin):

```bash
unpin stress-ng --cpu 4 --timeout 60s --metrics-brief   # 4 CPU workers for a minute
unpin stress-ng --vm 2 --vm-bytes 1G --timeout 30s      # 2 workers thrashing 1 GB each
unpin stress-ng --stressors                             # list every stressor
```

To install it onto your PATH:

```bash
unpin install stress-ng
```

## Man pages

`stress-ng.1` is embedded in the binary — read it with `unpin man stress-ng`.

## Build locally

```bash
nix build github:unpins/stress-ng
./result/bin/stress-ng --version
```

Or run directly:

```bash
nix run github:unpins/stress-ng -- --version
```

The first invocation will offer to add the [unpins.cachix.org](https://unpins.cachix.org) substituter so most pulls come pre-built.

## Manual download

The [Releases](https://github.com/unpins/stress-ng/releases) page has standalone binaries for manual download.

## Build notes

- **Platforms:** Linux and macOS. Upstream supports Windows only through Cygwin or WSL, so there is no Windows build.
- **Stressors on macOS:** the Linux-only stressors (kernel modules, AppArmor, SCTP, async I/O, ACLs, …) are not available there; stress-ng skips them at run time.
- **`gpu` stressor:** not built. It drives the GPU through EGL/GLES and `gbm`, whose libraries load the vendor's graphics driver at run time and have no static build.
- **`ipsec-mb` stressor:** x86_64 Linux only — Intel's multi-buffer crypto library is written for x86_64.
