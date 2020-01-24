import Vapor

struct GitHubWebhook {
    struct Label: Codable, Equatable {
        static var semverMajor: Label {
            .init(name: "semver-major")
        }
        static var semverMinor: Label {
            .init(name: "semver-minor")
        }
        static var semverPatch: Label {
            .init(name: "semver-patch")
        }
        let name: String
    }
    struct PullRequest: Codable {
        struct Base: Codable {
            let ref: String
        }
        let title: String
        let number: Int
        let body: String
        let labels: [Label]
        let merged_at: Date?
        let base: Base
    }
    struct Repository: Codable {
        struct Owner: Codable {
            let login: String
        }
        let name: String
        let owner: Owner
    }
    struct Notification: Codable {
        let action: String
        let pull_request: PullRequest?
        let repository: Repository?
    }
}
