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
    let nodeCachedOutputs: [String: [String: WorkflowValue]]
    let isRunning: Bool
    let onNodeSelect: (WorkflowNode) -> Void
    let onNodeEdit: (WorkflowNode) -> Void
    let onNodeDelete: (String) -> Void
    let onNodeRerun: (String) -> Void
    let onNodeReuse: (String) -> Void
    let onNodeRetry: (String) -> Void
    var highlightedNodeIds: Set<String> = []

    @State private var canvasOffset: CGPoint = .zero
    @State private var canvasScale: CGFloat = 1.0
    @State private var selectedNodeId: String?
    @State private var portDragState: PortDragState = .idle
    @State private var showAddNodeMenu = false
    @State private var addNodePosition: CGPoint = .zero
    @State private var showImageToVideoAlert = false
    @State private var pendingImageToVideoEdge: (sourcePortId: String, targetPortId: String, proposedMode: VideoMode)?

    // Pan/zoom base values for correct accumulation
    @State private var panBaseOffset: CGPoint = .zero
    @State private var zoomBaseScale: CGFloat = 1.0
    @State private var isCanvasPanning = false
    @State private var edgeErrorMessage: String?
    @State private var edgeErrorMessageTask: Task<Void, Never>?

    private let minScale: CGFloat = 0.3
    private let maxScale: CGFloat = 3.0
    private let nodeWidth: CGFloat = 200
    private let headerHeight: CGFloat = 40
    private let portSpacing: CGFloat = 28
    private let portRowHeight: CGFloat = 28
    private let portRowGap: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                canvasBackground(in: geometry)
                canvasContent(in: geometry)

                if let message = edgeErrorMessage {
                    edgeErrorToast(message)
                }
            }
            .clipped()
            .gesture(canvasZoomGesture)
            .onTapGesture(count: 2) {
                withAnimation {
                    canvasScale = 1.0
                    canvasOffset = .zero
                    zoomBaseScale = 1.0
                    panBaseOffset = .zero
                    isCanvasPanning = false
                }
            }
            .overlay(alignment: .bottomTrailing) {
                canvasControls
                    .padding()
            }
            .alert("切换视频模式？", isPresented: $showImageToVideoAlert, presenting: pendingImageToVideoEdge) { edge in
                Button("切换至\(edge.proposedMode == .startEnd || edge.proposedMode == .firstLast ? "首尾帧" : "图生视频")") {
                    applyImageToVideoMode(proposedMode: edge.proposedMode, targetPortId: edge.targetPortId)
                    tryCreateEdge(from: edge.sourcePortId, to: edge.targetPortId)
                    pendingImageToVideoEdge = nil
                }
                Button("取消连线", role: .cancel) {
                    pendingImageToVideoEdge = nil
                }
            } message: { edge in
                Text(edge.proposedMode == .startEnd || edge.proposedMode == .firstLast
                     ? "检测到图片连接，是否将视频节点切换为「首尾帧」模式并建立连线？"
                     : "检测到图片连接，是否将视频节点切换为「图生视频」模式并建立连线？")
            }
            .onDisappear {
                edgeErrorMessageTask?.cancel()
                edgeErrorMessageTask = nil
            }
        }
    }

    // MARK: - Edge Error Toast

    private func edgeErrorToast(_ message: String) -> some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 14))
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: Color.black.opacity(0.15), radius: 8)
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.25), value: edgeErrorMessage != nil)
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

            // Recommendation panel for selected node
            if let selectedId = selectedNodeId,
               let selectedNode = definition.nodes.first(where: { $0.id == selectedId }) {
                recommendationPanel(for: selectedNode)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: recommendations.count)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedNodeId)
        .scaleEffect(canvasScale)
        .position(x: centerX, y: centerY)
        .frame(width: geometry.size.width, height: geometry.size.height)
        .contentShape(Rectangle())
        .gesture(canvasDragGesture(in: geometry))
    }

    // MARK: - Node View

    private func nodeView(for node: WorkflowNode, in geometry: GeometryProxy, centerX: CGFloat, centerY: CGFloat) -> some View {
        let status = nodeStatuses[node.id] ?? .pending
        let isSelected = selectedNodeId == node.id

        let hasCachedOutputs: Bool = {
            guard let cached = nodeCachedOutputs[node.id] else { return false }
            return node.outputPorts.allSatisfy { cached[$0.id] != nil }
        }()

        return WorkflowNodeView(
            node: node,
            nodeStatus: status,
            isSelected: isSelected || highlightedNodeIds.contains(node.id),
            onDragChanged: { _ in },
            onDragEnded: { translation in
                moveNode(node.id, by: translation)
            },
            onPortDragStart: { _, _, _ in },
            onPortDragEnd: { _, _, _ in },
            onSelect: {
                selectedNodeId = node.id
            },
            onDelete: {
                deleteNode(node.id)
            },
            onNodeRerun: { onNodeRerun(node.id) },
            onNodeReuse: { onNodeReuse(node.id) },
            onNodeRetry: { onNodeRetry(node.id) },
            onNodeEdit: { onNodeEdit(node) },
            hasCachedOutputs: hasCachedOutputs
        )
        .position(
            x: node.position.x + nodeWidth / 2,
            y: node.position.y + nodeHeight(for: node) / 2
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
        guard let yOffset = portCenterYOffset(node: node, portId: portId, isInput: isInput) else {
            return CGPoint(x: node.position.x, y: node.position.y)
        }
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

    // MARK: - Canvas Drag Gesture

    private func canvasDragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let centerX = geometry.size.width / 2 + canvasOffset.x
                let centerY = geometry.size.height / 2 + canvasOffset.y

                if case .idle = portDragState, !isCanvasPanning {
                    if let (portId, nodeId, isInput) = hitTestPort(at: value.startLocation, centerX: centerX, centerY: centerY) {
                        if !isInput {
                            guard let sourceNode = definition.nodes.first(where: { $0.id == nodeId }) else { return }
                            let worldPos = portWorldPosition(node: sourceNode, portId: portId, isInput: false)
                            portDragState = .dragging(
                                sourcePortId: portId,
                                sourceNodeId: nodeId,
                                sourceIsOutput: true,
                                sourcePoint: worldPos,
                                currentPoint: value.location
                            )
                        }
                    } else if hitTestNode(at: value.startLocation, centerX: centerX, centerY: centerY) == nil {
                        isCanvasPanning = true
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
                } else if isCanvasPanning {
                    canvasOffset = CGPoint(
                        x: panBaseOffset.x + value.translation.width,
                        y: panBaseOffset.y + value.translation.height
                    )
                }
            }
            .onEnded { value in
                let centerX = geometry.size.width / 2 + canvasOffset.x
                let centerY = geometry.size.height / 2 + canvasOffset.y

                if case .dragging(let sourcePortId, _, _, _, _) = portDragState {
                    if let (targetPortId, targetNodeId, targetIsInput) = hitTestPort(at: value.location, centerX: centerX, centerY: centerY) {
                        if targetIsInput {
                            switch evaluateImageToVideoDrop(sourcePortId: sourcePortId, targetPortId: targetPortId, targetNodeId: targetNodeId) {
                            case .prompt(let mode):
                                pendingImageToVideoEdge = (sourcePortId, targetPortId, mode)
                                showImageToVideoAlert = true
                            case .reject(let reason):
                                showEdgeError(reason)
                            case .notApplicable:
                                tryCreateEdge(from: sourcePortId, to: targetPortId)
                            }
                        }
                    }
                } else if isCanvasPanning {
                    panBaseOffset = canvasOffset
                }
                portDragState = .idle
                isCanvasPanning = false
            }
    }

    private func hitTestPort(at screenPoint: CGPoint, centerX: CGFloat, centerY: CGFloat) -> (portId: String, nodeId: String, isInput: Bool)? {
        let worldPoint = screenToCanvas(screenPoint, centerX: centerX, centerY: centerY)

        for node in definition.nodes {
            // Check input ports
            for port in node.inputPorts {
                guard let yOffset = portCenterYOffset(node: node, portId: port.id, isInput: true) else { continue }
                let portCenter = CGPoint(
                    x: node.position.x,
                    y: node.position.y + yOffset
                )
                let distance = hypot(worldPoint.x - portCenter.x, worldPoint.y - portCenter.y)
                if distance < 15 {
                    return (port.id, node.id, true)
                }
            }

            // Check output ports
            for port in node.outputPorts {
                guard let yOffset = portCenterYOffset(node: node, portId: port.id, isInput: false) else { continue }
                let portCenter = CGPoint(
                    x: node.position.x + nodeWidth,
                    y: node.position.y + yOffset
                )
                let distance = hypot(worldPoint.x - portCenter.x, worldPoint.y - portCenter.y)
                if distance < 15 {
                    return (port.id, node.id, false)
                }
            }
        }

        return nil
    }

    private func hitTestNode(at screenPoint: CGPoint, centerX: CGFloat, centerY: CGFloat) -> WorkflowNode? {
        let worldPoint = screenToCanvas(screenPoint, centerX: centerX, centerY: centerY)

        return definition.nodes.first { node in
            return worldPoint.x >= node.position.x
                && worldPoint.x <= node.position.x + nodeWidth
                && worldPoint.y >= node.position.y
                && worldPoint.y <= node.position.y + nodeHeight(for: node)
        }
    }

    private func nodeHeight(for node: WorkflowNode) -> CGFloat {
        headerHeight + portsHeight(for: node) + configPreviewHeight(for: node)
    }

    private func portsHeight(for node: WorkflowNode) -> CGFloat {
        let inputCount = node.inputPorts.count
        let outputCount = node.outputPorts.count
        let rowCount = inputCount + outputCount
        let gapCount = max(inputCount - 1, 0) + max(outputCount - 1, 0)
        let dividerHeight: CGFloat = inputCount > 0 && outputCount > 0 ? 1 : 0
        return 16 + CGFloat(rowCount) * portSpacing + CGFloat(gapCount) * portRowGap + dividerHeight
    }

    private func configPreviewHeight(for node: WorkflowNode) -> CGFloat {
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

    private func portCenterYOffset(node: WorkflowNode, portId: String, isInput: Bool) -> CGFloat? {
        let ports = isInput ? node.inputPorts : node.outputPorts
        guard let index = ports.firstIndex(where: { $0.id == portId }) else { return nil }

        let inputSectionHeight = CGFloat(node.inputPorts.count) * portRowHeight
            + CGFloat(max(node.inputPorts.count - 1, 0)) * portRowGap
        let outputStartOffset = node.inputPorts.isEmpty ? 0 : inputSectionHeight + 1
        let sectionOffset = isInput ? 0 : outputStartOffset

        return headerHeight + 8 + sectionOffset + CGFloat(index) * (portRowHeight + portRowGap) + portRowHeight / 2
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
                    zoomBaseScale = canvasScale
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
                    zoomBaseScale = 1.0
                    panBaseOffset = .zero
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
                    zoomBaseScale = canvasScale
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

    private var canvasZoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                canvasScale = min(max(zoomBaseScale * value, minScale), maxScale)
            }
            .onEnded { _ in
                zoomBaseScale = canvasScale
            }
    }

    // MARK: - Recommendations

    private var recommendations: [RecommendedNode] {
        guard let selectedId = selectedNodeId else { return [] }
        return definition.recommendedDownstreamNodes(for: selectedId)
    }

    private func recommendationPanel(for node: WorkflowNode) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption2)
                    .foregroundColor(.accentColor)
                Text("节点操作")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    onNodeEdit(node)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.caption2)
                        Text("编辑")
                            .font(.caption2)
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("编辑节点配置")
            }

            if !recommendations.isEmpty {
                Divider()

                ForEach(recommendations) { rec in
                    Button {
                        addRecommendedNode(rec)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: rec.nodeType.icon)
                                .font(.system(size: 11))
                                .foregroundColor(.accentColor)
                                .frame(width: 16)
                            Text(rec.nodeType.displayName)
                                .font(.caption)
                                .foregroundColor(.primary)
                            Text(rec.reason)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.accentColor.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: Color.black.opacity(0.15), radius: 6)
        .frame(width: 220)
        .position(
            x: node.position.x + nodeWidth / 2,
            y: node.position.y + nodeHeight(for: node) + 20
        )
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    private func addRecommendedNode(_ recommendation: RecommendedNode) {
        guard let sourceNode = definition.nodes.first(where: { $0.id == selectedNodeId }) else { return }

        let newPos = WorkflowPoint(
            x: sourceNode.position.x + nodeWidth + 150,
            y: sourceNode.position.y
        )

        let newNode: WorkflowNode
        switch recommendation.nodeType {
        case .textInput:
            newNode = WorkflowNode(title: "文本输入", position: newPos, config: .textInput(TextInputNodeConfig()))
        case .promptTemplate:
            // Build a throwaway node to learn the default input port name for this role,
            // then prefill the template with it so {{portName}} resolves at runtime.
            let templatePortName: String = {
                let temp = WorkflowNode(title: "", config: .promptTemplate(PromptTemplateNodeConfig()))
                return temp.inputPorts.first(where: { $0.role == recommendation.targetPortRole })?.name ?? "变量"
            }()
            newNode = WorkflowNode(title: "提示词模板", position: newPos, config: .promptTemplate(PromptTemplateNodeConfig(template: "{{\(templatePortName)}}")))
        case .imageGen:
            newNode = WorkflowNode(title: "图片生成", position: newPos, config: .imageGen(ImageGenNodeConfig()))
        case .videoGen:
            var videoConfig = VideoGenNodeConfig()
            if case .setVideoMode(let mode) = recommendation.adjustment {
                videoConfig.mode = mode
            }
            newNode = WorkflowNode(title: "视频生成", position: newPos, config: .videoGen(videoConfig))
        case .resultOutput:
            newNode = WorkflowNode(title: "结果输出", position: newPos, config: .resultOutput(ResultOutputNodeConfig()))
        }

        definition.nodes.append(newNode)

        if let targetPort = newNode.inputPorts.first(where: { $0.role == recommendation.targetPortRole }) {
            definition.edges.removeAll(where: { $0.targetPortId == targetPort.id })
            let edge = WorkflowEdge(
                sourceNodeId: sourceNode.id,
                sourcePortId: recommendation.sourcePortId,
                targetNodeId: newNode.id,
                targetPortId: targetPort.id
            )
            definition.edges.append(edge)
        }

        selectedNodeId = newNode.id
    }

    private func applyImageToVideoMode(proposedMode: VideoMode, targetPortId: String) {
        guard let nodeIndex = definition.nodes.firstIndex(where: { $0.inputPorts.contains(where: { $0.id == targetPortId }) }),
              case .videoGen(var config) = definition.nodes[nodeIndex].config else { return }
        config.mode = proposedMode
        definition.nodes[nodeIndex].config = .videoGen(config)
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
        else {
            showEdgeError("找不到节点或端口")
            return
        }

        guard sourceNode.id != targetNode.id else {
            showEdgeError("端口不能连接到同一节点")
            return
        }

        let sourcePort = sourceNode.outputPorts.first(where: { $0.id == sourcePortId })!
        let targetPort = targetNode.inputPorts.first(where: { $0.id == targetPortId })!

        guard targetPort.portType == .any || sourcePort.portType == .any || sourcePort.portType == targetPort.portType else {
            showEdgeError("端口类型不兼容：\(sourcePort.portType.displayName) → \(targetPort.portType.displayName)")
            return
        }

        // Remove existing edge to this input port (single source)
        definition.edges.removeAll(where: { $0.targetPortId == targetPortId })

        let edge = WorkflowEdge(
            sourceNodeId: sourceNode.id,
            sourcePortId: sourcePortId,
            targetNodeId: targetNode.id,
            targetPortId: targetPortId
        )
        definition.edges.append(edge)
        edgeErrorMessageTask?.cancel()
        edgeErrorMessageTask = nil
        edgeErrorMessage = nil
    }

    private func showEdgeError(_ message: String) {
        edgeErrorMessageTask?.cancel()
        edgeErrorMessage = message
        edgeErrorMessageTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                edgeErrorMessage = nil
            }
        }
    }

    /// Result of evaluating whether to prompt for a video mode switch on image→video drag.
    private enum ImageToVideoRecommendation {
        /// Show alert proposing this mode switch.
        case prompt(mode: VideoMode)
        /// This edge would be useless — show error and reject.
        case reject(reason: String)
        /// Not an image→video situation, proceed as normal.
        case notApplicable
    }

    /// Evaluate whether an image→video drop should prompt, reject, or proceed normally.
    private func evaluateImageToVideoDrop(sourcePortId: String, targetPortId: String, targetNodeId: String) -> ImageToVideoRecommendation {
        guard let sourceNode = definition.nodes.first(where: { $0.outputPorts.contains(where: { $0.id == sourcePortId }) }),
              let sourcePort = sourceNode.outputPorts.first(where: { $0.id == sourcePortId }),
              sourcePort.portType == .image,
              let targetNode = definition.nodes.first(where: { $0.id == targetNodeId }),
              case .videoGen(let config) = targetNode.config,
              let targetPort = targetNode.inputPorts.first(where: { $0.id == targetPortId }) else { return .notApplicable }

        switch config.genType {
        case .grok:
            return .reject(reason: "Grok 仅支持文生视频，无法使用图片输入")
        case .wan:
            return .reject(reason: "Wan 暂不支持在工作流中使用")
        case .seedance:
            guard targetPort.role == .firstFrame else {
                return .reject(reason: "Seedance 参考模式下不支持从图片端口输入，请使用首帧端口")
            }
            return config.mode == .text ? .prompt(mode: .firstLast) : .notApplicable
        case .veo:
            guard targetPort.role == .image || targetPort.role == .firstFrame else { return .notApplicable }
            let targetMode = targetPort.role == .firstFrame ? VideoMode.startEnd : VideoMode.image
            let validModes = VeoRules.validModeValues(channel: config.channel.rawValue, model: config.model)
            guard validModes.contains(targetMode.rawValue) else {
                return .reject(reason: "当前 Veo 渠道/模型不支持 \(targetMode == .image ? "图生视频" : "首尾帧") 模式")
            }
            return config.mode == .text ? .prompt(mode: targetMode) : .notApplicable
        }
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
        nodeCachedOutputs: [:],
        isRunning: false,
        onNodeSelect: { _ in },
        onNodeEdit: { _ in },
        onNodeDelete: { _ in },
        onNodeRerun: { _ in },
        onNodeReuse: { _ in },
        onNodeRetry: { _ in }
    )
    .frame(width: 800, height: 600)
}
