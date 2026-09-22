# Homebrew formula for the Ray headless CLI.
#
# Installs the FULL self-contained bundle produced by
# packaging/cli/build-cli-bundle.sh (`ray-headless-<platform>-<version>.tar.gz`) -
# the engine (ray-server) + client (ray-cli) + all vendored Qt/FFmpeg/TLS libs and
# the `ray` launcher. It is NOT the thin `ray-cli` client. Works on macOS (Apple
# silicon) and on Linuxbrew (x86_64).
class RayHeadless < Formula
  desc "On-device subtitles, translation, narration, and stem separation"
  homepage "https://techspecs.io/ray"
  version "4.0.15-beta.1"
  # Ray is proprietary software; there is no OSI license identifier to declare.
  license :cannot_represent

  on_macos do
    on_arm do
      url "https://github.com/techspecs/ray-headless/releases/download/4.0.15-beta.1/ray-headless-macos-arm64-4.0.15-beta.1.tar.gz"
      sha256 "8e490b4a384733a27b8fbd57e08b4ee5c86d1a3719093d8a82ed4b2c9059c1b1"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/techspecs/ray-headless/releases/download/4.0.15-beta.1/ray-headless-linux-x64-4.0.15-beta.1.tar.gz"
      sha256 "741a2a458a4f18eb9c7fcab75773f68a42a056b8fa7e98932bdccc85cfa523c2"
    end
    # NOTE: linux-arm64 bundles are not published yet. Add an on_arm block here
    # once packaging/cli/build-cli-bundle.sh emits a linux-arm64 artifact.
  end

  # The bundle's Mach-O install names are already relative and every binary is
  # Developer ID signed. Rewriting @rpath IDs makes Homebrew ad-hoc re-sign the
  # affected libraries, which then fails hardened-runtime library validation.
  preserve_rpath

  def install
    # Homebrew extracts the tarball and chdir's into its single top-level
    # `ray-headless/` directory, so the bundle contents (ray, bin/, lib/, share/)
    # are the current directory. Install the whole self-contained tree under
    # libexec; nothing in it belongs directly on PATH except the launcher.
    libexec.install Dir["*"]

    # Put the launcher on PATH. `ray` follows the symlink back to its bundle root
    # (libexec) to locate bin/ and lib/, so a symlink is all that is needed - do
    # NOT copy the launcher out of the bundle.
    bin.install_symlink libexec/"ray"
  end

  def caveats
    <<~EOS
      Ray runs fully on-device. Before first use, sign in once:

        ray login

      (Ray emails you a sign-in code, or pass a Developer API key: ray login KEY.)

      Models download on demand the first time you generate,
      into:

        ${XDG_DATA_HOME:-$HOME/.local/share}/ray/models

      Override the model/results locations with RAY_MODEL_ROOT and
      RAY_DEVAPI_RESULTS_DIR. Run `ray help` for the full command list, or point
      `ray api ...` at a remote server with RAY_API_URL=http://host:port.
    EOS
  end

  test do
    # `ray version` runs entirely offline (execs the bundled engine/client with
    # the launcher's vendored library path) and prints a dotted version string.
    assert_match(/\d+\.\d+/, shell_output("#{bin}/ray version"))
  end
end
