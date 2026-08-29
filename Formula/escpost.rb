class Escpost < Formula
  desc "ESC/POS developer toolbox for receipt and label printers"
  homepage "https://escpost.dev"
  url "https://static.crates.io/crates/escpost/escpost-0.2.1.crate"
  sha256 "5056166467c4824d53f887b3ab9f11d0b385d7d12353c2dac851a264c42f3dc1"
  license "Apache-2.0"

  # A git checkout has no frontend/dist, so a head build must produce one.
  head do
    url "https://github.com/receiptful/escpost.git", branch: "main"

    depends_on "bun" => :build
  end

  depends_on "rust" => :build

  def install
    # The crates.io tarball ships the built web app under frontend/dist/, which
    # build.rs requires and rust-embed compiles into the release binary. Its
    # sources travel with it for auditing but are never read during this build,
    # so a stable build needs no Bun or Node toolchain.
    if build.head?
      cd "crates/escpost/frontend" do
        system "bun", "install", "--frozen-lockfile"
        system "bun", "run", "build"
      end
      system "cargo", "install", *std_cargo_args(path: "crates/escpost")
    else
      system "cargo", "install", *std_cargo_args
    end
  end

  test do
    # A head build reports the upstream version, not Homebrew's HEAD-<sha>.
    expected = version.head? ? "escpost" : version.to_s
    assert_match expected, shell_output("#{bin}/escpost --version")

    # The profile catalog is compiled into the binary, so listing it proves the
    # embedded pack survived packaging.
    catalog = shell_output("#{bin}/escpost profiles list --json --non-interactive")
    assert_match "REFERENCE", catalog

    # Render a short ESC/POS stream to PNG: initialise, emphasise a line, cut.
    (testpath/"job.hex").write <<~HEX
      1b 40
      1b 45 01 45 53 43 50 4f 53 1b 45 00 0a
      1d 56 00
    HEX

    system bin/"escpost", "render", testpath/"job.hex",
           "--profile", "REFERENCE",
           "--output", testpath/"job.png",
           "--non-interactive"

    assert_path_exists testpath/"job.png"
    assert_equal "\x89PNG\r\n\x1a\n".b, (testpath/"job.png").binread(8)
  end
end
