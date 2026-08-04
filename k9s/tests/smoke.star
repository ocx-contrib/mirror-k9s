# k9s/tests/smoke.star — stable across upstream k9s releases.
# Asserts the contract (exit codes, version shape, a real on-disk side effect),
# never help/version prose. See ocx.mirror testing-practices.md.
#
# k9s is a FULL-SCREEN Kubernetes TUI. Its headline behaviour — the terminal
# UI over a live cluster — is not testable hermetically (it needs a real
# apiserver AND a real terminal), and worse, if a leg ever reaches terminal
# initialisation it can block forever waiting on a console that a CI runner's
# piped stdio does not provide. So nothing here may enter the alternate screen.
#
# k9s ships exactly two genuinely non-TUI subcommands, and both are used below:
#
#   k9s version --short   prints version/commit/date and exits
#   k9s info              prints the config/log paths, CREATES the config tree
#                         on disk, and exits
#
# `K9S_CONFIG_DIR` / `K9S_LOGS_DIR` redirect every path k9s owns into the test
# scratch sandbox, so the run never reads or writes a real user config — on a
# developer laptop or a CI runner alike. `ocx.run(env=…)` is an OVERLAY on the
# composed bundle env (env_clear + base + overlay), so PATH and the rest
# survive.

K9S = "k9s.exe" if ocx.target_platform.os == ocx.os.Windows else "k9s"

# Scratch-relative names. `k9scfg` is a token k9s would never emit on its own,
# which is what makes the `contains` assertion below meaningful.
CFG_DIR = "k9scfg"
LOG_DIR = "k9slogs"

K9S_ENV = {
    "K9S_CONFIG_DIR": ocx.scratch_root + "/" + CFG_DIR,
    "K9S_LOGS_DIR": ocx.scratch_root + "/" + LOG_DIR,
}

# ── Tier 1 + 2: liveness on the composed PATH + version SHAPE ───────────────
# `version --short` is the plain-text form; the full `version` subcommand wraps
# its labels in SGR escapes. The digits are the contract; the banner and the
# vendor prose around them are not.
r_version = ocx.run(K9S, "version", "--short", env=K9S_ENV)
expect.ok(r_version)
expect.matches(r_version.stdout, r"\d+\.\d+\.\d+")

# ── The TUI must never open, and here is the proof ─────────────────────────
# This is the BARE entry point — the invocation that launches the full-screen
# UI — forced to die in cobra's flag parsing, which runs before k9s's own Run
# and therefore before any terminal initialisation. Two assertions:
#
#   * non-zero exit — this is also the NEGATIVE CONTROL for the whole file. A
#     binary that did nothing and exited 0 on everything would pass every other
#     check here; it cannot pass this one.
#   * EMPTY stdout — entering the alternate screen announces itself with a CSI
#     burst on stdout, so an empty stdout is positive evidence that no terminal
#     was ever taken over. cobra writes the error and the usage block to
#     stderr, measured on 0.50.17, 0.50.18 and 0.51.0.
r_bogus = ocx.run(K9S, "--ocx-not-a-real-flag", env=K9S_ENV)
expect.ne(r_bogus.exit_code, 0)
expect.eq(r_bogus.stdout, "")

# ── Tier 3: a real, observable on-disk side effect ─────────────────────────
# The config tree must not pre-exist, or the assertions below would pass
# against something this run did not do. This is what makes the check
# falsifiable rather than habitual.
expect.false(ocx.exists(CFG_DIR))

r_info = ocx.run(K9S, "info", env=K9S_ENV)
expect.ok(r_info)
expect.matches(r_info.stdout, r"\d+\.\d+\.\d+")

# k9s honoured K9S_CONFIG_DIR: every path it reports is rooted at our scratch
# directory. Asserted as the single unbroken token `k9scfg` rather than a full
# path — the reported paths are plain text inside a colourised listing, and
# Windows normalises the separators. This is the only assertion proving the run
# is hermetic: were the env var ignored, k9s would silently write into the
# host's real user config and everything below would still pass.
expect.contains(r_info.stdout, CFG_DIR)

# … and it actually materialised the tree, which a binary that merely printed
# paths could not do. These four subdirectories are created by `info` itself on
# 0.50.17, 0.50.18 and 0.51.0 alike.
expect.true(ocx.exists(CFG_DIR + "/skins"))
expect.true(ocx.exists(CFG_DIR + "/clusters"))
expect.true(ocx.exists(CFG_DIR + "/benchmarks"))
expect.true(ocx.exists(CFG_DIR + "/screen-dumps"))
