import SwiftUI

struct BananaView: View {
    @EnvironmentObject var api: APIService
    
    @State private var prompt = ""
    @State private var provider = "official"
    @State private var imageData: Data?
    @State private var imageName: String?
    @State private var imageMime: String?
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
                
                FilePickerRow(label: "参考图片", types: [.image]) { data, name, mime in
                    imageData = data; imageName = name; imageMime = mime
                }
                
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
                    imageData: imageData, fileName: imageName, mimeType: imageMime
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
    
    @State private var prompt = ""
    @State private var width = 720
    @State private var height = 1280
    @State private var seconds = 5
    @State private var imageData: Data?
    @State private var imageName: String?
    @State private var imageMime: String?
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var taskId: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("提示词").font(.headline)
                    TextField("描述动作...", text: $prompt).textFieldStyle(.roundedBorder)
                }
                
                HStack(spacing: 12) {
                    intField("宽度", $width)
                    intField("高度", $height)
                    intField("秒数", $seconds)
                }
                
                FilePickerRow(label: "输入图片", types: [.image]) { data, name, mime in
                    imageData = data; imageName = name; imageMime = mime
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
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || imageData == nil || isGenerating)
                }
                
                if let err = errorMessage { Text(err).foregroundColor(.red).font(.caption) }
                
                if let tid = taskId {
                    Text("✅ 任务已提交: \(tid)").font(.caption).foregroundColor(.green)
                }
            }
            .padding(24)
        }
    }
    
    private func intField(_ label: String, _ value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            TextField(label, value: value, format: .number).textFieldStyle(.roundedBorder).frame(width: 80)
        }
    }
    
    private func startGeneration() {
        guard let data = imageData, let name = imageName, let mime = imageMime else { return }
        guard width > 0, height > 0, seconds > 0, seconds <= 30 else {
            errorMessage = "宽高和秒数必须为正数，秒数最大 30"
            return
        }
        isGenerating = true; errorMessage = nil
        Task {
            do {
                let result = try await api.generateWanVideo(
                    imageData: data, fileName: name, mimeType: mime,
                    prompt: prompt, width: width, height: height, seconds: seconds
                )
                if let tid = result.taskId {
                    taskId = tid
                    api.addTask(id: tid, type: "Wan 视频", desc: String(prompt.prefix(30)))
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
