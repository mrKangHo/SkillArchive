import Foundation
import SwiftUI

final class AppState: ObservableObject {
    @Published var catalog: [CatalogEntry] = []
    @Published var lastError: String?
    @Published var lastMessage: String?
    @Published var selectedAgentID: String?
    @Published var showSettings = false
    @Published var isBusy = false
    @Published var isScanning = false
    @Published var busyProgress: BusyProgress?
    @Published var enabledAgentIDs: Set<String> {
        didSet { manageSettingsUseCase.enabledAgentIDs = enabledAgentIDs }
    }

    public let projectStore: ProjectStore
    public let settingsStore: SettingsStore

    private let scanCatalogUseCase: ScanCatalogUseCaseProtocol
    private let manageSkillUseCase: ManageSkillUseCaseProtocol
    private let manageProjectsUseCase: ManageProjectsUseCaseProtocol
    private var manageSettingsUseCase: ManageSettingsUseCaseProtocol

    private let ioQueue = DispatchQueue(label: "skillhub.io", qos: .userInitiated)
    private let prefetchQueue = DispatchQueue(label: "skillhub.prefetch", qos: .utility, attributes: .concurrent)

    init(
        scanCatalogUseCase: ScanCatalogUseCaseProtocol = AppDIContainer.shared.scanCatalogUseCase,
        manageSkillUseCase: ManageSkillUseCaseProtocol = AppDIContainer.shared.manageSkillUseCase,
        manageProjectsUseCase: ManageProjectsUseCaseProtocol = AppDIContainer.shared.manageProjectsUseCase,
        manageSettingsUseCase: ManageSettingsUseCaseProtocol = AppDIContainer.shared.manageSettingsUseCase,
        projectStore: ProjectStore = AppDIContainer.shared.projectStore,
        settingsStore: SettingsStore = AppDIContainer.shared.settingsStore
    ) {
        self.scanCatalogUseCase = scanCatalogUseCase
        self.manageSkillUseCase = manageSkillUseCase
        self.manageProjectsUseCase = manageProjectsUseCase
        self.manageSettingsUseCase = manageSettingsUseCase
        self.projectStore = projectStore
        self.settingsStore = settingsStore

        self.enabledAgentIDs = manageSettingsUseCase.enabledAgentIDs
        rescan()
    }

    func setAgentEnabled(_ id: String, _ on: Bool) {
        if on { enabledAgentIDs.insert(id) } else { enabledAgentIDs.remove(id) }
    }

    func selectOnlyDetectedAgents() {
        enabledAgentIDs = Set(Registry.agents.filter(\.isInstalledOnDisk).map(\.id))
        lastMessage = String(localized: "감지된 agent \(enabledAgentIDs.count)개만 선택됨")
    }

    func selectAllAgents() {
        enabledAgentIDs = Set(Registry.agents.map(\.id))
    }

    func rescan() {
        isScanning = true
        let projects = manageProjectsUseCase.projects
        let canonicalDir = settingsStore.canonicalDirURL
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            let result = self.scanCatalogUseCase.execute(projects: projects, canonicalDir: canonicalDir)
            DispatchQueue.main.async {
                self.catalog = result
                self.isScanning = false
            }
        }
    }

    func agent(_ id: String) -> AgentLocation? {
        Registry.agents.first { $0.id == id }
    }

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
            run({ [weak self] in
                guard let self = self else { return }
                try self.manageSkillUseCase.backupToCanonical(folder, canonicalDir: self.settingsStore.canonicalDirURL)
            }, label: String(localized: "백업"), itemName: entry.name, success: String(localized: "\(entry.name) 백업 완료"))
        }
    }

    func promoteAllProjectSkills() {
        let items = catalog.compactMap { entry in entry.isPromotable ? entry.projectCopies.values.first : nil }
        let canonicalDir = settingsStore.canonicalDirURL
        runBatch(label: String(localized: "프로젝트 skill 전체 글로벌 승격"), items: items, itemName: \.name) { [weak self] folder in
            try self?.manageSkillUseCase.backupToCanonical(folder, canonicalDir: canonicalDir)
        }
    }

    func backupAllAgentSkills() {
        let items = catalog.compactMap { entry in entry.isBackupable ? entry.agentCopies.values.first : nil }
        let canonicalDir = settingsStore.canonicalDirURL
        runBatch(label: String(localized: "전체 백업"), items: items, itemName: \.name) { [weak self] folder in
            try self?.manageSkillUseCase.backupToCanonical(folder, canonicalDir: canonicalDir)
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
        prefetchCloudDownloads(Set(items.map(\.skillName)).map { canonicalDir.appendingPathComponent($0) })
        runBatch(label: String(localized: "전체 설치"), items: items, itemName: { "\($0.skillName) → \($0.agentName)" }) { [weak self] item in
            guard let agent = self?.agent(item.agentID) else { return }
            try self?.manageSkillUseCase.install(skillName: item.skillName, into: agent, canonicalDir: canonicalDir)
        }
    }

    private func prefetchCloudDownloads(_ urls: [URL]) {
        for url in urls {
            prefetchQueue.async { Operations.prefetchDownload(url) }
        }
    }

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
        run({ [weak self] in
            try self?.manageSkillUseCase.install(skillName: entry.name, into: agent, canonicalDir: canonicalDir)
        }, label: String(localized: "설치"), itemName: "\(entry.name) → \(agent.displayName)", success: String(localized: "\(entry.name) → \(agent.displayName) 설치 완료"))
    }

    func installToAllMissing(_ entry: CatalogEntry) {
        guard entry.canonical != nil else { return }
        let ids = entry.missingAgents.filter { enabledAgentIDs.contains($0) }
        let canonicalDir = settingsStore.canonicalDirURL
        prefetchCloudDownloads([canonicalDir.appendingPathComponent(entry.name)])
        runBatch(label: String(localized: "\(entry.name) 전체 agent 설치"), items: ids, itemName: { [weak self] id in self?.agent(id)?.displayName ?? id }) { [weak self] id in
            guard let agent = self?.agent(id) else { return }
            try self?.manageSkillUseCase.install(skillName: entry.name, into: agent, canonicalDir: canonicalDir)
        }
    }

    func linkProject(_ entry: CatalogEntry, project: ProjectLocation) {
        guard entry.canonical != nil, let folder = entry.projectCopies[project] else { return }
        let canonicalDir = settingsStore.canonicalDirURL
        run({ [weak self] in
            try self?.manageSkillUseCase.linkProjectToCanonical(name: entry.name, projectFolder: folder, canonicalDir: canonicalDir)
        }, label: String(localized: "심볼릭 링크로 교체"), itemName: entry.name, success: String(localized: "\(entry.name) 프로젝트 사본 → 심볼릭 링크로 교체 완료"))
    }

    func addProjectFolder(_ url: URL) {
        manageProjectsUseCase.add(url: url)
        rescan()
    }

    func removeProject(_ p: ProjectLocation) {
        manageProjectsUseCase.remove(p)
        rescan()
    }

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
