import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var api: APIService
    @EnvironmentObject var queueStore: GenerationQueueStore
    @EnvironmentObject var worksStore: WorksStore
    @EnvironmentObject var editCoordinator: EditTaskCoordinator

    let onNavigateToTab: (SidebarTab) -> Void

    private let tileMinWidth: CGFloat = 116
    private let tileMaxWidth: CGFloat = 136
    private let tileHeight: CGFloat = 84
    // Queue cards need a little extra vertical room for the monospaced count.
    private let statTileHeight: CGFloat = 96
    private let tileSpacing: CGFloat = 16
    private let tileCornerRadius: CGFloat = 10

    private var tileColumns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: tileMinWidth, maximum: tileMaxWidth),
                spacing: tileSpacing,
                alignment: .top
            )
        ]
    }

    private var todayCount: Int {
        let cal = Calendar.current
        return queueStore.items.filter { cal.isDateInToday($0.createdAt) }.count
    }

    private var recentItems: [GenerationQueueItem] {
        Array(queueStore.items
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(10))
    }

    private var failedItems: [GenerationQueueItem] {
        queueStore.items.filter { $0.status == .failed }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                queueStatusSection
                connectionStatusSection
                quickActionsSection
                if !failedItems.isEmpty {
                    failedTasksSection
                }
                recentTasksSection
                todaySummarySection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .navigationTitle("首页")
    }

    // MARK: - Queue Status

    private var queueStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("队列状态")
            LazyVGrid(columns: tileColumns, alignment: .leading, spacing: tileSpacing) {
                statCard(label: "待提交", count: queueStore.pendingCount, icon: "clock", color: .secondary)
                statCard(label: "提交中", count: queueStore.submittingCount, icon: "arrow.up.circle", color: .blue)
                statCard(label: "轮询中", count: queueStore.pollingCount, icon: "antenna.radiowaves.left.and.right", color: .orange)
                statCard(label: "完成", count: queueStore.succeededCount, icon: "checkmark.circle", color: .green)
                statCard(label: "失败", count: queueStore.failedCount, icon: "xmark.circle", color: .red)
            }
        }
    }

    private func statCard(label: String, count: Int, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(count > 0 ? color : .secondary)
            Text("\(count)")
                .font(.system(.title, design: .monospaced))
                .foregroundColor(count > 0 ? color : .secondary)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(minWidth: tileMinWidth, maxWidth: .infinity, minHeight: statTileHeight, maxHeight: statTileHeight)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: tileCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: tileCornerRadius, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        }
    }

    // MARK: - Connection Status

    private var connectionStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("连接状态")
            LazyVGrid(columns: tileColumns, alignment: .leading, spacing: tileSpacing) {
                connectionCard(
                    icon: healthIcon,
                    iconColor: healthColor,
                    primary: healthPrimary,
                    secondary: "后端"
                )
                connectionCard(
                    icon: api.serverScheme == "https" ? "lock.fill" : "lock.open.fill",
                    iconColor: api.serverScheme == "https" ? .green : .orange,
                    primary: api.serverScheme.uppercased(),
                    secondary: api.serverDisplayOrigin
                )
                connectionCard(
                    icon: "person.circle.fill",
                    iconColor: .accentColor,
                    primary: api.username,
                    secondary: api.role
                )

                reconnectButton
            }
        }
    }

    private var healthIcon: String {
        switch api.backendHealthState {
        case .healthy: return "checkmark.circle.fill"
        case .reachable: return "exclamationmark.circle.fill"
        case .unhealthy, .unreachable: return "xmark.circle.fill"
        case .unknown, .checking: return "questionmark.circle"
        }
    }

    private var healthColor: Color {
        switch api.backendHealthState {
        case .healthy: return .green
        case .reachable: return .orange
        case .unhealthy, .unreachable: return .red
        case .unknown, .checking: return .gray
        }
    }

    private var healthPrimary: String {
        switch api.backendHealthState {
        case .unknown, .checking: return "检测中"
        case .healthy: return "正常"
        case .reachable: return "需鉴权"
        case .unhealthy: return "异常"
        case .unreachable: return "不可用"
        }
    }

    private func connectionCard(icon: String, iconColor: Color, primary: String, secondary: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
            Text(primary)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(secondary)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(12)
        .frame(minWidth: tileMinWidth, maxWidth: .infinity, minHeight: tileHeight, maxHeight: tileHeight)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: tileCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: tileCornerRadius, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        }
        .help("\(primary)\n\(secondary)")
    }

    private var reconnectButton: some View {
        Button {
            Task { await api.checkBackendHealth() }
        } label: {
            VStack(spacing: 8) {
                reconnectIndicator
                Text("重新检测")
                    .font(.caption)
            }
            .padding(12)
            .frame(minWidth: tileMinWidth, maxWidth: .infinity, minHeight: tileHeight, maxHeight: tileHeight)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: tileCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: tileCornerRadius, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(api.backendHealthState == .checking)
    }

    @ViewBuilder
    private var reconnectIndicator: some View {
        switch api.backendHealthState {
        case .checking:
            ProgressView()
                .controlSize(.small)
        case .healthy:
            Image(systemName: "arrow.clockwise.circle")
                .font(.title2)
                .foregroundColor(.green)
        case .reachable:
            Image(systemName: "arrow.clockwise.circle")
                .font(.title2)
                .foregroundColor(.orange)
        case .unhealthy, .unreachable:
            Image(systemName: "arrow.clockwise.circle")
                .font(.title2)
                .foregroundColor(.red)
        case .unknown:
            Image(systemName: "arrow.clockwise.circle")
                .font(.title2)
                .foregroundColor(.accentColor)
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("快速入口")

            LazyVGrid(columns: tileColumns, alignment: .leading, spacing: tileSpacing) {
                actionButton(title: "新建图片任务", icon: "photo.badge.plus", color: .accentColor) {
                    onNavigateToTab(.imageGen)
                }
                actionButton(title: "新建视频任务", icon: "video.badge.plus", color: .blue) {
                    onNavigateToTab(.seedance)
                }
                actionButton(title: "作品库", icon: "square.grid.2x2", color: .purple) {
                    onNavigateToTab(.works)
                }
                actionButton(title: "任务队列", icon: "list.bullet.rectangle", color: .orange) {
                    onNavigateToTab(.tasks)
                }
                if let lastItem = queueStore.items.sorted(by: { $0.createdAt > $1.createdAt }).first {
                    actionButton(title: "继续上次任务", icon: "arrow.counterclockwise", color: .green) {
                        editCoordinator.editingItem = lastItem
                    }
                }
            }
        }
    }

    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .padding(12)
            .frame(minWidth: tileMinWidth, maxWidth: .infinity, minHeight: tileHeight, maxHeight: tileHeight)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: tileCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: tileCornerRadius, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Failed Tasks

    private var failedTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("失败任务 (\(failedItems.count))")

            LazyVStack(spacing: 8) {
                ForEach(failedItems.sorted(by: { $0.createdAt > $1.createdAt }).prefix(5)) { item in
                    taskCard(item)
                }
            }

            if failedItems.count > 5 {
                Button("查看全部失败任务 (\(failedItems.count))") {
                    onNavigateToTab(.tasks)
                }
                .font(.caption)
                .foregroundColor(.red)
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Recent Tasks

    private var recentTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("最近任务")

            if recentItems.isEmpty {
                Text("暂无任务")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(recentItems.prefix(8)) { item in
                        taskCard(item)
                    }
                }
            }
        }
    }

    // MARK: - Today Summary

    private var todaySummarySection: some View {
        HStack(spacing: 16) {
            summaryBadge(icon: "tray.full", label: "今日任务", value: "\(todayCount)")
            summaryBadge(icon: "checkmark.circle.fill", label: "今日完成", value: "\(todaySucceededCount)")
            summaryBadge(icon: "chart.line.uptrend.xyaxis", label: "队列总任务", value: "\(queueStore.items.count)")
            summaryBadge(icon: "square.grid.2x2.fill", label: "作品总数", value: "\(worksStore.records.count)")
            summaryBadge(icon: "dollarsign.circle.fill", label: "总消费", value: String(format: "$%.2f", worksStore.totalCost))
            summaryBadge(icon: "dollarsign.circle", label: "今日消费", value: String(format: "$%.2f", worksStore.todayCost))
        }
    }

    private var todaySucceededCount: Int {
        let cal = Calendar.current
        return queueStore.items.filter { $0.status == .succeeded && cal.isDateInToday($0.completedAt ?? $0.createdAt) }.count
    }

    private func summaryBadge(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(.title3, design: .monospaced))
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        }
    }

    // MARK: - Task Card

    private func taskCard(_ item: GenerationQueueItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.iconName)
                .foregroundColor(.accentColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(item.displayType)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    statusBadge(item.status, pollDetail: item.pollDetail)
                }

                Text(item.summary.prefix(100))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if item.status == .failed && !item.restoredFromPersistence {
                HStack(spacing: 4) {
                    Button("编辑") { editCoordinator.editingItem = item }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .font(.caption)
                    Button("重试") { queueStore.retryFailedItem(item.id) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .font(.caption)
                }
            } else if item.status == .pending {
                Button("取消") { queueStore.cancelPendingItem(item.id) }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let error = item.errorMessage, item.status == .failed {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .lineLimit(2)
                    .frame(maxWidth: 200, alignment: .trailing)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        }
    }

    private func statusBadge(_ status: GenerationQueueStatus, pollDetail: String? = nil) -> some View {
        let label = (status == .polling && pollDetail != nil) ? pollDetail! : status.displayName
        return Text(label)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor(status).opacity(0.15))
            .foregroundColor(statusColor(status))
            .cornerRadius(4)
    }

    private func statusColor(_ status: GenerationQueueStatus) -> Color {
        switch status {
        case .pending: return .secondary
        case .submitting: return .blue
        case .polling: return .orange
        case .succeeded: return .green
        case .failed: return .red
        case .cancelled: return .gray
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .fontWeight(.semibold)
    }
}
