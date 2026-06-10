import SwiftUI
import UniformTypeIdentifiers

// MARK: - Call Log View

struct CallLogView: View {
    @EnvironmentObject var api: APIService

    // Filters
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var filterFunction = ""
    @State private var filterStatus = ""
    @State private var filterMediaType = ""
    @State private var filterGenerationMode = ""

    // Data
    @State private var logs: [AdminCallLog] = []
    @State private var stats: AdminCallLogStats?
    @State private var isLoading = true
    @State private var isExporting = false
    @State private var errorMessage: String?

    // Expanded log detail
    @State private var selectedLog: AdminCallLog?

    private let statusOptions = ["", "success", "failed", "running", "pending"]
    private let mediaTypeOptions = ["", "image", "video", "audio", "text"]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("调用日志")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: exportCSV) {
                    Label(isExporting ? "导出中…" : "导出 CSV", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .disabled(isExporting)
                Button("刷新", action: loadData)
                    .buttonStyle(.borderedProminent)
            }
            .padding()

            // Stats bar
            if let stats {
                HStack(spacing: 24) {
                    StatBadge(title: "总调用", value: "\(stats.totalCalls ?? 0)", icon: "number")
                    StatBadge(title: "总费用", value: String(format: "$%.4f", stats.totalCost ?? 0), icon: "dollarsign")
                    StatBadge(title: "平均耗时", value: formatDuration(stats.averageDuration ?? 0), icon: "clock")
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            // Filter bar
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    DatePicker("开始", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                    DatePicker("结束", selection: $endDate, displayedComponents: .date)
                        .datePickerStyle(.compact)

                    TextField("功能", text: $filterFunction)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)

                    Picker("状态", selection: $filterStatus) {
                        ForEach(statusOptions, id: \.self) { s in
                            Text(s.isEmpty ? "全部" : s.capitalized).tag(s)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)

                    Picker("媒体类型", selection: $filterMediaType) {
                        ForEach(mediaTypeOptions, id: \.self) { m in
                            Text(m.isEmpty ? "全部" : m.capitalized).tag(m)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)

                    Button("查询") { loadData() }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Content
            if isLoading {
                Spacer()
                ProgressView("加载中…")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                ContentUnavailableView(
                    "加载失败",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
                Button("重试") { loadData() }
                    .buttonStyle(.bordered)
                Spacer()
            } else if logs.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "暂无日志",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("调整筛选条件后重新查询")
                )
                Spacer()
            } else {
                List(logs) { log in
                    LogRow(log: log)
                }
                .listStyle(.plain)
            }
        }
        .task { loadData() }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Double) -> String {
        if seconds < 1 {
            return String(format: "%.0fms", seconds * 1000)
        } else if seconds < 60 {
            return String(format: "%.1fs", seconds)
        } else {
            let m = Int(seconds) / 60
            let s = Int(seconds) % 60
            return "\(m)m\(s)s"
        }
    }

    // MARK: - Data

    private func loadData() {
        isLoading = true
        errorMessage = nil
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        Task {
            do {
                let startStr = dateFormatter.string(from: startDate)
                let endStr = dateFormatter.string(from: endDate)

                async let logsResp = api.adminGetCallLogs(
                    startDate: startStr,
                    endDate: endStr,
                    function: filterFunction.isEmpty ? nil : filterFunction,
                    status: filterStatus.isEmpty ? nil : filterStatus,
                    mediaType: filterMediaType.isEmpty ? nil : filterMediaType,
                    generationMode: filterGenerationMode.isEmpty ? nil : filterGenerationMode
                )

                async let statsResp = api.adminGetCallLogStats(
                    startDate: startStr,
                    endDate: endStr
                )

                let (logsResult, statsResult) = try await (logsResp, statsResp)

                if logsResult.success, let logs = logsResult.logs {
                    self.logs = logs
                } else {
                    errorMessage = logsResult.message ?? "获取日志失败"
                }

                if statsResult.success {
                    self.stats = statsResult.stats
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func exportCSV() {
        isExporting = true
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        Task {
            do {
                let startStr = dateFormatter.string(from: startDate)
                let endStr = dateFormatter.string(from: endDate)
                let data = try await api.adminExportCallLogsCSV(
                    startDate: startStr,
                    endDate: endStr,
                    function: filterFunction.isEmpty ? nil : filterFunction,
                    status: filterStatus.isEmpty ? nil : filterStatus
                )

                // Save to desktop
                let fileName = "call-logs-\(formattedDateString()).csv"
                let saveURL = FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Desktop")
                    .appendingPathComponent(fileName)
                try data.write(to: saveURL)

                NSWorkspace.shared.selectFile(saveURL.path, inFileViewerRootedAtPath: saveURL.deletingLastPathComponent().path)
            } catch {
                errorMessage = "导出失败: \(error.localizedDescription)"
            }
            isExporting = false
        }
    }

    private func formattedDateString() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd"
        return df.string(from: Date())
    }
}

// MARK: - Log Row

private struct LogRow: View {
    let log: AdminCallLog

    var body: some View {
        HStack(spacing: 12) {
            // Time
            Text(formatTime(log.createdAt))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 130, alignment: .leading)

            // User
            Text(log.username ?? "-")
                .font(.caption)
                .frame(width: 60, alignment: .leading)

            // Function
            Text(log.function ?? "-")
                .font(.caption)
                .frame(minWidth: 80, alignment: .leading)

            // Status
            statusBadge(log.status)
                .frame(width: 50)

            // Duration
            Text(formatDuration(log.durationSeconds))
                .font(.caption.monospaced())
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)

            // Cost
            if let cost = log.cost {
                Text(String(format: "$%.4f", cost))
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .trailing)
            } else {
                Text("-")
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .trailing)
            }

            // Media type
            Text(log.mediaType ?? "-")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)

            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }

    private func formatTime(_ isoString: String?) -> String {
        guard let str = isoString else { return "-" }
        if str.count >= 19 {
            let idx = str.index(str.startIndex, offsetBy: 19)
            return String(str[..<idx])
        }
        return str
    }

    private func formatDuration(_ seconds: Double) -> String {
        if seconds < 1 {
            return String(format: "%.0fms", seconds * 1000)
        } else if seconds < 60 {
            return String(format: "%.1fs", seconds)
        } else {
            let m = Int(seconds) / 60
            let s = Int(seconds) % 60
            return "\(m)m\(s)s"
        }
    }

    @ViewBuilder
    private func statusBadge(_ status: String?) -> some View {
        switch status?.lowercased() {
        case "success", "completed":
            Text("成功")
                .font(.caption)
                .foregroundColor(.green)
        case "failed", "error":
            Text("失败")
                .font(.caption)
                .foregroundColor(.red)
        case "running", "processing":
            Text("运行中")
                .font(.caption)
                .foregroundColor(.orange)
        case "pending":
            Text("排队中")
                .font(.caption)
                .foregroundColor(.blue)
        default:
            Text(status ?? "-")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Stat Badge

private struct StatBadge: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.body.monospaced())
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.textBackgroundColor))
        .cornerRadius(8)
    }
}
