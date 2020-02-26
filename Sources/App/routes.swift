import Vapor

func routes(_ app: Application) throws {
    app.post("webhook") { req -> EventLoopFuture<HTTPStatus> in
        // Only accept pull_request events.
        guard req.headers.first(name: "X-GitHub-Event") == "pull_request" else {
            return req.eventLoop.makeSucceededFuture(.ok)
        }

        let notification = try req.content.decode(GitHubWebhook.Notification.self)
        if
            notification.action == "closed",
            let pr = notification.pull_request,
            pr.merged_at != nil,
            let repo = notification.repository,
            pr.base.ref == "master"
        {
            let bump: SemverVersion.Bump
            if pr.labels.contains(.semverMajor) {
                bump = .major
            } else if pr.labels.contains(.semverMinor) {
                bump = .minor
            } else if pr.labels.contains(.semverPatch) {
                bump = .patch
            } else {
                // If there is no semver label, then don't
                // tag this release.
                return req.eventLoop.makeSucceededFuture(.ok)
            }
            let acknowledgment: String
            if pr.user.login == pr.merged_by.login {
                acknowledgment = "This patch was authored and released by @\(pr.user.login)."
            } else {
                acknowledgment = "This patch was authored by @\(pr.user.login) and released by @\(pr.merged_by.login)."
            }
            return req.github.tagNextRelease(
                bump:  bump,
                owner: repo.owner.login,
                repo: repo.name,
                branch: pr.base.ref,
                name: pr.title,
                body: "\(pr.body)\n\n\(acknowledgment)"
            ).flatMap { release in
                let url = "https://github.com/\(repo.owner.login)/\(repo.name)/releases/tag/\(release.tag_name)"
                let comment = req.github.issues.create(
                    comment: .init(
                        body: "These changes are now available in [\(release.tag_name)](\(url))"
                    ),
                    owner: repo.owner.login,
                    repo: repo.name,
                    issue: pr.number
                )
                let discord = req.discord.post(to: .release, message: url)
                return discord.and(comment)
                    .transform(to: .ok)
            }
        } else {
            req.logger.info("Ignoring notification: \(notification.action)")
            return req.eventLoop.makeSucceededFuture(.ok)
        }
    }

    app.get("healthz") { req in
        HTTPStatus.ok
    }
}
