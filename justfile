# Maintain the Receiptful Homebrew tap. Formulae live in Formula/.
# See README.md for how the escpost formula is built and released.

# List available recipes.
default:
    @just --list

# Rewrite the formula's url and sha256 for a version published to crates.io,
# then lint and audit the result. Waits for the release to reach the registry,
# then confirms the tarball matches the digest crates.io recorded and carries
# the paths the formula builds from.
#
# This edits your working tree only. Committing and pushing this repository is
# what reaches users.
[doc("Update the formula for a crates.io release and verify it.")]
bump version: (_bump version) check

[private]
_bump version:
    scripts/bump-formula {{version}}

# Update the formula for a crates.io release, verify it, then commit and push
# after showing you the change. Pushing is what makes the new version reachable
# through `brew install receiptful/tap/escpost`, so this is the step that
# actually releases; it asks before doing it.
#
# Resumable: a run that stopped after committing but before pushing leaves the
# release incomplete, so re-running offers the outstanding push rather than
# reporting that there is nothing to do.
[doc("Update the formula, then commit and push it after confirmation.")]
release version: (bump version)
    @edited=$(git diff --quiet -- Formula/escpost.rb || echo yes); \
     unpushed=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0); \
     if [ -z "$edited" ] && [ "$unpushed" = "0" ]; then \
       echo "Formula/escpost.rb already points at {{version}} and is pushed; nothing to release."; \
       exit 0; \
     fi; \
     if [ -n "$edited" ]; then \
       git --no-pager diff -- Formula/escpost.rb; \
     fi; \
     if [ "$unpushed" != "0" ]; then \
       echo; echo "Committed but not yet pushed:"; \
       git --no-pager log --oneline @{u}..HEAD; \
     fi; \
     printf '\nCommit and push this to receiptful/homebrew-tap? [y/N] '; \
     read -r reply; \
     case "$reply" in \
       [yY]|[yY][eE][sS]) ;; \
       *) echo "Aborted. Any formula edit is left in your working tree."; exit 1 ;; \
     esac; \
     if [ -n "$edited" ]; then \
       git add Formula/escpost.rb && git commit -m "escpost {{version}}"; \
     fi; \
     git push

# Lint and audit the formula. `brew audit` resolves the formula through the tap
# rather than from a path, so it reads whichever checkout brew has registered.
# Refuse to run when that is not this one, because auditing a stale clone would
# report success for a formula nobody changed.
[doc("Run brew style and brew audit against the formula.")]
check:
    @resolved="$(readlink -f "$(brew formula receiptful/tap/escpost 2>/dev/null)" 2>/dev/null)"; \
      expected="$(readlink -f "$(pwd)/Formula/escpost.rb")"; \
      test "$resolved" = "$expected" || { \
        echo "brew reads ${resolved:-no registered tap}, not $expected."; \
        echo "Run 'just link' so brew resolves this working tree."; \
        exit 1; }
    brew style Formula/escpost.rb
    brew audit --strict --online receiptful/tap/escpost

# Build and test the formula from source, exactly as a user would.
[doc("Install escpost from source and run its test block.")]
verify:
    brew install --build-from-source receiptful/tap/escpost
    brew test receiptful/tap/escpost

# Make brew read formulae from this checkout rather than its clone of GitHub,
# so edits take effect without pushing first. Replaces whatever is registered:
# `brew untap` refuses while a formula from the tap is installed, and `ln` into
# a surviving directory would nest a link inside it rather than replace it.
[doc("Point brew at this working tree instead of its GitHub clone.")]
link:
    @target="$(brew --repo)/Library/Taps/receiptful/homebrew-tap"; \
      rm -rf "$target"; \
      mkdir -p "$(dirname "$target")"; \
      ln -s "$(pwd)" "$target"; \
      resolved="$(readlink -f "$(brew formula receiptful/tap/escpost 2>/dev/null)" 2>/dev/null)"; \
      test "$resolved" = "$(readlink -f "$(pwd)/Formula/escpost.rb")" || { \
        echo "link failed: brew reads ${resolved:-nothing}"; exit 1; }; \
      echo "receiptful/tap now reads $(pwd)"

# Restore brew's own clone of this repository from GitHub.
[doc("Restore brew's GitHub clone of the tap.")]
unlink:
    rm -rf "$(brew --repo)/Library/Taps/receiptful/homebrew-tap"
    brew tap receiptful/tap
