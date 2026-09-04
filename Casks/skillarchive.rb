cask "skillarchive" do
  version "1.0.2"
  sha256 "3b541d422cd7d9a709108ebab71963eb49d6d7611ba30129275933c30fac3350"

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
