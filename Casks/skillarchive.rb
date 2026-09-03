cask "skillarchive" do
  version "1.0.0"
  sha256 "PLACEHOLDER_SHA256"

  url "https://github.com/mrKangHo/SkillArchive/releases/download/v#{version}/SkillArchive.app.zip"
  name "SkillArchive"
  desc "Backup and install AI agent skills across every coding agent on your Mac"
  homepage "https://github.com/mrKangHo/SkillArchive"

  app "SkillArchive.app"

  zap trash: [
    "~/Library/Preferences/local.skillarchive.plist",
  ]
end
