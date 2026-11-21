import Foundation

public struct ServiceRestartResult: Sendable, Hashable {
    public let service: AllowlistedService
    public let succeeded: Bool

    public init(service: AllowlistedService, succeeded: Bool) {
        self.service = service
        self.succeeded = succeeded
    }
}

public protocol ServiceRestarting: Sendable {
    func restart(services: Set<AllowlistedService>) async -> [ServiceRestartResult]
}

public struct ServiceRestarter: ServiceRestarting {
    public init() {}

    public func restart(services: Set<AllowlistedService>) async -> [ServiceRestartResult] {
        var results: [ServiceRestartResult] = []
        // Sort deterministically so cfprefsd runs first if included
        let ordered = services.sorted { lhs, rhs in
            if lhs == .cfprefsd { return true }
            if rhs == .cfprefsd { return false }
            return lhs.rawValue < rhs.rawValue
        }

        for service in ordered {
            let ok = await runKillall(processName: service.processName)
            results.append(ServiceRestartResult(service: service, succeeded: ok))
        }
        return results
    }

    private func runKillall(processName: String) async -> Bool {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            process.arguments = [processName]
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            process.terminationHandler = { proc in
                // exit code 0 = killed; 1 = no matching process (not fatal)
                continuation.resume(returning: proc.terminationStatus == 0 || proc.terminationStatus == 1)
            }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: false)
            }
        }
    }
}
