import SwiftUI

struct TaskListView: View {
    @EnvironmentObject var api: APIService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if api.activeTasks.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("暂无活跃任务")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(api.activeTasks) { task in
                        HStack {
                            Image(systemName: task.type.contains("Image") || task.type.contains("Banana") ? "photo" : "video")
                                .foregroundColor(.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.type).font(.headline)
                                Text(task.desc).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("等待中").font(.caption).foregroundColor(.orange)
                                Text(task.elapsed).font(.caption2).foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("任务队列")
    }
}

// MARK: - History View

struct HistoryView: View {
    @EnvironmentObject var api: APIService
    
    @State private var imageHistory: [HistoryItem] = []
    @State private var videoHistory: [HistoryItem] = []
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Image history
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("GPT-Image-2 历史").font(.title3)
                        Spacer()
                        if !imageHistory.isEmpty {
                            Text("\(imageHistory.count) 条").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    
                    if imageHistory.isEmpty {
                        Text("暂无记录").font(.caption).foregroundColor(.secondary)
                            .padding(.vertical, 20)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 220))], spacing: 10) {
                            ForEach(imageHistory.filter { $0.resultUrl != nil }) { item in
                                VStack(spacing: 4) {
                                    AsyncImage(url: URL(string: item.resultUrl!)) { phase in
                                        switch phase {
                                        case .success(let img):
                                            img.resizable().scaledToFill()
                                                .frame(height: 160)
                                                .clipped()
                                                .cornerRadius(8)
                                        default:
                                            Color(nsColor: .controlBackgroundColor)
                                                .frame(height: 160)
                                                .cornerRadius(8)
                                        }
                                    }
                                    Text(item.prompt?.prefix(20) ?? "")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                .onTapGesture {
                                    if let url = item.resultUrl {
                                        NSWorkspace.shared.open(URL(string: url)!)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Divider()
                
                // Video history
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Seedance 视频历史").font(.title3)
                        Spacer()
                        if !videoHistory.isEmpty {
                            Text("\(videoHistory.count) 条").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    
                    if videoHistory.isEmpty {
                        Text("暂无记录").font(.caption).foregroundColor(.secondary)
                            .padding(.vertical, 20)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 220))], spacing: 10) {
                            ForEach(videoHistory.filter { $0.videoUrl != nil }) { item in
                                VStack(spacing: 4) {
                                    ZStack {
                                        Color(nsColor: .controlBackgroundColor)
                                            .frame(height: 160)
                                            .cornerRadius(8)
                                        Image(systemName: "play.rectangle")
                                            .font(.system(size: 30))
                                            .foregroundColor(.accentColor)
                                    }
                                    Text(item.prompt?.prefix(20) ?? "")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                .onTapGesture {
                                    if let url = item.videoUrl {
                                        NSWorkspace.shared.open(URL(string: url)!)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .onAppear { loadHistory() }
        .toolbar {
            ToolbarItem {
                Button("刷新") { loadHistory() }
                    .disabled(isLoading)
            }
        }
    }
    
    private func loadHistory() {
        isLoading = true
        Task {
            async let imgResult = try? api.getImageHistory()
            async let vidResult = try? api.getSeedanceHistory()
            let (img, vid) = await (imgResult, vidResult)
            imageHistory = img?.data ?? []
            videoHistory = vid?.data ?? []
            isLoading = false
        }
    }
}
