import SwiftUI
import UniformTypeIdentifiers

struct GrokVideoView: View {
    @EnvironmentObject var api: APIService
    
    @State private var prompt = ""
    @State private var channel = "budget"
    @State private var mode = "text"
    @State private var ratio = "9:16"
    @State private var resolution = "720p"
    @State private var duration = "6"
    @State private var imageFiles: [FileRef] = []
    @State private var videoFile: FileRef?
    
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var resultTaskId: String?
    
    var durationOptions: [(String, String)] {
        if channel == "official" {
            return [("6","6s"),("10","10s")]
        }
        return [("6","6s"),("8","8s"),("10","10s"),("12","12s"),("15","15s"),("20","20s"),("30","30s")]
    }
    
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
                    opt("模式", $mode, [
                        ("text","纯文本"),("image","图生视频"),("reference","多图参考"),
                        ("extend","视频续写"),("edit","视频编辑")
                    ])
                    opt("画幅", $ratio, [("9:16","9:16"),("16:9","16:9"),("1:1","1:1"),("2:3","2:3"),("3:2","3:2")])
                    opt("分辨率", $resolution, [("720p","720p"),("480p","480p")])
                    opt("时长", $duration, durationOptions)
                }
                
                MultiImagePickerRow(label: "参考图片", files: $imageFiles, maxCount: 10)
                
                if mode == "extend" || mode == "edit" {
                    FilePickerRow(label: "视频素材", types: [.movie, .video]) { data, name, mime in
                        videoFile = FileRef(data: data, name: name, mime: mime)
                    }
                }
                
                HStack {
                    Button(action: startGeneration) {
                        if isGenerating {
                            ProgressView().scaleEffect(0.8); Text("提交中...")
                        } else {
                            Label("生成 Grok 视频", systemImage: "brain")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
                }
                
                if let err = errorMessage { Text(err).foregroundColor(.red).font(.caption) }
                if let tid = resultTaskId {
                    TaskPollingView(taskId: tid, pollType: .grok, api: api)
                }
            }
            .padding(24)
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
                let images = imageFiles.map { ($0.data, $0.name, $0.mime) }
                let result = try await api.generateGrokVideo(
                    prompt: prompt, channel: channel, mode: mode,
                    aspectRatio: ratio, resolution: resolution, duration: duration,
                    imageFiles: images,
                    videoData: videoFile?.data, videoName: videoFile?.name, videoMime: videoFile?.mime
                )
                if let tid = result.taskId {
                    resultTaskId = tid
                    api.addTask(id: tid, type: "Grok 视频", desc: String(prompt.prefix(30)))
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
