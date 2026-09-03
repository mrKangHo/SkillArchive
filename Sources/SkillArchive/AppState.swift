import Foundation
import SwiftUI

final class AppState: ObservableObject {
    @Published var catalog: [CatalogEntry] = []
    @Published var lastError: String?
    @Published var lastMessage: String?
    @Published var selectedAgentID: String?
    @Published var showSettings = false
    @Published var enabledAgentIDs: Set<String> {
        didSet { saveEnabledAgents() }
    }

    let projectStore = ProjectStore()
    let settingsStore = SettingsStore()
    private let enabledAgentsKey = "skillhub.enabledAgentIDs.v1"

    init() {
        if let saved = UserDefaults.standard.array(forKey: "skillhub.enabledAgentIDs.v1") as? [String] {
            enabledAgentIDs = Set(saved)
        } else {
            enabledAgentIDs = Set(Registry.agents.map(\.id)) // default: every known agent participates
        }
        rescan()
    }

    private func saveEnabledAgents() {
        UserDefaults.standard.set(Array(enabledAgentIDs), forKey: enabledAgentsKey)
    }

    func setAgentEnabled(_ id: String, _ on: Bool) {
        if on { enabledAgentIDs.insert(id) } else { enabledAgentIDs.remove(id) }
    }

    /// Narrows bulk-install targets to agents actually present on this machine —
    /// handy right after restoring on a fresh OS/machine where not every agent is installed yet.
    func selectOnlyDetectedAgents() {
        enabledAgentIDs = Set(Registry.agents.filter(\.isInstalledOnDisk).map(\.id))
        lastMessage = String(localized: "감지된 agent \(enabledAgentIDs.count)개만 선택됨")
    }

    func selectAllAgents() {
        enabledAgentIDs = Set(Registry.agents.map(\.id))
    }

    func rescan() {
        catalog = Scanner.buildCatalog(projects: projectStore.projects, canonicalDir: settingsStore.canonicalDirURL)
    }

    func agent(_ id: String) -> AgentLocation? {
        Registry.agents.first { $0.id == id }
    }

    func run(_ block: () throws -> Void, success: String? = nil) {
        do {
            try block()
            lastError = nil
            if let success { lastMessage = success }
            rescan()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func backup(_ entry: CatalogEntry) {
        guard entry.canonical == nil else { return }
        if let folder = entry.projectCopies.values.first ?? entry.agentCopies.values.first {
            run({ try Operations.backupToCanonical(folder, canonicalDir: settingsStore.canonicalDirURL) }, success: String(localized: "\(entry.name) 백업 완료"))
        }
    }

    func promoteAllProjectSkills() {
        runBatch(label: String(localized: "프로젝트 skill 전체 글로벌 승격")) {
            for entry in catalog where entry.isPromotable {
                if let folder = entry.projectCopies.values.first {
                    try Operations.backupToCanonical(folder, canonicalDir: settingsStore.canonicalDirURL)
                }
            }
        }
    }

    func backupAllAgentSkills() {
        runBatch(label: String(localized: "전체 백업")) {
            for entry in catalog where entry.isBackupable {
                if let folder = entry.agentCopies.values.first {
                    try Operations.backupToCanonical(folder, canonicalDir: settingsStore.canonicalDirURL)
                }
            }
        }
    }

    func installAllToAllAgents() {
        runBatch(label: String(localized: "전체 설치")) {
            for entry in catalog where entry.canonical != nil {
                for id in entry.missingAgents where enabledAgentIDs.contains(id) {
                    guard let agent = agent(id) else { continue }
                    try Operations.install(skillName: entry.name, into: agent, canonicalDir: settingsStore.canonicalDirURL)
                }
            }
        }
    }

    /// Runs a batch of operations, tolerating per-item failures (already-exists etc.), then rescans once.
    private func runBatch(label: String, _ block: () throws -> Void) {
        do {
            try block()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        lastMessage = String(localized: "\(label) 완료")
        rescan()
    }

    func install(_ entry: CatalogEntry, agentID: String) {
        guard entry.canonical != nil, let agent = agent(agentID) else { return }
        run({ try Operations.install(skillName: entry.name, into: agent, canonicalDir: settingsStore.canonicalDirURL) }, success: String(localized: "\(entry.name) → \(agent.displayName) 설치 완료"))
    }

    func installToAllMissing(_ entry: CatalogEntry) {
        guard entry.canonical != nil else { return }
        for id in entry.missingAgents where enabledAgentIDs.contains(id) {
            guard let agent = agent(id) else { continue }
            run({ try Operations.install(skillName: entry.name, into: agent, canonicalDir: settingsStore.canonicalDirURL) })
        }
        lastMessage = String(localized: "\(entry.name) 전체 agent 설치 완료")
    }

    func linkProject(_ entry: CatalogEntry, project: ProjectLocation) {
        guard entry.canonical != nil, let folder = entry.projectCopies[project] else { return }
        run({ try Operations.linkProjectToCanonical(name: entry.name, projectFolder: folder, canonicalDir: settingsStore.canonicalDirURL) }, success: String(localized: "\(entry.name) 프로젝트 사본 → 심볼릭 링크로 교체 완료"))
    }

    func addProjectFolder(_ url: URL) {
        projectStore.add(url: url)
        rescan()
    }

    func removeProject(_ p: ProjectLocation) {
        projectStore.remove(p)
        rescan()
    }

    /// Change the backup location, moving any skills already stored at the old location
    /// into the new one first so nothing is orphaned.
    func changeCanonicalStore(to newURL: URL) {
        let oldURL = settingsStore.canonicalDirURL
        guard oldURL.path != newURL.path else { return }
        run({
            try Operations.migrateCanonicalStore(from: oldURL, to: newURL)
            settingsStore.canonicalStorePath = newURL.path
        }, success: String(localized: "백업 위치 변경 완료"))
    }

    func resetCanonicalStoreToDefault() {
        changeCanonicalStore(to: URL(fileURLWithPath: Registry.expand(Registry.defaultCanonicalStorePath)))
    }
}
