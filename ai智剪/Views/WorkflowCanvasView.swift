import SwiftUI

// MARK: - Canvas Node Position

struct CanvasNodePosition: Identifiable {
    let id: String
    var position: CGPoint
}

// MARK: - Port Drag State

enum PortDragState {
    case idle
    case dragging(sourcePortId: String, sourceNodeId: String, sourceIsOutput: Bool, sourcePoint: CGPoint, currentPoint: CGPoint)
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

    // Pan/zoom base values for correct accumulation
    @State private var panBaseOffset: CGPoint = .zero
    @State private var zoomBaseScale: CGFloat = 1.0

    private let minScale: CGFloat = 0.3
    private let maxScale: CGFloat = 3.0
    private let nodeWidth: CGFloat = 200
    private let headerHeight: CGFloat = 40
    private let portSpacing: CGFloat = 28
    private let portRowHeight: CGFloat = 28

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
            if case .dragging(_, _, _, let sourcePoint, let currentPoint) = portDragState {
                let sourceNode = findSourceNodeForDrag()
                let portType: WorkflowPortType = sourceNode?.outputPorts.first?.portType ?? .any
                TemporaryEdgeView(
                    sourcePoint: canvasToScreen(sourcePoint, centerX: centerX, centerY: centerY),
                    currentPoint: currentPoint,
                    portType: portType
                )
            }

            // Nodes
            ForEach(definition.nodes) { node in
                nodeView(for: node, in: geometry, centerX: centerX, centerY: centerY)
            }
        }
        .scaleEffect(canvasScale)
        .position(x: centerX, y: centerY)
        .frame(width: geometry.size.width, height: geometry.size.height)
        .contentShape(Rectangle())
        .gesture(portDragGesture(in: geometry))
    }

    // MARK: - Node View

    private func nodeView(for node: WorkflowNode, in geometry: GeometryProxy, centerX: CGFloat, centerY: CGFloat) -> some View {
        let status = nodeStatuses[node.id] ?? .pending
        let isSelected = selectedNodeId == node.id

        return WorkflowNodeView(
            node: node,
            nodeStatus: status,
            isSelected: isSelected,
            onDragChanged: { _ in },
            onDragEnded: { translation in
                moveNode(node.id, by: translation)
            },
            onPortDragStart: { _, _, _ in },
            onPortDragEnd: { _, _, _ in },
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
            y: node.position.y + headerHeight / 2 + 50
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

        let sourcePoint = portWorldPosition(node: sourceNode, portId: sourcePort.id, isInput: false)
        let targetPoint = portWorldPosition(node: targetNode, portId: targetPort!.id, isInput: true)

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

    // MARK: - Port Position Calculation

    private func portWorldPosition(node: WorkflowNode, portId: String, isInput: Bool) -> CGPoint {
        let portList = isInput ? node.inputPorts : node.outputPorts
        guard let portIndex = portList.firstIndex(where: { $0.id == portId }) else {
            return CGPoint(x: node.position.x, y: node.position.y)
        }

        let yOffset = headerHeight + 8 + CGFloat(portIndex) * portRowHeight + portRowHeight / 2
        let xOffset: CGFloat = isInput ? 0 : nodeWidth

        return CGPoint(
            x: node.position.x + xOffset,
            y: node.position.y + yOffset
        )
    }

    private func canvasToScreen(_ worldPoint: CGPoint, centerX: CGFloat, centerY: CGFloat) -> CGPoint {
        CGPoint(
            x: (worldPoint.x) * canvasScale + centerX - (centerX * canvasScale),
            y: (worldPoint.y) * canvasScale + centerY - (centerY * canvasScale)
        )
    }

    private func screenToCanvas(_ screenPoint: CGPoint, centerX: CGFloat, centerY: CGFloat) -> CGPoint {
        CGPoint(
            x: (screenPoint.x - centerX + (centerX * canvasScale)) / canvasScale,
            y: (screenPoint.y - centerY + (centerY * canvasScale)) / canvasScale
        )
    }

    private func findSourceNodeForDrag() -> WorkflowNode? {
        if case .dragging(_, let sourceNodeId, _, _, _) = portDragState {
            return definition.nodes.first(where: { $0.id == sourceNodeId })
        }
        return nil
    }

    // MARK: - Port Drag Gesture (canvas-level)

    private func portDragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let centerX = geometry.size.width / 2 + canvasOffset.x
                let centerY = geometry.size.height / 2 + canvasOffset.y

                if case .idle = portDragState {
                    // Try to find a port near the start location
                    if let (portId, nodeId, isInput) = hitTestPort(at: value.startLocation, centerX: centerX, centerY: centerY) {
                        if !isInput {
                            let worldPos = portWorldPosition(
                                node: definition.nodes.first(where: { $0.id == nodeId })!,
                                portId: portId,
                                isInput: false
                            )
                            portDragState = .dragging(
                                sourcePortId: portId,
                                sourceNodeId: nodeId,
                                sourceIsOutput: true,
                                sourcePoint: worldPos,
                                currentPoint: value.location
                            )
                        }
                    }
                }

                if case .dragging(let sourcePortId, let sourceNodeId, let sourceIsOutput, let sourcePoint, _) = portDragState {
                    portDragState = .dragging(
                        sourcePortId: sourcePortId,
                        sourceNodeId: sourceNodeId,
                        sourceIsOutput: sourceIsOutput,
                        sourcePoint: sourcePoint,
                        currentPoint: value.location
                    )
                }
            }
            .onEnded { value in
                let centerX = geometry.size.width / 2 + canvasOffset.x
                let centerY = geometry.size.height / 2 + canvasOffset.y

                if case .dragging(let sourcePortId, _, _, _, _) = portDragState {
                    // Find target port at end location
                    if let (targetPortId, _, targetIsInput) = hitTestPort(at: value.location, centerX: centerX, centerY: centerY) {
                        if targetIsInput {
                            tryCreateEdge(from: sourcePortId, to: targetPortId)
                        }
                    }
                }
                portDragState = .idle
            }
    }

    private func hitTestPort(at screenPoint: CGPoint, centerX: CGFloat, centerY: CGFloat) -> (portId: String, nodeId: String, isInput: Bool)? {
        let worldPoint = screenToCanvas(screenPoint, centerX: centerX, centerY: centerY)

        for node in definition.nodes {
            // Check input ports
            for (index, port) in node.inputPorts.enumerated() {
                let portCenter = CGPoint(
                    x: node.position.x,
                    y: node.position.y + headerHeight + 8 + CGFloat(index) * portRowHeight + portRowHeight / 2
                )
                let distance = hypot(worldPoint.x - portCenter.x, worldPoint.y - portCenter.y)
                if distance < 15 {
                    return (port.id, node.id, true)
                }
            }

            // Check output ports
            for (index, port) in node.outputPorts.enumerated() {
                let portCenter = CGPoint(
                    x: node.position.x + nodeWidth,
                    y: node.position.y + headerHeight + 8 + CGFloat(index) * portRowHeight + portRowHeight / 2
                )
                let distance = hypot(worldPoint.x - portCenter.x, worldPoint.y - portCenter.y)
                if distance < 15 {
                    return (port.id, node.id, false)
                }
            }
        }

        return nil
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

    // MARK: - Gestures (fixed accumulation)

    private var canvasPanGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                canvasOffset = CGPoint(
                    x: panBaseOffset.x + value.translation.width,
                    y: panBaseOffset.y + value.translation.height
                )
            }
            .onEnded { value in
                panBaseOffset = canvasOffset
            }
    }

    private var canvasZoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                canvasScale = min(max(zoomBaseScale * value, minScale), maxScale)
            }
            .onEnded { _ in
                zoomBaseScale = canvasScale
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

        // Remove existing edge to this input port (single source)
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
