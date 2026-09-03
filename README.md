# SkillArchive

A native macOS app that backs up and installs **Agent Skills** (`SKILL.md` folders) across every AI coding agent installed on your Mac — Claude Code, Cursor, Gemini CLI, Codex CLI, OpenCode, Factory, Grok CLI, CommandCode, Pi Agent, and any tool that follows the same `~/.<agent>/skills` convention.

Skills tend to end up scattered: some live in an agent's global skills folder, some are copied into individual project repos, and none of it survives an OS reinstall or a move to a new Mac. SkillArchive scans every known location, lets you promote project-local skills to a single **canonical store**, and re-installs that store into any agent you choose — on this Mac or a fresh one.

## Features

- **Cross-agent scan** — finds every skill in each agent's global folder and in project-local skill folders you add, and shows what's backed up vs. what's missing.
- **One canonical store** — a single folder (by default on iCloud Drive, so it survives an OS reinstall or a new Mac) that every agent installs from.
- **Promote / Back up / Install**, one skill at a time or in bulk for everything at once.
- **Per-agent install targets** — enable/disable which agents participate in bulk installs, or auto-detect which agents are actually present on the current machine.
- **Real app icons** where an agent has one installed, with a colored fallback glyph otherwise.
- **Configurable backup location** — change it any time from Settings; existing skills migrate automatically.
- **Localized** in Korean, English, and Japanese.

## Requirements

- macOS 13 (Ventura) or later

## Install

### Homebrew

This repo doubles as its own Homebrew tap (no separate `homebrew-*` repo):

```sh
brew tap mrKangHo/skillarchive https://github.com/mrKangHo/SkillArchive
brew install --cask skillarchive
```

### Manual

Download the latest `SkillArchive.app.zip` from [Releases](https://github.com/mrKangHo/SkillArchive/releases), unzip, and drag `SkillArchive.app` into `/Applications`.

> SkillArchive isn't notarized yet. On first launch, Gatekeeper may block it — right-click the app → **Open**, or run `xattr -cr /Applications/SkillArchive.app` once.

### Build from source

Requires Xcode 15+ (or the Swift 5.9+ toolchain) and [XcodeGen](https://github.com/yonaskolb/XcodeGen) if you want the `.xcodeproj`.

```sh
git clone https://github.com/mrKangHo/SkillArchive.git
cd SkillArchive

# Option A: open in Xcode
xcodegen generate
open SkillArchive.xcodeproj

# Option B: command line, no Xcode project needed
./build_app.sh
open SkillArchive.app
```

## How it works

- **Agents** are defined in `Sources/SkillArchive/Registry.swift` — each has a global skills path and an optional exclude list (for an agent's own built-in skills, which SkillArchive never touches).
- **Project skill folders** are added from the sidebar (`+`) and remembered across launches.
- **Promote to Global** copies a project-local skill into the canonical store (non-destructive — the project copy is untouched). A separate "Replace with Symlink" action can swap the project copy for a symlink back to the canonical one, if you want them to stay in sync.
- **Install** always copies (never symlinks) into an agent's folder, so each agent's copy is independent.
- Backup location lives in **Settings** — point it at iCloud Drive (default), a different Drive, or anywhere else; moving it migrates existing skills automatically.

## License

MIT — see [LICENSE](LICENSE).
