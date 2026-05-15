import SwiftUI

// MARK: - Canvas Node Position

struct CanvasNodePosition: Identifiable {
    let id: String
    var position: CGPoint
}

// MARK: - Port Drag State

enum PortDragState {
    case idle
    case dragging(sourcePortId: String, isInput: Bool, sourcePoint: CGPoint, currentPoint: CGPoint)
}

// MARK: - Workflow Canvas View

struct WorkflowCanvasView: View {
    @Binding var definition: WorkflowDefinition
    let nodeStatuses: [String: WorkflowNodeStatus]
    let isRunning: Bool
    let onNodeSelect: (WorkflowNode) -> Void
    let onNodeDelete: (String) -> Void

    @State private var canvasOffset: CGPoint = .zero
    @State private var canvasScale: CGFloat = 1.0
    @State private var selectedNodeId: String?
    @State private var portDragState: PortDragState = .idle
    @State private var showAddNodeMenu = false
    @State private var addNodePosition: CGPoint = .zero

    private let minScale: CGFloat = 0.3
    private let maxScale: CGFloat = 3.0
    private let nodeWidth: CGFloat = 200

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                canvasBackground(in: geometry)
                canvasContent(in: geometry)
            }
            .clipped()
            .gesture(canvasPanGesture)
            .gesture(canvasZoomGesture)
            .onTapGesture(count: 2) {
                withAnimation {
                    canvasScale = 1.0
                    canvasOffset = .zero
                }
            }
            .overlay(alignment: .bottomTrailing) {
                canvasControls
                    .padding()
            }
        }
    }

    // MARK: - Canvas Background

    private func canvasBackground(in geometry: GeometryProxy) -> some View {
        Canvas { context, size in
            let gridSpacing: CGFloat = 20 * canvasScale
            let offsetX = canvasOffset.x.truncatingRemainder(dividingBy: gridSpacing)
            let offsetY = canvasOffset.y.truncatingRemainder(dividingBy: gridSpacing)

            context.stroke(
                Path { path in
                    var x = offsetX
                    while x < size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        x += gridSpacing
                    }
                    var y = offsetY
                    while y < size.height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        y += gridSpacing
                    }
                },
                with: .color(Color.secondary.opacity(0.1)),
                lineWidth: 0.5
            )
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onTapGesture {
            selectedNodeId = nil
        }
        .onTapGesture(count: 2) {
            // Double click handled by parent
        }
    }

    // MARK: - Canvas Content

    private func canvasContent(in geometry: GeometryProxy) -> some View {
        let centerX = geometry.size.width / 2 + canvasOffset.x
        let centerY = geometry.size.height / 2 + canvasOffset.y

        return ZStack {
            // Edges
            ForEach(definition.edges) { edge in
                edgeView(for: edge)
            }

            // Temporary edge during drag
            if case .dragging(let sourcePortId, _, let sourcePoint, let currentPoint) = portDragState {
                let portType = findPortType(portId: sourcePortId)
                TemporaryEdgeView(
                    sourcePoint: transformPoint(sourcePoint, in: geometry),
                    currentPoint: currentPoint,
                    portType: portType
                )
            }

            // Nodes
            ForEach(definition.nodes) { node in
                nodeView(for: node, in: geometry)
            }
        }
        .scaleEffect(canvasScale)
        .position(x: centerX, y: centerY)
    }

    // MARK: - Node View

    private func nodeView(for node: WorkflowNode, in geometry: GeometryProxy) -> some View {
        let status = nodeStatuses[node.id] ?? .pending
        let isSelected = selectedNodeId == node.id

        return WorkflowNodeView(
            node: node,
            nodeStatus: status,
            isSelected: isSelected,
            onDragChanged: { translation in
                // Handled by onDragEnded
            },
            onDragEnded: { translation in
                moveNode(node.id, by: translation)
            },
            onPortDragStart: { portId, isInput, point in
                if !isInput {
                    portDragState = .dragging(
                        sourcePortId: portId,
                        isInput: isInput,
                        sourcePoint: point,
                        currentPoint: point
                    )
                }
            },
            onPortDragEnd: { portId, isInput, point in
                if case .dragging(let sourcePortId, _, _, _) = portDragState {
                    if isInput {
                        tryCreateEdge(from: sourcePortId, to: portId)
                    }
                }
                portDragState = .idle
            },
            onSelect: {
                selectedNodeId = node.id
                onNodeSelect(node)
            },
            onDelete: {
                deleteNode(node.id)
            }
        )
        .position(
            x: node.position.x + nodeWidth / 2,
            y: node.position.y + 50
        )
    }

    // MARK: - Edge View

    private func edgeView(for edge: WorkflowEdge) -> some View {
        let sourceNode = definition.nodes.first(where: { $0.id == edge.sourceNodeId })
        let targetNode = definition.nodes.first(where: { $0.id == edge.targetNodeId })

        guard let sourceNode, let targetNode else {
            return AnyView(EmptyView())
        }

        let sourcePort = sourceNode.outputPorts.first(where: { $0.id == edge.sourcePortId })
        let targetPort = targetNode.inputPorts.first(where: { $0.id == edge.targetPortId })

        guard let sourcePort, targetPort != nil else {
            return AnyView(EmptyView())
        }

        let sourcePoint = CGPoint(
            x: sourceNode.position.x + nodeWidth,
            y: sourceNode.position.y + 50
        )
        let targetPoint = CGPoint(
            x: targetNode.position.x,
            y: targetNode.position.y + 50
        )

        let isActive = isRunning && (nodeStatuses[edge.sourceNodeId] == .running || nodeStatuses[edge.targetNodeId] == .running)
        let isSelected = selectedNodeId == edge.sourceNodeId || selectedNodeId == edge.targetNodeId

        return AnyView(
            WorkflowEdgeView(
                edge: edge,
                sourcePoint: sourcePoint,
                targetPoint: targetPoint,
                portType: sourcePort.portType,
                isActive: isActive,
                isSelected: isSelected
            )
        )
    }

    // MARK: - Canvas Controls

    private var canvasControls: some View {
        VStack(spacing: 8) {
            Button {
                showAddNodeMenu = true
                addNodePosition = CGPoint(x: 0, y: 0)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.accentColor)
                    .shadow(radius: 2)
            }
            .help("添加节点")
            .popover(isPresented: $showAddNodeMenu) {
                addNodeMenu
            }

            Button {
                withAnimation {
                    canvasScale = min(canvasScale * 1.2, maxScale)
                }
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .help("放大")

            Button {
                withAnimation {
                    canvasScale = 1.0
                    canvasOffset = .zero
                }
            } label: {
                Image(systemName: "1.magnifyingglass")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .help("重置缩放")

            Button {
                withAnimation {
                    canvasScale = max(canvasScale / 1.2, minScale)
                }
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .help("缩小")

            Divider()
                .frame(width: 20)

            Text("\(Int(canvasScale * 100))%")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Add Node Menu

    private var addNodeMenu: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("添加节点")
                .font(.headline)
                .padding(.bottom, 4)

            ForEach(WorkflowNodeType.allCases, id: \.self) { type in
                Button {
                    addNode(type: type)
                    showAddNodeMenu = false
                } label: {
                    Label(type.displayName, systemImage: type.icon)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding()
        .frame(width: 200)
    }

    // MARK: - Gestures

    private var canvasPanGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                canvasOffset = CGPoint(
                    x: canvasOffset.x + value.translation.width,
                    y: canvasOffset.y + value.translation.height
                )
            }
    }

    private var canvasZoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = canvasScale * value
                canvasScale = min(max(newScale, minScale), maxScale)
            }
    }

    // MARK: - Actions

    private func moveNode(_ nodeId: String, by translation: CGSize) {
        guard let index = definition.nodes.firstIndex(where: { $0.id == nodeId }) else { return }
        definition.nodes[index].position = WorkflowPoint(
            x: definition.nodes[index].position.x + translation.width / canvasScale,
            y: definition.nodes[index].position.y + translation.height / canvasScale
        )
    }

    private func addNode(type: WorkflowNodeType) {
        let position = WorkflowPoint(
            x: addNodePosition.x - nodeWidth / 2,
            y: addNodePosition.y - 50
        )

        let node: WorkflowNode
        switch type {
        case .textInput:
            node = WorkflowNode(title: "文本输入", position: position, config: .textInput(TextInputNodeConfig()))
        case .promptTemplate:
            node = WorkflowNode(title: "提示词模板", position: position, config: .promptTemplate(PromptTemplateNodeConfig()))
        case .imageGen:
            node = WorkflowNode(title: "图片生成", position: position, config: .imageGen(ImageGenNodeConfig()))
        case .videoGen:
            node = WorkflowNode(title: "视频生成", position: position, config: .videoGen(VideoGenNodeConfig()))
        case .resultOutput:
            node = WorkflowNode(title: "结果输出", position: position, config: .resultOutput(ResultOutputNodeConfig()))
        }

        definition.nodes.append(node)
    }

    private func deleteNode(_ nodeId: String) {
        definition.nodes.removeAll(where: { $0.id == nodeId })
        definition.edges.removeAll(where: { $0.sourceNodeId == nodeId || $0.targetNodeId == nodeId })
        if selectedNodeId == nodeId {
            selectedNodeId = nil
        }
    }

    private func tryCreateEdge(from sourcePortId: String, to targetPortId: String) {
        guard let sourceNode = definition.nodes.first(where: { $0.outputPorts.contains(where: { $0.id == sourcePortId }) }),
              let targetNode = definition.nodes.first(where: { $0.inputPorts.contains(where: { $0.id == targetPortId }) })
        else { return }

        guard sourceNode.id != targetNode.id else { return }

        let sourcePort = sourceNode.outputPorts.first(where: { $0.id == sourcePortId })!
        let targetPort = targetNode.inputPorts.first(where: { $0.id == targetPortId })!

        guard targetPort.portType == .any || sourcePort.portType == .any || sourcePort.portType == targetPort.portType else { return }

        definition.edges.removeAll(where: { $0.targetPortId == targetPortId })

        let edge = WorkflowEdge(
            sourceNodeId: sourceNode.id,
            sourcePortId: sourcePortId,
            targetNodeId: targetNode.id,
            targetPortId: targetPortId
        )
        definition.edges.append(edge)
    }

    private func findPortType(portId: String) -> WorkflowPortType {
        for node in definition.nodes {
            if let port = node.outputPorts.first(where: { $0.id == portId }) {
                return port.portType
            }
            if let port = node.inputPorts.first(where: { $0.id == portId }) {
                return port.portType
            }
        }
        return .any
    }

    private func transformPoint(_ point: CGPoint, in geometry: GeometryProxy) -> CGPoint {
        let centerX = geometry.size.width / 2 + canvasOffset.x
        let centerY = geometry.size.height / 2 + canvasOffset.y
        return CGPoint(
            x: (point.x - centerX) / canvasScale + centerX,
            y: (point.y - centerY) / canvasScale + centerY
        )
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var definition = WorkflowDefinition.sample()

    WorkflowCanvasView(
        definition: $definition,
        nodeStatuses: [:],
        isRunning: false,
        onNodeSelect: { _ in },
        onNodeDelete: { _ in }
    )
    .frame(width: 800, height: 600)
}
