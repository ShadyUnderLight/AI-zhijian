import SwiftUI

// MARK: - Route Health View

struct RouteHealthView: View {
    @EnvironmentObject var api: APIService

    @State private var results: [HealthCheckResult] = []
    @State private var isChecking = true
    @State private var errorMessage: String?
    @State private var lastCheckTime: Date?

    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 260), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("全局线路检测")
                    .font(.title2)
                    .fontWeight(.semibold)

                if let lastCheck = lastCheckTime {
                    Text("上次检测：\(relativeTime(lastCheck))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)
                }

                Spacer()

                Button(action: checkAll) {
                    Label(isChecking ? "检测中…" : "全部重新检测", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isChecking)
            }
            .padding()

            if let error = errorMessage {
                ContentUnavailableView(
                    "检测失败",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
                Button("重试") { checkAll() }
                    .buttonStyle(.bordered)
                Spacer()
            } else if results.isEmpty && isChecking {
                Spacer()
                ProgressView("正在检测各服务线路…")
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(results) { result in
                            ServiceHealthCard(result: result)
                        }
                    }
                    .padding()
                }
            }
        }
        .task { checkAll() }
    }

    // MARK: - Actions

    private func checkAll() {
        isChecking = true
        errorMessage = nil
        Task {
            do {
                let healthResults = try await api.adminCheckAllHealth()
                results = healthResults.results
                lastCheckTime = Date()
            } catch {
                errorMessage = error.localizedDescription
            }
            isChecking = false
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            return "\(Int(interval / 60)) 分钟前"
        } else {
            let df = DateFormatter()
            df.dateFormat = "HH:mm"
            return df.string(from: date)
        }
    }
}

// MARK: - Service Health Card

private struct ServiceHealthCard: View {
    let result: HealthCheckResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }

            Divider()

            // Latency
            HStack {
                Image(systemName: "hare")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(result.latency ?? "-")
                    .font(.body.monospaced())
                    .foregroundColor(.secondary)
            }

            // Last check
            HStack {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(result.lastCheckAt ?? "-")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Status text
            Text(statusLabel)
                .font(.caption)
                .foregroundColor(statusColor)
                .padding(.top, 4)
        }
        .padding(12)
        .frame(height: 140)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(statusColor.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var displayName: String {
        switch result.serviceName {
        case "deepseek": return "DeepSeek"
        case "yunwu": return "云雾"
        case "runninghub": return "RunningHub"
        case "gemini": return "Gemini（反代）"
        case "gemini-pro": return "Gemini Pro（反代）"
        case "gemini-official": return "Gemini 官方"
        case "gemini-official-pro": return "Gemini 官方 Pro"
        case "gpt": return "GPT API"
        default: return result.serviceName
        }
    }

    private var statusColor: Color {
        switch result.healthStatus {
        case .healthy: return .green
        case .reachable: return .yellow
        case .unhealthy: return .red
        case .unknown: return .gray
        }
    }

    private var statusLabel: String {
        switch result.healthStatus {
        case .healthy: return "正常"
        case .reachable: return "需鉴权"
        case .unhealthy: return "异常"
        case .unknown: return "未知"
        }
    }
}
