import Foundation

final class AppDIContainer: @unchecked Sendable {
    static let shared = AppDIContainer()

    public let projectStore: ProjectStore
    public let settingsStore: SettingsStore

    public let skillCatalogRepository: SkillCatalogRepositoryProtocol
    public let projectRepository: ProjectRepositoryProtocol
    public let settingsRepository: SettingsRepositoryProtocol

    public let scanCatalogUseCase: ScanCatalogUseCaseProtocol
    public let manageSkillUseCase: ManageSkillUseCaseProtocol
    public let manageProjectsUseCase: ManageProjectsUseCaseProtocol
    public let manageSettingsUseCase: ManageSettingsUseCaseProtocol

    private init() {
        let pStore = ProjectStore()
        let sStore = SettingsStore()

        self.projectStore = pStore
        self.settingsStore = sStore

        self.skillCatalogRepository = SkillCatalogRepositoryImpl()
        self.projectRepository = ProjectRepositoryImpl(store: pStore)
        self.settingsRepository = SettingsRepositoryImpl(store: sStore)

        self.scanCatalogUseCase = ScanCatalogUseCase(repository: self.skillCatalogRepository)
        self.manageSkillUseCase = ManageSkillUseCase(repository: self.skillCatalogRepository)
        self.manageProjectsUseCase = ManageProjectsUseCase(repository: self.projectRepository)
        self.manageSettingsUseCase = ManageSettingsUseCase(repository: self.settingsRepository)
    }

    func makeAppState() -> AppState {
        return AppState(
            scanCatalogUseCase: scanCatalogUseCase,
            manageSkillUseCase: manageSkillUseCase,
            manageProjectsUseCase: manageProjectsUseCase,
            manageSettingsUseCase: manageSettingsUseCase,
            projectStore: projectStore,
            settingsStore: settingsStore
        )
    }
}
