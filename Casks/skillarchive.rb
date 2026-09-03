cask "skillarchive" do
  version "1.0.1"
  sha256 "67ff265918090fecbfaad575f2aaf729a5787f1248cac51cf7107c392bc5c510"

  url "https://github.com/mrKangHo/SkillArchive/releases/download/v#{version}/SkillArchive.app.zip"
  name "SkillArchive"
  desc "Backup and install AI agent skills across every coding agent on your Mac"
  homepage "https://github.com/mrKangHo/SkillArchive"

  app "SkillArchive.app"

  zap trash: [
    "~/Library/Preferences/local.skillarchive.plist",
  ]
end
