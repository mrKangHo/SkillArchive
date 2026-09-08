import Foundation

/// Persists the user-editable list of project skill folders across launches.
final class ProjectStore: ObservableObject {
    private let key = "skillhub.projectLocations.v1"

    @Published var projects: [ProjectLocation] {
        didSet { save() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([ProjectLocation].self, from: data),
           !decoded.isEmpty {
            self.projects = decoded
        } else {
            self.projects = Registry.defaultProjects
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func add(url: URL) {
        let name = url.deletingLastPathComponent().lastPathComponent
        let loc = ProjectLocation(projectName: name, path: url.path)
        if !projects.contains(where: { $0.path == loc.path }) {
            projects.append(loc)
        }
    }

    func remove(_ loc: ProjectLocation) {
        projects.removeAll { $0.id == loc.id }
    }
}
