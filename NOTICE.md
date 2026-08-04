# NOTICE

This repository packages and redistributes upstream software published by the
[k9s](https://github.com/derailed/k9s) project. The Apache-2.0 license in
[`LICENSE`](LICENSE) covers the OCX pipeline files authored here. It does
**not** cover any upstream-derived asset — each package's redistributed bytes
carry their own license, recorded below.

The logo shipped in `k9s/logo.svg` / `k9s/logo.png` is **upstream's own mark**
(`assets/k9s.png` from the k9s repository), reproduced unmodified apart from
being scaled and centred on a 512×512 transparent canvas. It is used to
identify the mirrored software and no endorsement is implied.

| Package | GHCR path | Upstream SPDX |
|---|---|---|
| `k9s` | `ghcr.io/ocx-contrib/k9s/k9s` | `Apache-2.0` |

---

## `k9s`

Upstream: <https://github.com/derailed/k9s>
Published to `ghcr.io/ocx-contrib/k9s/k9s`.

| Component | SPDX | Holder |
|---|---|---|
| k9s (`k9s`) | **Apache-2.0** | Copyright © 2019 Imhotep Software LLC \<fernand@imhotep.io\> and other contributors |

Verified at the redistribution gate:

```
$ gh api repos/derailed/k9s/license --jq '{spdx: .license.spdx_id, name: .license.name}'
{"name":"Apache License 2.0","spdx":"Apache-2.0"}
```

The copyright holder above is taken verbatim from upstream's `COPYING` file,
which carries the attribution the bare `LICENSE` (an unmodified copy of the
Apache-2.0 text) does not.

The Apache License 2.0 grants redistribution of the work in source and object
form, on the conditions that recipients receive a copy of the license, that
modified files are marked, and that applicable attribution notices are
retained. Those conditions are met by construction: upstream's `LICENSE` file
ships **inside every mirrored archive**, at the archive root beside the binary,
and is republished unmodified as part of the bundle content.

The published binaries statically link third-party Go modules under permissive
licenses, enumerated in the `go.mod` / `go.sum` of the tagged upstream source
for each mirrored version. Upstream additionally publishes an SBOM sidecar per
release asset (`*.sbom.json`), which is not redistributed here.

No modifications are made to any upstream artifact in this repository; they are
republished byte-for-byte inside an OCX bundle.
