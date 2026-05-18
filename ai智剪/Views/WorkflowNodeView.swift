import SwiftUI

// MARK: - Port Position

struct PortPosition: Equatable {
    let portId: String
    let position: CGPoint
    let isInput: Bool
}

// MARK: - Workflow Node View

struct WorkflowNodeView: View {
    let node: WorkflowNode
    let nodeStatus: WorkflowNodeStatus
    let isSelected: Bool
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: (CGSize) -> Void
    let onPortDragStart: (String, Bool, CGPoint) -> Void
    let onPortDragEnd: (String, Bool, CGPoint) -> Void
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isDragging = false
    @State private var dragOffset: CGSize = .zero

    private let nodeWidth: CGFloat = 200
    private let portSpacing: CGFloat = 28
    private let headerHeight: CGFloat = 40
    private let portRowGap: CGFloat = 4

    var body: some View {
        VStack(spacing: 0) {
            headerView
            portsView
            configPreview
        }
        .frame(width: nodeWidth, height: nodeHeight, alignment: .top)
        .background(nodeBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: isSelected ? Color.accentColor.opacity(0.4) : Color.black.opacity(0.15),
                radius: isSelected ? 6 : 3)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .offset(x: dragOffset.width, y: dragOffset.height)
        .gesture(dragGesture)
        .onTapGesture { onSelect() }
        .contextMenu { contextMenu }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 8) {
            Image(systemName: node.type.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            Text(node.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            statusIndicator
        }
        .padding(.horizontal, 12)
        .frame(height: headerHeight)
        .background(headerBackground)
    }

    private var headerBackground: some View {
        LinearGradient(
            colors: [nodeTypeColor, nodeTypeColor.opacity(0.8)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var statusIndicator: some View {
        Group {
            switch nodeStatus {
            case .pending:
                Image(systemName: "circle")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
            case .running:
                ProgressView()
                    .scaleEffect(0.6)
                    .tint(.white)
            case .succeeded:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            case .skipped:
                Image(systemName: "forward.circle")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
            case .cancelled:
                Image(systemName: "stop.circle")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Ports

    private var portsView: some View {
        VStack(spacing: 0) {
            if !node.inputPorts.isEmpty {
                portSection(ports: node.inputPorts, isInput: true)
            }

            if !node.inputPorts.isEmpty && !node.outputPorts.isEmpty {
                Divider()
                    .padding(.horizontal, 8)
            }

            if !node.outputPorts.isEmpty {
                portSection(ports: node.outputPorts, isInput: false)
            }
        }
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .frame(height: portsHeight)
    }

    private func portSection(ports: [WorkflowPort], isInput: Bool) -> some View {
        VStack(spacing: portRowGap) {
            ForEach(ports) { port in
                portRow(port: port, isInput: isInput)
            }
        }
    }

    private func portRow(port: WorkflowPort, isInput: Bool) -> some View {
        HStack(spacing: 6) {
            if isInput {
                portDot(port: port, isInput: true)
                Text(port.name)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
                Spacer()
                Text(port.portType.displayName)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            } else {
                Spacer()
                Text(port.name)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
                Text(port.portType.displayName)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                portDot(port: port, isInput: false)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: portSpacing)
        .background(portHoverBackground(port: port))
    }

    private func portDot(port: WorkflowPort, isInput: Bool) -> some View {
        Circle()
            .fill(portColor(port.portType))
            .frame(width: 10, height: 10)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 1.5)
            )
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            // Port position tracking handled by parent
                        }
                }
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let globalPos = CGPoint(
                            x: node.position.x + (isInput ? 0 : nodeWidth),
                            y: node.position.y + portCenterY(portId: port.id, isInput: isInput)
                        )
                        onPortDragStart(port.id, isInput, globalPos)
                    }
                    .onEnded { value in
                        let globalPos = CGPoint(
                            x: node.position.x + (isInput ? 0 : nodeWidth),
                            y: node.position.y + portCenterY(portId: port.id, isInput: isInput)
                        )
                        onPortDragEnd(port.id, isInput, globalPos)
                    }
            )
    }

    private func portHoverBackground(port: WorkflowPort) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.clear)
            .contentShape(Rectangle())
    }

    // MARK: - Config Preview

    private var configPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch node.config {
            case .textInput(let config):
                previewText("文本内容", config.text)
            case .promptTemplate(let config):
                previewText("提示词模板", config.template)
            case .imageGen(let config):
                previewRow("类型", imageGenTypeName(config.genType))
                previewRow("规格", "\(config.aspectRatio.rawValue) · \(config.resolution.rawValue.uppercased()) · \(imageQualityName(config.quality))")
                previewRow("风格", config.photoReal ? "照片真实感" : "默认")
            case .videoGen(let config):
                previewRow("类型", videoGenTypeName(config.genType))
                previewRow("模式", "\(videoModeName(config.mode)) · \(videoChannelName(config.channel))")
                previewRow("模型", config.model)
                previewRow("规格", "\(config.aspectRatio.rawValue) · \(config.resolution.rawValue) · \(config.duration)s\(config.generateAudio ? " · 音频" : "")")
            case .resultOutput(let config):
                previewRow("输出标签", config.label)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: configPreviewHeight, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func previewText(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
            Text(previewValue(value))
                .font(.system(size: 11))
                .foregroundColor(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func previewRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 38, alignment: .leading)
            Text(previewValue(value))
                .font(.system(size: 11))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }

    // MARK: - Node Background

    private var nodeBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Node Type Color

    private var nodeTypeColor: Color {
        switch node.type {
        case .textInput: return .blue
        case .promptTemplate: return .purple
        case .imageGen: return .orange
        case .videoGen: return .pink
        case .resultOutput: return .green
        }
    }

    // MARK: - Layout

    private var nodeHeight: CGFloat {
        headerHeight + portsHeight + configPreviewHeight
    }

    private var portsHeight: CGFloat {
        let inputCount = node.inputPorts.count
        let outputCount = node.outputPorts.count
        let rowCount = inputCount + outputCount
        let gapCount = max(inputCount - 1, 0) + max(outputCount - 1, 0)
        let dividerHeight: CGFloat = inputCount > 0 && outputCount > 0 ? 1 : 0
        return 16 + CGFloat(rowCount) * portSpacing + CGFloat(gapCount) * portRowGap + dividerHeight
    }

    private var configPreviewHeight: CGFloat {
        switch node.config {
        case .textInput, .promptTemplate:
            return 78
        case .imageGen:
            return 88
        case .videoGen:
            return 120
        case .resultOutput:
            return 54
        }
    }

    private func portCenterY(portId: String, isInput: Bool) -> CGFloat {
        let ports = isInput ? node.inputPorts : node.outputPorts
        guard let index = ports.firstIndex(where: { $0.id == portId }) else {
            return headerHeight + 8 + portSpacing / 2
        }

        let inputSectionHeight = CGFloat(node.inputPorts.count) * portSpacing
            + CGFloat(max(node.inputPorts.count - 1, 0)) * portRowGap
        let outputStartOffset = node.inputPorts.isEmpty ? 0 : inputSectionHeight + 1
        let sectionOffset = isInput ? 0 : outputStartOffset

        return headerHeight + 8 + sectionOffset + CGFloat(index) * (portSpacing + portRowGap) + portSpacing / 2
    }

    private func previewValue(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未填写" : trimmed
    }

    private func imageGenTypeName(_ type: ImageGenType) -> String {
        switch type {
        case .gptImage: return "GPT-Image"
        case .banana: return "Banana"
        }
    }

    private func imageQualityName(_ quality: ImageQuality) -> String {
        switch quality {
        case .low: return "低画质"
        case .medium: return "中画质"
        case .high: return "高画质"
        }
    }

    private func videoGenTypeName(_ type: VideoGenType) -> String {
        switch type {
        case .veo: return "Veo"
        case .grok: return "Grok"
        case .seedance: return "Seedance"
        case .wan: return "Wan"
        }
    }

    private func videoChannelName(_ channel: VideoChannel) -> String {
        switch channel {
        case .official: return "官方"
        case .budget: return "低价"
        case .google: return "Google"
        }
    }

    private func videoModeName(_ mode: VideoMode) -> String {
        switch mode {
        case .text: return "文生视频"
        case .image: return "图生视频"
        case .reference: return "参考图"
        case .startEnd: return "首尾帧"
        case .extend: return "续写"
        case .firstLast: return "首尾帧"
        }
    }

    // MARK: - Port Color

    private func portColor(_ type: WorkflowPortType) -> Color {
        switch type {
        case .text: return .blue
        case .image: return .orange
        case .video: return .pink
        case .file: return .gray
        case .json: return .purple
        case .any: return .secondary
        }
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                isDragging = true
                dragOffset = value.translation
                onDragChanged(value.translation)
            }
            .onEnded { value in
                isDragging = false
                dragOffset = .zero
                onDragEnded(value.translation)
            }
    }

    // MARK: - Context Menu

    private var contextMenu: some View {
        Group {
            Button {
                onSelect()
            } label: {
                Label("选择", systemImage: "hand.point.up.left")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let node = WorkflowNode(
        title: "文本输入",
        position: WorkflowPoint(x: 100, y: 100),
        config: .textInput(TextInputNodeConfig(text: "测试文本"))
    )

    WorkflowNodeView(
        node: node,
        nodeStatus: .pending,
        isSelected: false,
        onDragChanged: { _ in },
        onDragEnded: { _ in },
        onPortDragStart: { _, _, _ in },
        onPortDragEnd: { _, _, _ in },
        onSelect: {},
        onDelete: {}
    )
    .frame(width: 400, height: 400)
    .padding()
}
