import SwiftUI
import UniformTypeIdentifiers

struct ImageGenView: View {
    @EnvironmentObject var api: APIService
    
    @State private var prompt = ""
    @State private var channel = "official"
    @State private var ratio = "9:16"
    @State private var resolution = "2k"
    @State private var quality = "medium"
    @State private var referenceImages: [FileRef] = []
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

                MultiImagePickerRow(label: "参考图片", files: $referenceImages, maxCount: 10)
                
                // Generate button
                HStack {
                    Button(action: startGeneration) {
                        if isGenerating {
                            ProgressView().scaleEffect(0.8)
                            Text("生成中...")
                        } else {
                            Label(referenceImages.isEmpty ? "生成图片" : "图生图", systemImage: "wand.and.stars")
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
                let result: TaskSubmitResponse
                if referenceImages.isEmpty {
                    result = try await api.generateImage(
                        prompt: prompt,
                        channel: channel,
                        aspectRatio: ratio,
                        resolution: resolution,
                        quality: quality
                    )
                } else {
                    result = try await api.generateImageToImage(
                        prompt: prompt,
                        channel: channel,
                        aspectRatio: ratio,
                        resolution: resolution,
                        quality: quality,
                        referenceImages: referenceImages
                    )
                }
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

struct MultiImagePickerRow: View {
    let label: String
    @Binding var files: [FileRef]
    let maxCount: Int

    @State private var errorMessage: String?
    @State private var thumbnails: [NSImage?] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.caption).foregroundColor(.secondary)
                Button("选择图片...") {
                    pickImages()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if !files.isEmpty {
                    Button("清除") {
                        files = []
                        thumbnails = []
                        errorMessage = nil
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }

                Text("\(files.count)/\(maxCount)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if !files.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(files.indices, id: \.self) { i in
                            VStack(spacing: 2) {
                                if i < thumbnails.count, let image = thumbnails[i] {
                                    Image(nsImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                                } else {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.secondary.opacity(0.15))
                                        .frame(width: 80, height: 80)
                                }
                                Text(files[i].name)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .frame(width: 80)
                            }
                        }
                    }
                }
                .frame(minHeight: 100)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
    }

    private func pickImages() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK {
            do {
                guard !panel.urls.isEmpty else { return }
                guard panel.urls.count <= maxCount else {
                    throw ImagePickerError.tooManyFiles(maxCount: maxCount)
                }

                var selected: [FileRef] = []
                var failedCount = 0
                var firstError: Error?

                for url in panel.urls {
                    do {
                        let data = try loadValidatedImage(at: url)
                        selected.append(FileRef(data: data, name: url.lastPathComponent, mime: url.mimeType()))
                    } catch {
                        failedCount += 1
                        if firstError == nil { firstError = error }
                    }
                }

                files = selected
                generateThumbnails(for: selected)
                if let firstError {
                    errorMessage = failedCount == 1
                        ? firstError.localizedDescription
                        : "\(firstError.localizedDescription)，另有 \(failedCount - 1) 个文件未添加"
                } else {
                    errorMessage = nil
                }
            } catch {
                files = []
                thumbnails = []
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadValidatedImage(at url: URL) throws -> Data {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
        guard let contentType = values.contentType, contentType.conforms(to: .image) else {
            throw ImagePickerError.unsupportedType
        }

        let fileSize = values.fileSize ?? 0
        guard fileSize > 0 else { throw ImagePickerError.emptyFile }
        guard fileSize <= 25 * 1024 * 1024 else { throw ImagePickerError.fileTooLarge(maxBytes: 25 * 1024 * 1024) }

        return try Data(contentsOf: url, options: [.mappedIfSafe])
    }

    private func generateThumbnails(for files: [FileRef]) {
        thumbnails = files.map { file in
            guard let source = CGImageSourceCreateWithData(file.data as CFData, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 120,
                kCGImageSourceCreateThumbnailWithTransform: true
            ]
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                return nil
            }
            return NSImage(cgImage: cgImage, size: NSSize(width: 120, height: 120))
        }
    }
}

enum ImagePickerError: LocalizedError {
    case unsupportedType
    case emptyFile
    case fileTooLarge(maxBytes: Int)
    case tooManyFiles(maxCount: Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedType:
            return "文件类型不支持"
        case .emptyFile:
            return "文件为空"
        case .fileTooLarge(let maxBytes):
            return "文件过大，最大支持 \(maxBytes / 1024 / 1024) MB"
        case .tooManyFiles(let maxCount):
            return "最多选择 \(maxCount) 张参考图"
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
                                        .onTapGesture { ExternalURL.open(url) }
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
                    ExternalURL.open(url)
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
