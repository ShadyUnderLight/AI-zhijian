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

    mutating func upsert(_ summary: WorkflowRunSummary) {
        runs.removeAll { $0.runId == summary.runId }
        runs.insert(summary, at: 0)
        if runs.count > Self.maxEntries {
            runs = Array(runs.prefix(Self.maxEntries))
        }
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

    // MARK: - Directories

    static var baseDirectory: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AI 智剪/WorkflowRuns")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var indexURL: URL {
        baseDirectory.appendingPathComponent("index.json")
    }

    static func runDirectory(runId: String) -> URL {
        baseDirectory.appendingPathComponent(runId)
    }

    static func runJSONURL(runId: String) -> URL {
        runDirectory(runId: runId).appendingPathComponent("run.json")
    }

    static func assetsDirectory(runId: String) -> URL {
        let url = runDirectory(runId: runId).appendingPathComponent("assets")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - Index

    static func loadIndex() -> WorkflowRunIndex {
        guard let data = try? Data(contentsOf: indexURL),
              let index = try? JSONDecoder().decode(WorkflowRunIndex.self, from: data)
        else { return WorkflowRunIndex() }
        return index
    }

    static func saveIndex(_ index: WorkflowRunIndex) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(index)
            try data.write(to: indexURL, options: .atomic)
        } catch {
            logger.error("Failed to save run index: \(error.localizedDescription)")
        }
    }

    // MARK: - Run Records

    static func saveRun(_ record: WorkflowRunRecord) {
        do {
            let dir = runDirectory(runId: record.runId)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(record)
            try data.write(to: runJSONURL(runId: record.runId), options: .atomic)
        } catch {
            logger.error("Failed to save run record: \(error.localizedDescription)")
        }
    }

    static func loadRun(runId: String) -> WorkflowRunRecord? {
        guard let data = try? Data(contentsOf: runJSONURL(runId: runId)),
              let record = try? JSONDecoder().decode(WorkflowRunRecord.self, from: data)
        else { return nil }
        return record
    }

    // MARK: - Assets

    static func saveAsset(data: Data, name: String, runId: String) -> String? {
        let dir = assetsDirectory(runId: runId)
        let safeName = name.replacingOccurrences(of: "/", with: "_")
        let fileName = "\(UUID().uuidString)-\(safeName)"
        let fileURL = dir.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileName
        } catch {
            logger.error("Failed to save asset: \(error.localizedDescription)")
            return nil
        }
    }

    static func loadAsset(runId: String, fileName: String) -> Data? {
        let url = assetsDirectory(runId: runId).appendingPathComponent(fileName)
        return try? Data(contentsOf: url)
    }

    // MARK: - Cleanup

    static func deleteRun(runId: String) {
        let dir = runDirectory(runId: runId)
        try? FileManager.default.removeItem(at: dir)
    }

    static func deleteRuns(for workflowId: String) {
        let index = loadIndex()
        for summary in index.runs where summary.workflowId == workflowId {
            deleteRun(runId: summary.runId)
        }
        var updated = index
        updated.removeRuns(for: workflowId)
        saveIndex(updated)
    }
}
