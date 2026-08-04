# mirror-k9s

OCX mirror for [k9s](https://github.com/derailed/k9s), a terminal UI for
Kubernetes. One repository, one spec directory per package.

| Package | Spec | Publishes to | Announced as | Upstream SPDX |
|---|---|---|---|---|
| [k9s](https://github.com/derailed/k9s) | [`k9s/mirror.yml`](k9s/mirror.yml) | `ghcr.io/ocx-contrib/k9s/k9s` | [`ocx.sh/k9s/k9s`](https://index.ocx.sh/k9s/k9s) | `Apache-2.0` |

Each upstream release is discovered, re-bundled, smoke-tested per
`(version, platform)` and only then pushed with cascade tags, after which the
result is announced into the OCX index.

`derailed` is a personal handle rather than a vendor identity, so the tool
names itself: the package is `k9s/k9s`. Provenance lives in the index claim's
`upstream` block, not in the namespace.

## Layout

```
k9s/
├── mirror.yml          the spec — never at the repo root
├── metadata.json       bundle interface
├── CATALOG.md          → ocx package describe
├── logo.svg / logo.png describe assets, 512px PNG
└── tests/smoke.star    Starlark smoke test
```

`LICENSE` and `NOTICE.md` are shared at the root. Logos are **not** — each
package carries its own, because a repo-root `logo.*` sits in no workflow's
`paths:` filter, so replacing it would publish nothing until some unrelated
edit happened to fire.

There is **no `mirror-base.yml`** and no `extends:` chain: every key this
single package needs is package-owned. That is deliberate — `extends:` is a
shallow merge of top-level keys, and a spec that restates `platforms:` to
change one runner drops every `containers:` entry with it while nothing reds.
With one spec there is nothing to merge and the trap does not exist. A second
package here would move the genuinely repo-wide keys into a base; that is a
content move, not a rename, and changes no generated workflow filename.

## Platforms

`k9s` publishes six platform entries: both Linux arches, both macOS arches and
both Windows arches. All six are shipped by upstream on every in-range release.

Upstream builds are **static Go binaries**. Measured with `file` / `readelf` on
both declared Linux arches at both ends of the mirrored range — 0.50.17,
0.50.18 and 0.51.0 — all six show no `PT_INTERP`, no `DT_NEEDED` and no
versioned GLIBC symbol references at all, and `readelf -h` confirms real
section headers (i.e. not a UPX stub faking a static verdict). `os.features`
states what an artifact requires *of the host*, so both Linux keys are
**bare**: `+libc.glibc` would hide the package from every musl host and
`+libc.musl` from every glibc host, and neither is true. The `alpine:3.20`
container leg on both arches is what turns that claim into evidence; the
measurement transcript is recorded above the `assets:` block in
`k9s/mirror.yml`.

Upstream also publishes `armv7`, `ppc64le` and `s390x` Linux archives, FreeBSD
archives, and `.apk`/`.deb`/`.rpm` distro sidecars. ocx expresses exactly
`amd64` and `arm64`, so none of the extra arches is a declarable platform, and
FreeBSD is not an OCX OS — the anchored `^…$` asset regexes are what keep all
of them out.

Three naming traps make those anchors load-bearing, and all three are defused
by end-anchoring on the archive extension while keeping the match
case-sensitive:

1. The OS token is **Title-case for the archives** (`k9s_Linux_amd64.tar.gz`)
   but **lowercase for the package-manager siblings in the same release**
   (`k9s_linux_amd64.apk`). A case-insensitive pattern matches both and the
   resolver hard-errors as ambiguous.
2. **Every archive has a same-named `.sbom.json` sidecar**
   (`k9s_Linux_amd64.tar.gz.sbom.json`), so a prefix-matching pattern hits two
   assets per platform.
3. `k9s_Freebsd_amd64.tar.gz` also ships, and must not fall through an
   OS-agnostic fragment.

Resolution was verified **both ways on every in-range release**: each pattern
matches exactly one asset, every time. A pattern matching zero would be
silently skipped rather than reported, so this check is not optional.

Asset names here are **not** version-suffixed — `k9s_Linux_amd64.tar.gz` is
identical in name across every release — so "does this asset belong to this
tag" cannot be answered from the filename. It was answered by extracting and
running each tag's binary: `k9s version --short` self-reports `v0.50.17`,
`v0.50.18` and `v0.51.0` respectively. No release re-ships a predecessor's
build.

## Editing

| File | Edit | Regenerate after |
|------|------|------------------|
| `k9s/mirror.yml` | hand | yes — see below |
| `k9s/{metadata.json,CATALOG.md,logo.*}` | hand | — |
| `k9s/tests/smoke.star` | hand | — |
| `.github/workflows/*.yml` | **generated — never hand-edit** | re-run when a spec changes |

```bash
ocx-mirror package pipeline generate ci --spec k9s/mirror.yml
```

**Name every spec.** `--spec` *appends* rather than replaces, so a command
naming a subset silently stops rendering the rest while staying green — and the
drift guard reds on a generated workflow the current spec set no longer
produces.

`verify-generated.yml` exits 65 on drift. If a generated workflow is wrong, the
spec or the renderer template is wrong — fix it there and regenerate.

Run `direnv allow` once to put the pinned toolchain on `PATH`, and invoke
`ocx-mirror` directly — never `ocx run -- ocx-mirror`, which pins
`OCX_BINARY_PIN` to the bootstrap `ocx` and false-reds the nested push.

## The binaries claim

`k9s/metadata.json` declares `binaries: ["k9s"]` by hand, and `k9s/mirror.yml`
sets `bin_scan: "off"` — forced, not preferred. The scan only inspects an
interface-visible `${installPath}/<dir>` PATH entry, and k9s's archives are
**flat**: `k9s` (`k9s.exe` on Windows), `LICENSE` and `README.md` sit at the
archive root with no subdirectory to point one at. With nothing to inspect the
scan would pass green whatever the archive contained, so `auto` and `verify`
both fail spec load at exit 65 rather than offer a hollow check. The
hand-written list is what the error message itself directs, and it is short and
stable — the binary is the only mode-0755 entry; the other two are 0644 data.

## The smoke test

k9s is a **full-screen TUI**. Its headline behaviour needs both a live
apiserver and a real terminal, and a leg that reaches terminal initialisation
can block forever on a runner whose stdio is a pipe. So the smoke test asserts
the two genuinely non-TUI contracts underneath it:

- `k9s version --short` — liveness on the composed PATH plus the version
  *shape* (`\d+\.\d+\.\d+`), never the vendor banner around it.
- `k9s info` with `K9S_CONFIG_DIR` / `K9S_LOGS_DIR` redirected into the test
  scratch sandbox — it prints those paths **and materialises the config tree**
  (`skins/`, `clusters/`, `benchmarks/`, `screen-dumps/`). The test asserts the
  tree did **not** pre-exist, then that all four directories appeared: a real
  on-disk side effect a binary that merely printed paths could not produce. It
  also asserts the reported paths contain the scratch-local token, which is the
  only thing proving the run is hermetic — were the env var ignored, k9s would
  write into the host's real user config and every other assertion would still
  pass.

The **negative control**, which is also the proof that no terminal was ever
taken over, is the bare entry point forced to die in cobra's flag parsing:
`k9s --ocx-not-a-real-flag` must exit non-zero **and** leave stdout exactly
empty. Entering the alternate screen announces itself with a CSI burst on
stdout, so an empty stdout is positive evidence the TUI never opened — and a
binary that did nothing and exited 0 on everything could not pass this check
even though it would pass all the others.

## Required secrets

| Secret | Use |
|--------|-----|
| `OCX_ANNOUNCE_TOKEN` | opens the index pull request from the `ocx-contrib/index` fork |
| `OCX_MIRROR_DISCORD_HOOK` | notify-stage Discord webhook URL |

(Inherited from the `ocx-contrib` org with visibility ALL. GHCR pushes use the
run's own `GITHUB_TOKEN` — no registry secret needed.)

## License

Apache-2.0 — see [`LICENSE`](LICENSE). Upstream assets are out of scope; the
redistribution license is recorded in [`NOTICE.md`](NOTICE.md). The logo is
upstream's own mark, scaled and centred — see `NOTICE.md`.
