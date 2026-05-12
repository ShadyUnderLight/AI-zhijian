import SwiftUI

struct ImageGenView: View {
    @EnvironmentObject var api: APIService
    
    @State private var prompt = ""
    @State private var channel = "official"
    @State private var ratio = "9:16"
    @State private var resolution = "2k"
    @State private var quality = "medium"
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var resultTaskId: String?
    @State private var pollTask: Task<Void, Never>?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Prompt
                VStack(alignment: .leading, spacing: 6) {
                    Text("提示词").font(.headline)
                    TextEditor(text: $prompt)
                        .font(.body)
                        .frame(height: 80)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                }
                
                // Options
                HStack(spacing: 16) {
                    optionPicker("渠道", selection: $channel, options: [
                        ("official", "官方"),
                        ("budget", "低价")
                    ])
                    optionPicker("画幅", selection: $ratio, options: [
                        ("9:16", "9:16"), ("16:9", "16:9"), ("1:1", "1:1"),
                        ("2:3", "2:3"), ("3:2", "3:2"), ("4:3", "4:3"),
                        ("3:4", "3:4"), ("21:9", "21:9")
                    ])
                    optionPicker("分辨率", selection: $resolution, options: [
                        ("1k", "1K"), ("2k", "2K"), ("4k", "4K")
                    ])
                    optionPicker("质量", selection: $quality, options: [
                        ("low", "低"), ("medium", "中"), ("high", "高")
                    ])
                }
                
                // Generate button
                HStack {
                    Button(action: startGeneration) {
                        if isGenerating {
                            ProgressView().scaleEffect(0.8)
                            Text("生成中...")
                        } else {
                            Label("生成图片", systemImage: "wand.and.stars")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
                }
                
                if let error = errorMessage {
                    Text(error).foregroundColor(.red).font(.caption)
                }
                
                // Results
                if let taskId = resultTaskId {
                    TaskPollingView(taskId: taskId, pollType: .image, api: api)
                }
            }
            .padding(24)
        }
        .frame(minWidth: 500)
    }
    
    private func startGeneration() {
        isGenerating = true
        errorMessage = nil
        resultTaskId = nil
        
        Task {
            do {
                let result = try await api.generateImage(
                    prompt: prompt,
                    channel: channel,
                    aspectRatio: ratio,
                    resolution: resolution,
                    quality: quality
                )
                if let taskId = result.ourTaskId {
                    resultTaskId = taskId
                    api.addTask(id: taskId, type: "GPT-Image-2", desc: String(prompt.prefix(30)))
                } else {
                    errorMessage = result.message ?? "未能获取任务ID"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isGenerating = false
        }
    }
    
    private func optionPicker(_ label: String, selection: Binding<String>, options: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(.secondary)
            Picker(label, selection: selection) {
                ForEach(options, id: \.0) { opt in
                    Text(opt.1).tag(opt.0)
                }
            }
            .pickerStyle(.menu)
            .frame(minWidth: 100)
        }
    }
}

// MARK: - Task Polling View

enum PollType { case image, seedance, veo, grok }

struct TaskPollingView: View {
    let taskId: String
    let pollType: PollType
    @ObservedObject var api: APIService
    
    @State private var status = "排队中..."
    @State private var resultUrls: [String] = []
    @State private var videoUrl: String?
    @State private var isPolling = true
    @State private var pollCount = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider().padding(.vertical, 4)
            
            HStack {
                ProgressView()
                    .scaleEffect(0.7)
                Text("任务: \(String(taskId.prefix(12)))...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(status)
                    .font(.caption)
                    .foregroundColor(isPolling ? .orange : (resultUrls.isEmpty && videoUrl == nil ? .red : .green))
                Text("(\(pollCount)次)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Image results
            if !resultUrls.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(resultUrls, id: \.self) { url in
                            AsyncImage(url: URL(string: url)) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFit()
                                        .frame(maxHeight: 300)
                                        .cornerRadius(8)
                                        .onTapGesture { NSWorkspace.shared.open(URL(string: url)!) }
                                case .failure:
                                    Color.red.frame(width: 100, height: 100)
                                default:
                                    ProgressView().frame(width: 100, height: 100)
                                }
                            }
                        }
                    }
                }
            }
            
            // Video result
            if let url = videoUrl {
                Button("在浏览器中打开视频") {
                    NSWorkspace.shared.open(URL(string: url)!)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .onAppear { startPolling() }
        .onDisappear { isPolling = false }
    }
    
    private func startPolling() {
        Task {
            while isPolling {
                pollCount += 1
                do {
                    let result: TaskPollResponse
                    switch pollType {
                    case .image:
                        result = try await api.pollImageTask(taskId)
                        if result.dbStatus == "SUCCESS" {
                            status = "完成"
                            resultUrls = result.resultUrls ?? []
                            isPolling = false
                            api.removeTask(id: taskId)
                        } else if result.dbStatus == "FAILED" || result.dbStatus == "CANCELLED" {
                            status = result.errorMessage ?? "失败"
                            isPolling = false
                            api.removeTask(id: taskId)
                        } else {
                            status = result.dbStatus ?? "处理中"
                        }
                    case .seedance:
                        result = try await api.pollSeedanceTask(taskId)
                        handleVideoResult(result)
                    case .veo:
                        result = try await api.pollVeoTask(taskId)
                        handleVideoResult(result)
                    case .grok:
                        result = try await api.pollGrokTask(taskId)
                        if result.status == "SUCCESS" {
                            status = "完成"
                            videoUrl = result.outputUrl
                            isPolling = false
                            api.removeTask(id: taskId)
                        } else if result.status == "FAILED" || result.status == "CANCELLED" {
                            status = result.errorMessage ?? "失败"
                            isPolling = false
                            api.removeTask(id: taskId)
                        } else {
                            status = result.status ?? "处理中"
                        }
                    }
                } catch {
                    status = "轮询错误"
                }
                if isPolling {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                }
            }
        }
    }
    
    private func handleVideoResult(_ result: TaskPollResponse) {
        if result.dbStatus == "SUCCESS" {
            status = "完成"
            videoUrl = result.videoUrl
            isPolling = false
            api.removeTask(id: taskId)
        } else if result.dbStatus == "FAILED" || result.dbStatus == "CANCELLED" {
            status = result.errorMessage ?? "失败"
            isPolling = false
            api.removeTask(id: taskId)
        } else {
            status = result.dbStatus ?? "处理中"
        }
    }
}
