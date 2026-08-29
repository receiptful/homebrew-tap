# receiptful/homebrew-tap

Homebrew formulae for [Receiptful](https://github.com/receiptful) software.

## Install

```sh
brew install receiptful/tap/escpost
```

Homebrew taps this repository automatically, so no separate `brew tap` step is
needed.

Naming the full tap path is also what grants Homebrew permission to load the
formula. Since Homebrew 6.0 a third-party tap is untrusted until the user says
otherwise, and an explicit `receiptful/tap/escpost` counts as saying so. The
older two-step form uses the bare formula name, which does not, so it needs the
tap trusted first:

```sh
brew trust receiptful/tap
brew tap receiptful/tap
brew install escpost
```

Trust is recorded in `~/.homebrew/trust.json` (or `$XDG_CONFIG_HOME/homebrew/`).
Once escpost is installed through the tap-qualified command, later bare-name
operations such as `brew upgrade escpost` work without further prompting.

## Formulae

| Formula | Description |
| --- | --- |
| `escpost` | [ESCPost](https://github.com/receiptful/escpost), an ESC/POS developer toolbox for receipt and label printers |

## How the escpost formula builds

The formula's stable build takes its source from the crates.io release tarball
rather than a GitHub tag archive:

```
https://static.crates.io/crates/escpost/escpost-<version>.crate
```

ESCPost embeds a web app in its release binary. `crates/escpost/build.rs`
requires `frontend/dist/`, and `rust-embed` compiles that directory into the
binary. A GitHub tag archive omits `frontend/dist/` because git ignores it, so
building from a tag would force every user through a Bun and Node toolchain and
a network install of the npm dependency tree.

The crate tarball ships `frontend/dist/` instead, via the `include` list in
`crates/escpost/Cargo.toml`. The formula therefore needs only Rust, and the
install reduces to `cargo install`. The frontend *sources* — `frontend/src/`,
`package.json`, `bun.lock`, and the Vite and TypeScript configuration — ship in
the same tarball so the embedded bundle can be read and re-derived by anyone
inspecting the release. Nothing in the Homebrew build reads them.

`brew install --HEAD` builds from a git checkout, which has no bundle, so the
head spec additionally depends on `bun` and runs the frontend build first.

## Releasing a new version

The crate tarball is the release artifact, so ESCPost must reach crates.io
before this tap can point at it.

1. In the ESCPost repository, publish the release:

   ```sh
   just publish <version>
   ```

   That sets the workspace version, runs the tests, and — after asking —
   commits, tags, pushes, and uploads the crates in dependency order. It
   refuses to start from a dirty worktree, and rebuilds the frontend bundle so
   the crate carries it.

2. In this repository, update the formula and publish it to users:

   ```sh
   just release <version>
   ```

   This rewrites the formula, verifies it, shows you the change, and asks
   before committing and pushing. Pushing is what makes the new version
   reachable through `brew install`. Use `just bump <version>` instead to stop
   after the edit and verification, and commit yourself.

   Re-run it if a release stops partway. It works out what is outstanding, so
   an aborted prompt or a failed push resumes rather than reporting that there
   is nothing left to do.

Step 2 needs `just link` to have been run once in this repository; see
[Working on this tap locally](#working-on-this-tap-locally).

Existing users pick the release up through `brew update` and
`brew upgrade escpost`.

### What `just bump` does

`bump` waits for the release to reach crates.io, because `cargo publish`
returns before the crate is downloadable. It then reads the digest from the
registry rather than hashing the tarball itself: crates.io publishes
`version.checksum`, which is the SHA-256 of the `.crate` file Homebrew
downloads. It still fetches the tarball, to confirm it matches that digest and
carries `frontend/dist/index.html` — a crate published without the bundle would
fail `build.rs` on every user's machine, and this catches that here instead.
It rewrites the `url` and `sha256` lines, refusing to guess if either line does
not appear exactly once, then runs `check`.

`check` runs `brew style` and `brew audit --strict --online`. To also build and
test the formula the way a user would, run `just verify`, which takes as long
as a full Rust build.

`brew audit` resolves a formula through the tap rather than from a path, so it
reads whichever checkout Homebrew has registered — by default its own clone of
this repository, not this working tree. Auditing that clone after editing here
would check a file nobody changed, so `check` refuses to run unless Homebrew
resolves this checkout. Run `just link` once to arrange that; `just unlink`
restores the clone.

## Working on this tap locally

By default Homebrew reads formulae from its own clone of this repository, so
edits here have no effect until they are pushed. To make `brew` resolve
`receiptful/tap/escpost` from this working tree instead:

```sh
just link
```

`just unlink` restores Homebrew's own clone of this repository from GitHub. Run
`just` on its own to list every recipe.

## License

Each packaged project keeps its own license. ESCPost is Apache-2.0.
