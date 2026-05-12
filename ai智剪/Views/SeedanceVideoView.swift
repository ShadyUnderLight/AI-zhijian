import SwiftUI
import UniformTypeIdentifiers

struct SeedanceVideoView: View {
    @EnvironmentObject var api: APIService
    
    @State private var prompt = ""
    @State private var mode = "reference"
    @State private var model = "dreamina-seedance-2-0-260128"
    @State private var ratio = "9:16"
    @State private var resolution = "720p"
    @State private var duration = 5
    @State private var count = 1
    @State private var generateAudio = true
    @State private var refImage: (Data, String, String)?
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var resultTaskIds: [String] = []
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("提示词").font(.headline)
                    TextEditor(text: $prompt)
                        .font(.body)
                        .frame(height: 60)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                }
                
                HStack(spacing: 12) {
                    opt("模式", $mode, [("reference", "全能参考"), ("first_last", "首尾帧")])
                    opt("模型", $model, [
                        ("dreamina-seedance-2-0-260128", "标准版"),
                        ("dreamina-seedance-2-0-fast-260128", "快速版")
                    ])
                    opt("画幅", $ratio, [("9:16","9:16"),("16:9","16:9"),("1:1","1:1")])
                    opt("分辨率", $resolution, [("720p","720p"),("1080p","1080p"),("2k","2K"),("4k","4K")])
                    opt("秒数", Binding(get: { "\(duration)" }, set: { duration = Int($0) ?? 5 }),
                        [("4","4s"),("5","5s"),("8","8s"),("10","10s"),("15","15s")])
                    opt("数量", Binding(get: { "\(count)" }, set: { count = Int($0) ?? 1 }),
                        [("1","1"),("2","2"),("3","3"),("4","4")])
                }
                
                Toggle("生成音频", isOn: $generateAudio)
                
                FilePickerRow(label: "参考图片", types: [.image]) { data, name, mime in
                    refImage = (data, name, mime)
                }
                
                HStack {
                    Button(action: startGeneration) {
                        if isGenerating {
                            ProgressView().scaleEffect(0.8)
                            Text("提交中...")
                        } else {
                            Label("生成视频", systemImage: "video.badge.plus")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
                }
                
                if let err = errorMessage { Text(err).foregroundColor(.red).font(.caption) }
                
                ForEach(resultTaskIds, id: \.self) { tid in
                    TaskPollingView(taskId: tid, pollType: .seedance, api: api)
                }
            }
            .padding(24)
        }
    }
    
    private func startGeneration() {
        isGenerating = true; errorMessage = nil; resultTaskIds = []
        Task {
            do {
                let result = try await api.generateSeedanceVideo(
                    prompt: prompt, mode: mode, model: model,
                    ratio: ratio, resolution: resolution,
                    duration: duration, count: count,
                    generateAudio: generateAudio,
                    imageData: refImage?.0, fileName: refImage?.1, mimeType: refImage?.2
                )
                if let tasks = result.tasks {
                    resultTaskIds = tasks.map { $0.ourTaskId }
                    for t in tasks {
                        api.addTask(id: t.ourTaskId, type: "Seedance 2.0", desc: String(prompt.prefix(30)))
                    }
                } else {
                    errorMessage = result.message ?? "提交失败"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isGenerating = false
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
}

// MARK: - Reusable File Picker

struct FilePickerRow: View {
    let label: String
    let types: [UTType]
    var onPick: (Data, String, String) -> Void
    
    @State private var fileName: String?
    
    var body: some View {
        HStack {
            Text(label).font(.caption).foregroundColor(.secondary)
            Button("选择文件...") {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = types
                panel.allowsMultipleSelection = false
                if panel.runModal() == .OK, let url = panel.url {
                    if let data = try? Data(contentsOf: url) {
                        let mime = url.mimeType()
                        fileName = url.lastPathComponent
                        onPick(data, url.lastPathComponent, mime)
                    }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            if let name = fileName {
                Text(name).font(.caption).foregroundColor(.secondary).lineLimit(1)
            }
        }
    }
}

extension URL {
    func mimeType() -> String {
        if let utType = UTType(filenameExtension: pathExtension) {
            return utType.preferredMIMEType ?? "application/octet-stream"
        }
        return "application/octet-stream"
    }
}
