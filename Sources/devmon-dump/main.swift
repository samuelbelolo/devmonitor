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
// Each session names the tracked account it draws on by its place in the app's list, never by its email.
let tracked = TrackedAccount.load(from: UserDefaults(suiteName: "local.devmonitor") ?? .standard).map(\.id)
let accountReader = SessionAccountReader()
var sessionsByAccount: [String: Int] = [:]
for session in scan.agentSessions {
    let environment = ProcessEnvironment.values(SessionAccountReader.variables, of: session.process.pid)
    let key = accountReader.accountKey(agent: session.agent, environment: environment)
    if let key { sessionsByAccount[key, default: 0] += 1 }
    let account = key.map { key in tracked.firstIndex(of: key).map { "account #\($0 + 1)" } ?? "an untracked account" } ?? "no account told"
    print("agent  \(session.process.pid)  \(session.agent.displayName)  \(session.version?.text ?? "?")  [\(session.location?.name ?? "outside any project")]  \(account)" + (session.launchedBy.map { "  launched by \($0.displayName)" } ?? ""))
}
for (index, key) in tracked.enumerated() {
    print("usage account #\(index + 1)  \(AccountID.provider(ofKey: key).rawValue)  \(sessionsByAccount[key] ?? 0) session(s)")
}
// The skills are listed without asking GitHub, so the dump stays offline; the plugins are compared on disk.
let extensions = InstalledExtensions.read().report(trees: [:], checksUpstream: false, now: Date())
for source in extensions.skills {
    print("skills  \(source.name)  \(source.items.count) installed  not checked")
}
for source in extensions.plugins {
    print("plugins  \(source.name)  \(source.items.count) installed  \(source.updates) to update  \(source.unknown) unknown")
}
if let swap = SwapUsage.read() {
    print("swap  \(DisplayFormat.memory(swap.usedBytes))  \(swap.state)")
}
print(String(format: "scan: %d process, %.0f ms", scan.processIdentities.count, Date().timeIntervalSince(started) * 1000))
