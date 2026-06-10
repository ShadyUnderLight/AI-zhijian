import SwiftUI

struct TikTokScrapeControlView: View {
    @EnvironmentObject var api: APIService

    @State private var isRunning = false
    @State private var statusMessage: String?
    @State private var logs: [TikTokScrapeLog] = []
    @State private var isLoading = true
    @State private var isStarting = false
    @State private var errorMessage: String?
    @State private var pollingTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            // Status header
            statusHeader
                .padding()
                .background(.bar)

            Divider()

            // Logs
            Group {
                if isLoading {
                    Spacer()
                    ProgressView("加载采集日志...")
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Text(error)
                            .foregroundColor(.red)
                        Button("重试") {
                            loadData()
                        }
                    }
                    Spacer()
                } else if logs.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text("暂无采集日志")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List(logs) { log in
                        HStack(alignment: .top, spacing: 8) {
                            logLevelIcon(log.level)
                                .font(.caption)
                            VStack(alignment: .leading, spacing: 2) {
                                if let msg = log.message {
                                    Text(msg)
                                        .font(.caption)
                                }
                                if let time = log.createdAt {
                                    Text(time)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .listStyle(.inset)
                }
            }
        }
        .navigationTitle("采集控制")
        .toolbar {
            ToolbarItem {
                Button("刷新日志") {
                    loadData()
                }
            }
        }
        .task {
            loadData()
        }
        .onDisappear {
            pollingTask?.cancel()
            pollingTask = nil
        }
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(isRunning ? Color.green : Color.secondary)
                .frame(width: 12, height: 12)

            Text(isRunning ? "采集运行中" : "采集空闲")
                .font(.headline)

            if let message = statusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isStarting {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 20, height: 20)
            }

            Button(isRunning ? "运行中..." : "启动采集") {
                startScrape()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRunning || isStarting)
        }
    }

    // MARK: - Actions

    private func loadData() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                async let statusResult = api.tiktokGetScrapeStatus()
                async let logsResult = api.tiktokGetScrapeLogs()
                let (status, loadedLogs) = try await (statusResult, logsResult)
                isRunning = status.isRunning
                statusMessage = status.message
                logs = loadedLogs
                isLoading = false
                if isRunning {
                    startPolling()
                }
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                    guard !Task.isCancelled else { break }
                    async let statusResult = api.tiktokGetScrapeStatus()
                    async let logsResult = api.tiktokGetScrapeLogs()
                    let (status, freshLogs) = try await (statusResult, logsResult)
                    isRunning = status.isRunning
                    statusMessage = status.message
                    logs = freshLogs
                    if !status.isRunning {
                        pollingTask = nil
                        break
                    }
                } catch {
                    if Task.isCancelled { break }
                }
            }
        }
    }

    private func startScrape() {
        isStarting = true
        Task {
            do {
                try await api.tiktokStartScrape()
                isRunning = true
                isStarting = false
                statusMessage = "采集已启动"
                logs = try await api.tiktokGetScrapeLogs()
                startPolling()
            } catch {
                errorMessage = error.localizedDescription
                isStarting = false
            }
        }
    }

    @ViewBuilder
    private func logLevelIcon(_ level: String?) -> some View {
        switch level?.lowercased() {
        case "error":
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
        case "warn", "warning":
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
        case "info":
            Image(systemName: "info.circle")
                .foregroundColor(.blue)
        case "debug":
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
        default:
            Image(systemName: "doc.text")
                .foregroundColor(.secondary)
        }
    }
}
