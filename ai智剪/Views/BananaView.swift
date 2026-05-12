import SwiftUI

struct BananaView: View {
    @EnvironmentObject var api: APIService
    
    @State private var prompt = ""
    @State private var provider = "third_party"
    @State private var referenceImages: [FileRef] = []
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var resultImage: NSImage?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("提示词").font(.headline)
                    TextEditor(text: $prompt)
                        .font(.body).frame(height: 60)
                        .scrollContentBackground(.hidden).padding(6)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                }
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("提供商").font(.caption2).foregroundColor(.secondary)
                        Picker("", selection: $provider) {
                            Text("官方 Gemini").tag("official")
                            Text("第三方 RunningHub").tag("third_party")
                        }.pickerStyle(.segmented)
                    }
                }
                
                MultiImagePickerRow(label: "参考图片", files: $referenceImages, maxCount: 3)
                
                HStack {
                    Button(action: startGeneration) {
                        if isGenerating {
                            ProgressView().scaleEffect(0.8); Text("生成中...")
                        } else {
                            Label("生成", systemImage: "paintbrush")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
                }
                
                if let err = errorMessage { Text(err).foregroundColor(.red).font(.caption) }
                
                if let img = resultImage {
                    Divider().padding(.vertical, 4)
                    Image(nsImage: img).resizable().scaledToFit()
                        .frame(maxHeight: 400).cornerRadius(8)
                }
            }
            .padding(24)
        }
    }
    
    private func startGeneration() {
        isGenerating = true; errorMessage = nil; resultImage = nil
        Task {
            do {
                if let data = try await api.generateBanana(
                    prompt: prompt, provider: provider,
                    referenceImages: referenceImages
                ) {
                    resultImage = NSImage(data: data)
                } else {
                    errorMessage = "未返回图片数据"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isGenerating = false
        }
    }
}

// MARK: - Wan Video View

struct WanVideoView: View {
    @EnvironmentObject var api: APIService
    
    @State private var mode = "image"
    @State private var prompt = ""
    @State private var width = 720
    @State private var height = 1280
    @State private var seconds = 5
    @State private var enable48G = false
    @State private var imageData: Data?
    @State private var imageName: String?
    @State private var imageMime: String?
    @State private var firstFrame: FileRef?
    @State private var lastFrame: FileRef?
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var taskId: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Picker("", selection: $mode) {
                    Text("图生视频").tag("image")
                    Text("首尾帧").tag("first_last")
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)

                VStack(alignment: .leading, spacing: 6) {
                    Text("提示词").font(.headline)
                    TextField(mode == "first_last" ? "描述首尾帧之间的变化（可选）" : "描述动作...", text: $prompt)
                        .textFieldStyle(.roundedBorder)
                }
                
                if mode == "image" {
                    HStack(spacing: 12) {
                        intField("宽度", $width)
                        intField("高度", $height)
                        intField("秒数", $seconds)
                    }

                    FilePickerRow(label: "输入图片", types: [.image], onClear: { imageData = nil; imageName = nil; imageMime = nil }) { data, name, mime in
                        imageData = data; imageName = name; imageMime = mime
                    }
                } else {
                    HStack(spacing: 12) {
                        intField("秒数", $seconds)
                        Toggle("48G 队列", isOn: $enable48G)
                            .toggleStyle(.checkbox)
                    }

                    FilePickerRow(label: "首帧图片", types: [.image], onClear: { firstFrame = nil }) { data, name, mime in
                        firstFrame = FileRef(data: data, name: name, mime: mime)
                    }
                    FilePickerRow(label: "尾帧图片", types: [.image], onClear: { lastFrame = nil }) { data, name, mime in
                        lastFrame = FileRef(data: data, name: name, mime: mime)
                    }
                }
                
                HStack {
                    Button(action: startGeneration) {
                        if isGenerating {
                            ProgressView().scaleEffect(0.8); Text("提交中...")
                        } else {
                            Label("生成视频", systemImage: "film")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSubmit || isGenerating)
                }
                
                if let err = errorMessage { Text(err).foregroundColor(.red).font(.caption) }
                
                if let tid = taskId {
                    TaskPollingView(taskId: tid, pollType: .wan, api: api)
                }
            }
            .padding(24)
            .onChange(of: mode) { _, newMode in
                taskId = nil
                errorMessage = nil
                if newMode == "image" {
                    firstFrame = nil; lastFrame = nil
                } else {
                    imageData = nil; imageName = nil; imageMime = nil
                }
            }
        }
    }

    private var canSubmit: Bool {
        if mode == "image" {
            return !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && imageData != nil
        }
        return firstFrame != nil && lastFrame != nil
    }
    
    private func intField(_ label: String, _ value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            TextField(label, value: value, format: .number).textFieldStyle(.roundedBorder).frame(width: 80)
        }
    }
    
    private func startGeneration() {
        guard width > 0, height > 0, seconds > 0, seconds <= 30 else {
            errorMessage = "宽高和秒数必须为正数，秒数最大 30"
            return
        }
        guard mode == "image" || (firstFrame != nil && lastFrame != nil) else {
            errorMessage = "请先选择首帧和尾帧图片"
            return
        }
        isGenerating = true; errorMessage = nil; taskId = nil
        Task {
            do {
                let result: TaskSubmitResponse
                if mode == "image" {
                    guard let data = imageData, let name = imageName, let mime = imageMime else { return }
                    result = try await api.generateWanVideo(
                        imageData: data, fileName: name, mimeType: mime,
                        prompt: prompt, width: width, height: height, seconds: seconds
                    )
                } else {
                    guard let firstFrame, let lastFrame else { return }
                    result = try await api.generateWanFirstLastVideo(
                        firstFrame: firstFrame,
                        lastFrame: lastFrame,
                        prompt: prompt,
                        seconds: seconds,
                        enable48G: enable48G
                    )
                }
                if let tid = result.taskId {
                    taskId = tid
                    api.addTask(id: tid, type: mode == "image" ? "Wan 视频" : "Wan 首尾帧", desc: String(prompt.prefix(30)))
                } else {
                    errorMessage = result.message ?? "提交失败"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isGenerating = false
        }
    }
}
