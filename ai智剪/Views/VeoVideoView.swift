import SwiftUI
import UniformTypeIdentifiers

struct VeoVideoView: View {
    @EnvironmentObject var api: APIService
    
    @State private var prompt = ""
    @State private var channel = "budget"
    @State private var model = "fast"
    @State private var mode = "text"
    @State private var ratio = "9:16"
    @State private var resolution = "720p"
    @State private var duration = "4"
    @State private var generateAudio = false
    @State private var negativePrompt = ""
    
    // File refs
    @State private var imageFile: FileRef?
    @State private var firstImageFile: FileRef?
    @State private var lastImageFile: FileRef?
    @State private var ref1: FileRef?
    @State private var ref2: FileRef?
    @State private var ref3: FileRef?
    @State private var videoFile: FileRef?
    
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var resultTaskId: String?
    
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
                    opt("渠道", $channel, [("budget","低价"),("official","官方")])
                    opt("模型", $model, [("fast","Fast"),("lite","Lite"),("pro","Pro")])
                    opt("模式", $mode, [
                        ("text","纯文本"),("image","图生视频"),
                        ("reference","多图参考"),("start_end","首尾帧"),("extend","视频续写")
                    ])
                    opt("画幅", $ratio, [("9:16","9:16"),("16:9","16:9"),("1:1","1:1")])
                    opt("分辨率", $resolution, [("720p","720p"),("1080p","1080p"),("4k","4K")])
                    opt("时长", $duration, [("4","4s"),("6","6s"),("8","8s")])
                }
                
                Toggle("生成音频", isOn: $generateAudio)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("反向提示词").font(.caption).foregroundColor(.secondary)
                    TextField("不希望出现的内容...", text: $negativePrompt).textFieldStyle(.roundedBorder)
                }
                
                if mode == "image" || mode == "reference" {
                    FilePickerRow(label: "参考图片", types: [.image], onClear: { imageFile = nil }) { d, n, m in imageFile = FileRef(data: d, name: n, mime: m) }
                }
                if mode == "start_end" {
                    FilePickerRow(label: "首帧图片", types: [.image], onClear: { firstImageFile = nil }) { d, n, m in firstImageFile = FileRef(data: d, name: n, mime: m) }
                    FilePickerRow(label: "尾帧图片", types: [.image], onClear: { lastImageFile = nil }) { d, n, m in lastImageFile = FileRef(data: d, name: n, mime: m) }
                }
                if mode == "reference" {
                    FilePickerRow(label: "参考图1", types: [.image], onClear: { ref1 = nil }) { d, n, m in ref1 = FileRef(data: d, name: n, mime: m) }
                    FilePickerRow(label: "参考图2", types: [.image], onClear: { ref2 = nil }) { d, n, m in ref2 = FileRef(data: d, name: n, mime: m) }
                    FilePickerRow(label: "参考图3", types: [.image], onClear: { ref3 = nil }) { d, n, m in ref3 = FileRef(data: d, name: n, mime: m) }
                }
                if mode == "extend" {
                    FilePickerRow(label: "视频素材", types: [.movie, .video], onClear: { videoFile = nil }) { d, n, m in videoFile = FileRef(data: d, name: n, mime: m) }
                }
                
                HStack {
                    Button(action: startGeneration) {
                        if isGenerating {
                            ProgressView().scaleEffect(0.8); Text("提交中...")
                        } else {
                            Label("生成 Veo 视频", systemImage: "globe")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
                }
                
                if let err = errorMessage { Text(err).foregroundColor(.red).font(.caption) }
                if let tid = resultTaskId {
                    TaskPollingView(taskId: tid, pollType: .veo, api: api)
                }
            }
            .padding(24)
            .onChange(of: mode) { _, newMode in
                if newMode != "image" && newMode != "reference" {
                    imageFile = nil
                }
                if newMode != "start_end" {
                    firstImageFile = nil; lastImageFile = nil
                }
                if newMode != "reference" {
                    ref1 = nil; ref2 = nil; ref3 = nil
                }
                if newMode != "extend" {
                    videoFile = nil
                }
            }
        }
    }
    
    private func opt(_ label: String, _ sel: Binding<String>, _ opts: [(String,String)]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            Picker("", selection: sel) {
                ForEach(opts, id: \.0) { Text($0.1).tag($0.0) }
            }.pickerStyle(.menu).labelsHidden()
        }
    }
    
    private func startGeneration() {
        isGenerating = true; errorMessage = nil; resultTaskId = nil
        Task {
            do {
                var params = VeoParams()
                params.channel = channel; params.model = model; params.mode = mode
                params.prompt = prompt; params.aspectRatio = ratio
                params.resolution = resolution; params.duration = duration
                params.generateAudio = generateAudio
                params.negativePrompt = negativePrompt.isEmpty ? nil : negativePrompt
                if let f = imageFile { params.imageData = f.data; params.imageName = f.name; params.imageMime = f.mime }
                if let f = firstImageFile { params.firstImageData = f.data; params.firstImageName = f.name; params.firstImageMime = f.mime }
                if let f = lastImageFile { params.lastImageData = f.data; params.lastImageName = f.name; params.lastImageMime = f.mime }
                if let f = ref1 { params.ref1Data = (f.data, f.name, f.mime) }
                if let f = ref2 { params.ref2Data = (f.data, f.name, f.mime) }
                if let f = ref3 { params.ref3Data = (f.data, f.name, f.mime) }
                if let f = videoFile { params.videoData = f.data; params.videoName = f.name; params.videoMime = f.mime }
                
                let result = try await api.generateVeoVideo(params: params)
                if let tid = result.ourTaskId {
                    resultTaskId = tid
                    api.addTask(id: tid, type: "Veo 视频", desc: String(prompt.prefix(30)))
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

struct FileRef {
    let data: Data
    let name: String
    let mime: String
}
