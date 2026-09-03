import Foundation

enum Registry {

    /// Default backup location — overridable at runtime from Settings (see SettingsStore).
    static let defaultCanonicalStorePath = "~/Library/Mobile Documents/com~apple~CloudDocs/skillBackup/skills"

    /// AI agents known to support a filesystem "skills" folder, discovered on this machine.
    static let agents: [AgentLocation] = [
        AgentLocation(id: "claude", displayName: "Claude Code", globalSkillsPath: "~/.claude/skills", excludeNames: []),
        AgentLocation(id: "cursor", displayName: "Cursor", globalSkillsPath: "~/.cursor/skills", excludeNames: []),
        AgentLocation(id: "gemini", displayName: "Gemini CLI", globalSkillsPath: "~/.gemini/config/skills", excludeNames: []),
        AgentLocation(id: "codex", displayName: "Codex CLI", globalSkillsPath: "~/.codex/skills", excludeNames: [".system"]),
        AgentLocation(id: "opencode", displayName: "OpenCode", globalSkillsPath: "~/.opencode/skills", excludeNames: []),
        AgentLocation(id: "factory", displayName: "Factory", globalSkillsPath: "~/.factory/skills", excludeNames: []),
        AgentLocation(id: "grok", displayName: "Grok CLI", globalSkillsPath: "~/.grok/skills", excludeNames: []),
        AgentLocation(id: "commandcode", displayName: "CommandCode", globalSkillsPath: "~/.commandcode/skills", excludeNames: []),
        AgentLocation(id: "pi", displayName: "Pi Agent", globalSkillsPath: "~/.pi/agent/skills", excludeNames: []),
        AgentLocation(id: "universal", displayName: "Universal (~/.agents)", globalSkillsPath: "~/.agents/skills", excludeNames: []),
    ]

    /// Project folders that were found to contain their own local "skills" directory.
    /// Editable at runtime from the UI (Add Project Folder…); this is just the seed list.
    static let defaultProjects: [ProjectLocation] = [
        ProjectLocation(projectName: "recepie", path: expand("~/Documents/recepie/.agents/skills")),
        ProjectLocation(projectName: "SPARK (.claude)", path: expand("~/Documents/SPARK/.claude/skills")),
        ProjectLocation(projectName: "SPARK (.agents)", path: expand("~/Documents/SPARK/.agents/skills")),
        ProjectLocation(projectName: "clean-arch-checker (source)", path: expand("~/Documents/clean-arch-checker/skills")),
    ]

    static func expand(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }
}
