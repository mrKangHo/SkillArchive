import Foundation

protocol ProjectRepositoryProtocol: AnyObject {
    var projects: [ProjectLocation] { get }
    func add(url: URL)
    func remove(_ loc: ProjectLocation)
}
