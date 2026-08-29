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
before this tap can point at it. `escpost` depends on `escpost-render` and
`escpost-profiles` at the same workspace version, and crates.io refuses a crate
whose dependencies it does not yet have, so the publish order matters.

1. In the ESCPost repository, build the frontend and publish, in order:

   ```sh
   just frontend-build
   cargo publish -p escpost-render
   cargo publish -p escpost-profiles
   cargo publish -p escpost          # or: just publish
   ```

2. Confirm the crate carries the bundle:

   ```sh
   curl -sL https://static.crates.io/crates/escpost/escpost-<version>.crate \
     | tar tz | grep frontend/dist
   ```

3. Get the digest Homebrew must verify:

   ```sh
   curl -sL https://static.crates.io/crates/escpost/escpost-<version>.crate \
     | sha256sum
   ```

4. Update `url` and `sha256` in `Formula/escpost.rb`, then verify before
   pushing:

   ```sh
   brew style Formula/escpost.rb
   brew audit --strict --online receiptful/tap/escpost
   brew install --build-from-source receiptful/tap/escpost
   brew test receiptful/tap/escpost
   ```

Existing users pick the release up through `brew update && brew upgrade escpost`.

## Working on this tap locally

Symlink the checkout into Homebrew's tap directory so `brew` resolves
`receiptful/tap/escpost` from your working tree:

```sh
ln -sfn "$PWD" "$(brew --repo)/Library/Taps/receiptful/homebrew-tap"
```

Remove it with `rm "$(brew --repo)/Library/Taps/receiptful/homebrew-tap"`.

## License

Each packaged project keeps its own license. ESCPost is Apache-2.0.
