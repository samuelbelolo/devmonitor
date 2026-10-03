import DevMonitorCore
import Foundation

// Prints what the menu bar app would show, to check the grouping against the real machine.
let started = Date()
let scan = ProjectScan.run(containers: DockerCLI.containers(), resolver: RepoResolver())
for group in scan.groups {
    print("\(group.name)  \(DisplayFormat.memory(group.memoryBytes))  (\(group.processCount) process)")
    for service in group.services {
        let ports = service.ports.map { ":\($0)" }.joined(separator: " ")
        let place = [service.location.name, service.location.worktree, service.location.package].compactMap { $0 }.joined(separator: " · ")
        let flags = [service.isOrphan ? "orphan" : nil, service.agent?.displayName].compactMap { $0 }.joined(separator: ", ")
        print("  \(service.root.pid)  \(service.label)  \(ports)  \(DisplayFormat.memory(service.memoryBytes))  x\(service.members.count)  [\(place)]  \(flags)")
    }
    for container in group.containers {
        print("  docker  \(container.name)  \(DisplayFormat.memory(container.memoryBytes))")
    }
}
for session in scan.agentSessions {
    print("agent  \(session.process.pid)  \(session.agent.displayName)  \(session.version?.text ?? "?")  [\(session.location?.name ?? "outside any project")]")
}
print(String(format: "scan: %d process, %.0f ms", scan.processIdentities.count, Date().timeIntervalSince(started) * 1000))
