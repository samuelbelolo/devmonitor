import Foundation
@testable import DevMonitorCore

/// Builds a service located in a project from its member processes, the first one being the root.
/// @example service([snap(40, parent: 1, path: "/bin/pnpm")], project: "shop").id // "40-100"
func service(_ members: [ProcessSnapshot], project: String = "shop", mcp: Bool = false) -> Service {
    let location = ProjectLocation(root: "/home/" + project, name: project, worktree: nil, package: nil)
    return Service(root: members[0], members: members, label: members[0].name, location: location, agent: nil, isMCP: mcp)
}
