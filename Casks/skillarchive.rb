cask "skillarchive" do
  version "1.0.1"
  sha256 "67ff265918090fecbfaad575f2aaf729a5787f1248cac51cf7107c392bc5c510"

  url "https://github.com/mrKangHo/SkillArchive/releases/download/v#{version}/SkillArchive.app.zip"
  name "SkillArchive"
  desc "Backup and install AI agent skills across every coding agent on your Mac"
  homepage "https://github.com/mrKangHo/SkillArchive"

  app "SkillArchive.app"

  postflight do
    # Ad-hoc signed, no Apple Developer ID — Gatekeeper reports a quarantined
    # download as "damaged" with no override. Clearing quarantine here is the
    # same fix a user would otherwise have to run by hand.
    system_command "/usr/bin/xattr",
                    args: ["-cr", "#{appdir}/SkillArchive.app"]
  end

  zap trash: [
    "~/Library/Preferences/local.skillarchive.plist",
  ]
end
