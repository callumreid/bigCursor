cask "bigcursor" do
  version "1.2.0"
  sha256 "b8a88f959b5f6067ec346a77647293a4c1b42d5907efe2ee34ff853ec6b65423"

  url "https://github.com/callumreid/bigCursor/releases/download/v#{version}/bigCursor.dmg"
  name "bigCursor"
  desc "Shake-to-enlarge cursor menu bar app"
  homepage "https://github.com/callumreid/bigCursor"

  depends_on macos: ">= :ventura"

  app "bigCursor.app"

  postflight do
    system_command "/usr/bin/xattr", args: ["-cr", "#{appdir}/bigCursor.app"]
  end

  caveats do
    <<~EOS
      bigCursor needs Accessibility permissions to track the mouse:
        System Settings → Privacy & Security → Accessibility
    EOS
  end
end
