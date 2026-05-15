import Foundation
import OSLog

// MARK: - Step Run Record DTO

struct WorkflowStepRunRecord: Codable {
    var stepId: String
    var stepType: String
    var stepLabel: String
    var status: String
    var errorMessage: String?
    var resultText: String?
    var resultImageURLs: [String]?
    var resultVideoURL: String?
    var resultAssetPath: String?

    init(step: WorkflowStep, status: String, error: String? = nil, result: StepResult? = nil) {
        self.stepId = step.id
        self.stepType = step.type.rawValue
        self.stepLabel = step.label
        self.status = status
        self.errorMessage = error

        guard let result else { return }
        switch result {
        case .none: break
        case .text(let t): resultText = t
        case .images(let urls): resultImageURLs = urls
        case .video(let url): resultVideoURL = url
        case .bananaImage: break
        }
    }

    mutating func attachAssetPath(_ path: String) {
        resultAssetPath = path
    }
}

// MARK: - Run Record

struct WorkflowRunRecord: Codable {
    var runId: String
    var workflowId: String
    var workflowName: String
    var stepsSnapshot: [WorkflowStep]
    var stepRecords: [WorkflowStepRunRecord]
    var overallStatus: String
    var startedAt: Date
    var completedAt: Date?
}

// MARK: - Run Summary (lightweight index entry)

struct WorkflowRunSummary: Codable, Equatable {
    var runId: String
    var workflowId: String
    var workflowName: String
    var overallStatus: String
    var startedAt: Date
    var completedAt: Date?
    var stepCount: Int
    var succeededCount: Int
    var firstError: String?
}

// MARK: - Run Index

struct WorkflowRunIndex: Codable {
    var runs: [WorkflowRunSummary] = []

    static let maxEntries = 100

    /// Insert or update a summary at the front. Returns summaries evicted due to max cap.
    @discardableResult
    mutating func upsert(_ summary: WorkflowRunSummary) -> [WorkflowRunSummary] {
        var evicted: [WorkflowRunSummary] = []
        runs.removeAll { $0.runId == summary.runId }
        runs.insert(summary, at: 0)
        if runs.count > Self.maxEntries {
            evicted = Array(runs.suffix(runs.count - Self.maxEntries))
            runs = Array(runs.prefix(Self.maxEntries))
        }
        return evicted
    }

    mutating func removeRuns(for workflowId: String) {
        runs.removeAll { $0.workflowId == workflowId }
    }

    mutating func removeRun(_ runId: String) {
        runs.removeAll { $0.runId == runId }
    }
}

// MARK: - Persistence Manager

enum WorkflowRunPersistence {
    private static let logger = Logger(subsystem: "AIZhijian", category: "WorkflowRunPersistence")

    /// For testing only. When set, all directory lookups use this as the base.
    nonisolated(unsafe) static var baseDirectoryOverride: URL?

    // MARK: - Directories

    private static var effectiveBase: URL {
        if let override = baseDirectoryOverride { return override }
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AI 智剪/WorkflowRuns")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var baseDirectory: URL { effectiveBase }

    static var indexURL: URL {
        effectiveBase.appendingPathComponent("index.json")
    }

    static func runDirectory(runId: String) -> URL {
        effectiveBase.appendingPathComponent(runId)
    }

    static func runJSONURL(runId: String) -> URL {
        runDirectory(runId: runId).appendingPathComponent("run.json")
    }

    static func assetsDirectory(runId: String) -> URL {
        let url = runDirectory(runId: runId).appendingPathComponent("assets")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - Path Validation

    private static func isValidRunId(_ runId: String) -> Bool {
        UUID(uuidString: runId) != nil
    }

    private static func isValidAssetName(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        let forbidden: Set<Character> = ["/", "\\", ":"]
        guard !name.contains(".."), !name.contains(where: forbidden.contains) else { return false }
        return true
    }

    private static func isPathWithinBase(_ url: URL, base: URL) -> Bool {
        let resolved = url.resolvingSymlinksInPath().standardizedFileURL
        let baseResolved = base.resolvingSymlinksInPath().standardizedFileURL
        return resolved.path == baseResolved.path
            || resolved.path.hasPrefix(baseResolved.path + "/")
    }

    private static func validatedChildURL(parent: URL, component: String) -> URL? {
        guard !component.isEmpty else { return nil }
        let child = parent.appendingPathComponent(component)
        guard isPathWithinBase(child, base: parent) else {
            logger.warning("Path escape detected: \(component) in \(parent.path)")
            return nil
        }
        return child
    }

    // MARK: - Index

    static func loadIndex() -> WorkflowRunIndex {
        guard let data = try? Data(contentsOf: indexURL),
              let index = try? JSONDecoder().decode(WorkflowRunIndex.self, from: data)
        else { return WorkflowRunIndex() }
        return index
    }

    @discardableResult
    static func saveIndex(_ index: WorkflowRunIndex) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(index)
            try data.write(to: indexURL, options: .atomic)
            return true
        } catch {
            logger.error("Failed to save run index: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Run Records

    @discardableResult
    static func saveRun(_ record: WorkflowRunRecord) -> Bool {
        guard isValidRunId(record.runId) else {
            logger.error("Refusing to save run with invalid runId: \(record.runId)")
            return false
        }
        do {
            let dir = runDirectory(runId: record.runId)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(record)
            try data.write(to: runJSONURL(runId: record.runId), options: .atomic)
            return true
        } catch {
            logger.error("Failed to save run record: \(error.localizedDescription)")
            return false
        }
    }

    static func loadRun(runId: String) -> WorkflowRunRecord? {
        guard isValidRunId(runId) else { return nil }
        let url = runJSONURL(runId: runId)
        guard let data = try? Data(contentsOf: url),
              let record = try? JSONDecoder().decode(WorkflowRunRecord.self, from: data)
        else { return nil }
        guard record.runId == runId else {
            logger.warning("Run record runId mismatch: expected \(runId), got \(record.runId)")
            return nil
        }
        return record
    }

    // MARK: - Assets

    static func saveAsset(data: Data, name: String, runId: String) -> String? {
        guard isValidRunId(runId), isValidAssetName(name) else {
            logger.error("Refusing to save asset: invalid runId or name")
            return nil
        }
        let dir = assetsDirectory(runId: runId)
        let safeName = name.replacingOccurrences(of: "/", with: "_")
        let rawName = "\(UUID().uuidString)-\(safeName)"
        guard let fileURL = validatedChildURL(parent: dir, component: rawName) else { return nil }
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL.lastPathComponent
        } catch {
            logger.error("Failed to save asset: \(error.localizedDescription)")
            return nil
        }
    }

    static func loadAsset(runId: String, fileName: String) -> Data? {
        guard isValidRunId(runId), isValidAssetName(fileName) else { return nil }
        let dir = assetsDirectory(runId: runId)
        guard let url = validatedChildURL(parent: dir, component: fileName) else { return nil }
        return try? Data(contentsOf: url)
    }

    // MARK: - Cleanup

    static func deleteRun(runId: String) {
        guard isValidRunId(runId) else { return }
        let dir = runDirectory(runId: runId)
        try? FileManager.default.removeItem(at: dir)
    }

    /// Delete all run records belonging to a workflow.
    /// Uses index as fast path, then falls back to scanning the filesystem
    /// to catch orphan runs whose index entry was lost.
    static func deleteRuns(for workflowId: String) {
        let index = loadIndex()
        for summary in index.runs where summary.workflowId == workflowId {
            deleteRun(runId: summary.runId)
        }

        scanAndDeleteRuns(for: workflowId)

        var updated = index
        updated.removeRuns(for: workflowId)
        saveIndex(updated)
    }

    /// Prune evicted runs (lose their index slots) and their on-disk directories.
    static func pruneEvictedRuns(_ evicted: [WorkflowRunSummary]) {
        for summary in evicted {
            deleteRun(runId: summary.runId)
        }
    }

    // MARK: - Filesystem scan

    private static func scanAndDeleteRuns(for workflowId: String) {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: effectiveBase, includingPropertiesForKeys: nil
        ) else { return }

        for entry in entries {
            let name = entry.lastPathComponent
            guard isValidRunId(name) else { continue }
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: entry.path, isDirectory: &isDir),
                  isDir.boolValue else { continue }

            let runJSON = entry.appendingPathComponent("run.json")
            guard let data = try? Data(contentsOf: runJSON),
                  let record = try? JSONDecoder().decode(WorkflowRunRecord.self, from: data),
                  record.workflowId == workflowId,
                  record.runId == name else { continue }

            deleteRun(runId: name)
            logger.info("Orphan run \(name) cleaned up by filesystem scan")
        }
    }
}
