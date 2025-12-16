cask "bigcursor" do
  version "1.1.0"
  sha256 "b8947ee1554e9c9f8798115bd8c631229ee4148f183a865a4d278c9782a3449d"

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

