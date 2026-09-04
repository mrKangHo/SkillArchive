import Foundation
import SwiftUI

/// Progress snapshot for a running batch operation (bulk backup/install), shown as a
/// progress bar so long-running iCloud-backed file I/O doesn't look like a hang.
struct BusyProgress: Equatable {
    var label: String
    var completed: Int
    var total: Int
    /// Name of the item currently being copied — set the moment an item starts (not when it
    /// finishes), since a single iCloud-backed skill folder can take several seconds to download
    /// and the bar needs to show *something* is happening during that wait, not just after.
    var currentItem: String
}

final class AppState: ObservableObject {
    @Published var catalog: [CatalogEntry] = []
    @Published var lastError: String?
    @Published var lastMessage: String?
    @Published var selectedAgentID: String?
    @Published var showSettings = false
    /// True while a scan or file operation is in flight — bulk buttons disable to avoid
    /// overlapping runs against the same canonical store.
    @Published var isBusy = false
    /// Set only while a scan is running, so the UI can show a "스캔 중…" state without
    /// hiding results that are already on screen from a previous scan.
    @Published var isScanning = false
    /// Set only while a batch (bulk backup/install) is running, carrying counts for a progress bar.
    @Published var busyProgress: BusyProgress?
    @Published var enabledAgentIDs: Set<String> {
        didSet { saveEnabledAgents() }
    }

    let projectStore = ProjectStore()
    let settingsStore = SettingsStore()
    private let enabledAgentsKey = "skillhub.enabledAgentIDs.v1"
    private let ioQueue = DispatchQueue(label: "skillhub.io", qos: .userInitiated)
    private let prefetchQueue = DispatchQueue(label: "skillhub.prefetch", qos: .utility, attributes: .concurrent)

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

    /// Scans every known location (canonical store, agent folders, project folders) off the
    /// main thread — these can live on iCloud Drive, where a cold read can block on a download,
    /// so doing this synchronously on launch/refresh made the whole window feel frozen.
    func rescan() {
        isScanning = true
        let projects = projectStore.projects
        let canonicalDir = settingsStore.canonicalDirURL
        ioQueue.async { [weak self] in
            let result = Scanner.buildCatalog(projects: projects, canonicalDir: canonicalDir)
            DispatchQueue.main.async {
                self?.catalog = result
                self?.isScanning = false
            }
        }
    }

    func agent(_ id: String) -> AgentLocation? {
        Registry.agents.first { $0.id == id }
    }

    /// Runs a single file operation off the main thread, showing it as a 1-item busyProgress
    /// (labelled with `itemName`) so a single iCloud-backed copy — which can itself take a few
    /// seconds — still shows live activity instead of just dimming buttons with no feedback.
    func run(_ block: @escaping () throws -> Void, label: String, itemName: String, success: String? = nil) {
        isBusy = true
        busyProgress = BusyProgress(label: label, completed: 0, total: 1, currentItem: itemName)
        ioQueue.async { [weak self] in
            do {
                try block()
                DispatchQueue.main.async {
                    self?.lastError = nil
                    if let success { self?.lastMessage = success }
                    self?.busyProgress = nil
                    self?.isBusy = false
                    self?.rescan()
                }
            } catch {
                DispatchQueue.main.async {
                    self?.lastError = error.localizedDescription
                    self?.busyProgress = nil
                    self?.isBusy = false
                }
            }
        }
    }

    func backup(_ entry: CatalogEntry) {
        guard entry.canonical == nil else { return }
        if let folder = entry.projectCopies.values.first ?? entry.agentCopies.values.first {
            run({ try Operations.backupToCanonical(folder, canonicalDir: self.settingsStore.canonicalDirURL) }, label: String(localized: "백업"), itemName: entry.name, success: String(localized: "\(entry.name) 백업 완료"))
        }
    }

    func promoteAllProjectSkills() {
        let items = catalog.compactMap { entry in entry.isPromotable ? entry.projectCopies.values.first : nil }
        let canonicalDir = settingsStore.canonicalDirURL
        runBatch(label: String(localized: "프로젝트 skill 전체 글로벌 승격"), items: items, itemName: \.name) { folder in
            try Operations.backupToCanonical(folder, canonicalDir: canonicalDir)
        }
    }

    func backupAllAgentSkills() {
        let items = catalog.compactMap { entry in entry.isBackupable ? entry.agentCopies.values.first : nil }
        let canonicalDir = settingsStore.canonicalDirURL
        runBatch(label: String(localized: "전체 백업"), items: items, itemName: \.name) { folder in
            try Operations.backupToCanonical(folder, canonicalDir: canonicalDir)
        }
    }

    func installAllToAllAgents() {
        struct InstallItem { let skillName: String; let agentID: String; let agentName: String }
        var items: [InstallItem] = []
        for entry in catalog where entry.canonical != nil {
            for id in entry.missingAgents where enabledAgentIDs.contains(id) {
                items.append(InstallItem(skillName: entry.name, agentID: id, agentName: agent(id)?.displayName ?? id))
            }
        }
        let canonicalDir = settingsStore.canonicalDirURL
        // iCloud-backed canonical skills can take seconds each to download — kick off every
        // download concurrently up front instead of waiting on them one at a time in the loop below.
        prefetchCloudDownloads(Set(items.map(\.skillName)).map { canonicalDir.appendingPathComponent($0) })
        runBatch(label: String(localized: "전체 설치"), items: items, itemName: { "\($0.skillName) → \($0.agentName)" }) { [weak self] item in
            guard let agent = self?.agent(item.agentID) else { return }
            try Operations.install(skillName: item.skillName, into: agent, canonicalDir: canonicalDir)
        }
    }

    /// Best-effort: ask iCloud to start downloading every file under these folders concurrently
    /// (fire-and-forget), so a later sequential copy loop over the same folders finds them
    /// already downloading/downloaded instead of paying for each download serially.
    private func prefetchCloudDownloads(_ urls: [URL]) {
        for url in urls {
            prefetchQueue.async { Operations.prefetchDownload(url) }
        }
    }

    /// Runs a batch of operations off the main thread, tolerating per-item failures
    /// (already-exists etc.) and publishing progress — including which item is currently
    /// running — so long-running installs/backups show live activity instead of looking hung.
    private func runBatch<T>(label: String, items: [T], itemName: @escaping (T) -> String, operation: @escaping (T) throws -> Void) {
        guard !items.isEmpty else {
            lastMessage = String(localized: "\(label): 대상 없음")
            return
        }
        isBusy = true
        busyProgress = BusyProgress(label: label, completed: 0, total: items.count, currentItem: itemName(items[0]))
        ioQueue.async { [weak self] in
            var firstError: Error?
            for (index, item) in items.enumerated() {
                DispatchQueue.main.async {
                    self?.busyProgress?.currentItem = itemName(item)
                }
                do {
                    try operation(item)
                } catch {
                    if firstError == nil { firstError = error }
                }
                let completed = index + 1
                DispatchQueue.main.async {
                    self?.busyProgress?.completed = completed
                }
            }
            DispatchQueue.main.async {
                self?.busyProgress = nil
                self?.isBusy = false
                self?.lastError = firstError?.localizedDescription
                self?.lastMessage = String(localized: "\(label) 완료")
                self?.rescan()
            }
        }
    }

    func install(_ entry: CatalogEntry, agentID: String) {
        guard entry.canonical != nil, let agent = agent(agentID) else { return }
        let canonicalDir = settingsStore.canonicalDirURL
        prefetchCloudDownloads([canonicalDir.appendingPathComponent(entry.name)])
        run({ try Operations.install(skillName: entry.name, into: agent, canonicalDir: canonicalDir) }, label: String(localized: "설치"), itemName: "\(entry.name) → \(agent.displayName)", success: String(localized: "\(entry.name) → \(agent.displayName) 설치 완료"))
    }

    func installToAllMissing(_ entry: CatalogEntry) {
        guard entry.canonical != nil else { return }
        let ids = entry.missingAgents.filter { enabledAgentIDs.contains($0) }
        let canonicalDir = settingsStore.canonicalDirURL
        prefetchCloudDownloads([canonicalDir.appendingPathComponent(entry.name)])
        runBatch(label: String(localized: "\(entry.name) 전체 agent 설치"), items: ids, itemName: { [weak self] id in self?.agent(id)?.displayName ?? id }) { [weak self] id in
            guard let agent = self?.agent(id) else { return }
            try Operations.install(skillName: entry.name, into: agent, canonicalDir: canonicalDir)
        }
    }

    func linkProject(_ entry: CatalogEntry, project: ProjectLocation) {
        guard entry.canonical != nil, let folder = entry.projectCopies[project] else { return }
        let canonicalDir = settingsStore.canonicalDirURL
        run({ try Operations.linkProjectToCanonical(name: entry.name, projectFolder: folder, canonicalDir: canonicalDir) }, label: String(localized: "심볼릭 링크로 교체"), itemName: entry.name, success: String(localized: "\(entry.name) 프로젝트 사본 → 심볼릭 링크로 교체 완료"))
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
        isBusy = true
        busyProgress = BusyProgress(label: String(localized: "백업 위치 이동"), completed: 0, total: 1, currentItem: oldURL.lastPathComponent)
        prefetchCloudDownloads([oldURL])
        ioQueue.async { [weak self] in
            do {
                try Operations.migrateCanonicalStore(from: oldURL, to: newURL)
                DispatchQueue.main.async {
                    self?.settingsStore.canonicalStorePath = newURL.path
                    self?.lastError = nil
                    self?.lastMessage = String(localized: "백업 위치 변경 완료")
                    self?.busyProgress = nil
                    self?.isBusy = false
                    self?.rescan()
                }
            } catch {
                DispatchQueue.main.async {
                    self?.lastError = error.localizedDescription
                    self?.busyProgress = nil
                    self?.isBusy = false
                }
            }
        }
    }

    func resetCanonicalStoreToDefault() {
        changeCanonicalStore(to: URL(fileURLWithPath: Registry.expand(Registry.defaultCanonicalStorePath)))
    }
}
