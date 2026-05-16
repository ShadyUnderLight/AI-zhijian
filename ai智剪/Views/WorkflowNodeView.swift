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

    var body: some View {
        VStack(spacing: 0) {
            headerView
            portsView
        }
        .frame(width: nodeWidth)
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
    }

    private func portSection(ports: [WorkflowPort], isInput: Bool) -> some View {
        VStack(spacing: 4) {
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
                            y: node.position.y + headerHeight + 8 + CGFloat(node.inputPorts.count) * portSpacing / 2
                        )
                        onPortDragStart(port.id, isInput, globalPos)
                    }
                    .onEnded { value in
                        let globalPos = CGPoint(
                            x: node.position.x + (isInput ? 0 : nodeWidth),
                            y: node.position.y + headerHeight + 8 + CGFloat(node.inputPorts.count) * portSpacing / 2
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
