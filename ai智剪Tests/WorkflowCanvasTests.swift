import XCTest
@testable import aiZhijian

final class WorkflowCanvasTests: XCTestCase {

    // MARK: - WorkflowNode Tests

    func testWorkflowNodeDefaultPorts() {
        let node = WorkflowNode(
            title: "文本输入",
            config: .textInput(TextInputNodeConfig())
        )

        XCTAssertTrue(node.inputPorts.isEmpty)
        XCTAssertEqual(node.outputPorts.count, 1)
        XCTAssertEqual(node.outputPorts.first?.portType, .text)
    }

    func testWorkflowNodeImageGenPorts() {
        let node = WorkflowNode(
            title: "图片生成",
            config: .imageGen(ImageGenNodeConfig())
        )

        XCTAssertEqual(node.inputPorts.count, 1)
        XCTAssertEqual(node.inputPorts.first?.portType, .text)
        XCTAssertEqual(node.outputPorts.count, 1)
        XCTAssertEqual(node.outputPorts.first?.portType, .image)
    }

    func testWorkflowNodeVideoGenPorts() {
        let node = WorkflowNode(
            title: "视频生成",
            config: .videoGen(VideoGenNodeConfig())
        )

        XCTAssertEqual(node.inputPorts.count, 4)
        XCTAssertTrue(node.inputPorts.contains(where: { $0.name == "提示词" && $0.portType == .text }))
        XCTAssertTrue(node.inputPorts.contains(where: { $0.name == "图片" && $0.portType == .image }))
        XCTAssertTrue(node.inputPorts.contains(where: { $0.name == "首帧图片" && $0.portType == .image }))
        XCTAssertTrue(node.inputPorts.contains(where: { $0.name == "尾帧图片" && $0.portType == .image }))
        XCTAssertEqual(node.outputPorts.count, 1)
        XCTAssertEqual(node.outputPorts.first?.portType, .video)
    }

    // MARK: - WorkflowEdge Tests

    func testWorkflowEdgeCreation() {
        let edge = WorkflowEdge(
            sourceNodeId: "node1",
            sourcePortId: "port1",
            targetNodeId: "node2",
            targetPortId: "port2"
        )

        XCTAssertFalse(edge.id.isEmpty)
        XCTAssertEqual(edge.sourceNodeId, "node1")
        XCTAssertEqual(edge.sourcePortId, "port1")
        XCTAssertEqual(edge.targetNodeId, "node2")
        XCTAssertEqual(edge.targetPortId, "port2")
    }

    // MARK: - WorkflowDefinition Tests

    func testWorkflowDefinitionAddNode() {
        var definition = WorkflowDefinition(name: "测试工作流")
        let node = WorkflowNode(
            title: "文本输入",
            config: .textInput(TextInputNodeConfig())
        )

        definition.nodes.append(node)

        XCTAssertEqual(definition.nodes.count, 1)
        XCTAssertEqual(definition.nodes.first?.title, "文本输入")
    }

    func testWorkflowDefinitionAddEdge() {
        var definition = WorkflowDefinition(name: "测试工作流")

        let node1 = WorkflowNode(
            id: "node1",
            title: "文本输入",
            config: .textInput(TextInputNodeConfig())
        )
        let node2 = WorkflowNode(
            id: "node2",
            title: "图片生成",
            config: .imageGen(ImageGenNodeConfig())
        )

        definition.nodes = [node1, node2]

        let edge = WorkflowEdge(
            sourceNodeId: "node1",
            sourcePortId: node1.outputPorts.first!.id,
            targetNodeId: "node2",
            targetPortId: node2.inputPorts.first!.id
        )

        definition.edges.append(edge)

        XCTAssertEqual(definition.edges.count, 1)
        XCTAssertEqual(definition.edges.first?.sourceNodeId, "node1")
        XCTAssertEqual(definition.edges.first?.targetNodeId, "node2")
    }

    func testWorkflowDefinitionDeleteNodeRemovesEdges() {
        var definition = WorkflowDefinition(name: "测试工作流")

        let node1 = WorkflowNode(
            id: "node1",
            title: "文本输入",
            config: .textInput(TextInputNodeConfig())
        )
        let node2 = WorkflowNode(
            id: "node2",
            title: "图片生成",
            config: .imageGen(ImageGenNodeConfig())
        )

        definition.nodes = [node1, node2]

        let edge = WorkflowEdge(
            sourceNodeId: "node1",
            sourcePortId: node1.outputPorts.first!.id,
            targetNodeId: "node2",
            targetPortId: node2.inputPorts.first!.id
        )

        definition.edges = [edge]

        // Delete node1
        definition.nodes.removeAll(where: { $0.id == "node1" })
        definition.edges.removeAll(where: { $0.sourceNodeId == "node1" || $0.targetNodeId == "node1" })

        XCTAssertEqual(definition.nodes.count, 1)
        XCTAssertTrue(definition.edges.isEmpty)
    }

    // MARK: - WorkflowNodeType Tests

    func testWorkflowNodeTypeDisplayName() {
        XCTAssertEqual(WorkflowNodeType.textInput.displayName, "文本输入")
        XCTAssertEqual(WorkflowNodeType.imageGen.displayName, "图片生成")
        XCTAssertEqual(WorkflowNodeType.videoGen.displayName, "视频生成")
        XCTAssertEqual(WorkflowNodeType.resultOutput.displayName, "结果输出")
    }

    func testWorkflowNodeTypeIcon() {
        XCTAssertEqual(WorkflowNodeType.textInput.icon, "text.cursor")
        XCTAssertEqual(WorkflowNodeType.imageGen.icon, "photo.badge.plus")
        XCTAssertEqual(WorkflowNodeType.videoGen.icon, "video.badge.plus")
        XCTAssertEqual(WorkflowNodeType.resultOutput.icon, "arrow.down.to.line")
    }

    // MARK: - WorkflowPortType Tests

    func testWorkflowPortTypeDisplayName() {
        XCTAssertEqual(WorkflowPortType.text.displayName, "文本")
        XCTAssertEqual(WorkflowPortType.image.displayName, "图片")
        XCTAssertEqual(WorkflowPortType.video.displayName, "视频")
        XCTAssertEqual(WorkflowPortType.any.displayName, "任意")
    }

    // MARK: - WorkflowNodeStatus Tests

    func testWorkflowNodeStatusDisplayName() {
        XCTAssertEqual(WorkflowNodeStatus.pending.displayName, "等待中")
        XCTAssertEqual(WorkflowNodeStatus.running.displayName, "执行中")
        XCTAssertEqual(WorkflowNodeStatus.succeeded.displayName, "已完成")
        XCTAssertEqual(WorkflowNodeStatus.failed.displayName, "失败")
    }

    // MARK: - CanvasNodePosition Tests

    func testCanvasNodePosition() {
        let position = CanvasNodePosition(id: "node1", position: CGPoint(x: 100, y: 200))
        XCTAssertEqual(position.id, "node1")
        XCTAssertEqual(position.position.x, 100)
        XCTAssertEqual(position.position.y, 200)
    }

    // MARK: - PortDragState Tests

    func testPortDragStateIdle() {
        let state: PortDragState = .idle
        if case .idle = state {
            // Pass
        } else {
            XCTFail("Expected idle state")
        }
    }

    func testPortDragStateDragging() {
        let state: PortDragState = .dragging(
            sourcePortId: "port1",
            sourceNodeId: "node1",
            sourceIsOutput: true,
            sourcePoint: CGPoint(x: 0, y: 0),
            currentPoint: CGPoint(x: 100, y: 100)
        )

        if case .dragging(let portId, let nodeId, let isOutput, _, _) = state {
            XCTAssertEqual(portId, "port1")
            XCTAssertEqual(nodeId, "node1")
            XCTAssertTrue(isOutput)
        } else {
            XCTFail("Expected dragging state")
        }
    }

    // MARK: - WorkflowDefinition JSON Roundtrip with Edges

    func testWorkflowDefinitionWithEdgesRoundTrips() throws {
        let node1 = WorkflowNode(
            id: "input",
            title: "输入",
            position: WorkflowPoint(x: 0, y: 0),
            config: .textInput(TextInputNodeConfig(text: "测试"))
        )
        let node2 = WorkflowNode(
            id: "output",
            title: "输出",
            position: WorkflowPoint(x: 300, y: 0),
            config: .resultOutput(ResultOutputNodeConfig())
        )

        let edge = WorkflowEdge(
            id: "edge1",
            sourceNodeId: "input",
            sourcePortId: node1.outputPorts.first!.id,
            targetNodeId: "output",
            targetPortId: node2.inputPorts.first!.id
        )

        let definition = WorkflowDefinition(
            id: "test",
            name: "测试工作流",
            nodes: [node1, node2],
            edges: [edge]
        )

        let data = try definition.encode()
        let decoded = try WorkflowDefinition.decode(from: data)

        XCTAssertEqual(decoded.nodes.count, 2)
        XCTAssertEqual(decoded.edges.count, 1)
        XCTAssertEqual(decoded.edges.first?.id, "edge1")
        XCTAssertEqual(decoded.edges.first?.sourceNodeId, "input")
        XCTAssertEqual(decoded.edges.first?.targetNodeId, "output")
    }

    // MARK: - WorkflowValue.imageValues Tests

    func testWorkflowValueImageReturnsImages() {
        let single = WorkflowValue.image(WorkflowImage(localFile: nil, remoteURL: "https://a.com/1.png"))
        XCTAssertEqual(single.imageValues?.count, 1)
        XCTAssertEqual(single.imageValues?.first?.remoteURL, "https://a.com/1.png")

        let multi = WorkflowValue.images([
            WorkflowImage(localFile: nil, remoteURL: "https://a.com/1.png"),
            WorkflowImage(localFile: nil, remoteURL: "https://a.com/2.png")
        ])
        XCTAssertEqual(multi.imageValues?.count, 2)
    }

    func testWorkflowValueImagesWorksWithVeoImageMode() {
        // Uses the shared firstRemoteImageURL helper
        let imageValue: WorkflowValue = .images([
            WorkflowImage(localFile: nil, remoteURL: "https://a.com/frame.png")
        ])

        XCTAssertEqual(imageValue.firstRemoteImageURL, "https://a.com/frame.png")

        let singleImage: WorkflowValue = .image(WorkflowImage(localFile: nil, remoteURL: "https://a.com/single.png"))
        XCTAssertEqual(singleImage.firstRemoteImageURL, "https://a.com/single.png")

        let noImage: WorkflowValue = .none
        XCTAssertNil(noImage.firstRemoteImageURL)
    }

    // MARK: - Seedance/Wan DAG Validation Tests

    func testSeedanceReferenceNodePassesDAGValidation() {
        let textNode = WorkflowNode(
            id: "text",
            title: "文本输入",
            config: .textInput(TextInputNodeConfig(text: "测试"))
        )
        var seedanceConfig = VideoGenNodeConfig()
        seedanceConfig.genType = .seedance
        seedanceConfig.model = "dreamina-seedance-2-0-260128"
        seedanceConfig.mode = .reference
        let seedanceNode = WorkflowNode(
            id: "video",
            title: "Seedance 视频",
            position: WorkflowPoint(x: 300, y: 0),
            config: .videoGen(seedanceConfig)
        )

        let definition = WorkflowDefinition(
            name: "Seedance 测试",
            nodes: [textNode, seedanceNode],
            edges: []
        )

        let errors = definition.fullValidate()
        let seedanceErrors = errors.filter {
            if case .invalidConfig(let msg) = $0 { return msg.contains("Seedance") }
            return false
        }
        XCTAssertTrue(seedanceErrors.isEmpty, "Seedance 参考模式应在画布中可用，但报错: \(seedanceErrors)")
    }

    func testWanNodeFailsDAGValidation() {
        let textNode = WorkflowNode(
            id: "text",
            title: "文本输入",
            config: .textInput(TextInputNodeConfig(text: "测试"))
        )
        var wanConfig = VideoGenNodeConfig()
        wanConfig.genType = .wan
        let wanNode = WorkflowNode(
            id: "video",
            title: "Wan 视频",
            position: WorkflowPoint(x: 300, y: 0),
            config: .videoGen(wanConfig)
        )

        let definition = WorkflowDefinition(
            name: "Wan 测试",
            nodes: [textNode, wanNode],
            edges: []
        )

        let errors = definition.fullValidate()
        XCTAssertTrue(errors.contains(.invalidConfig("Wan 视频需要本地文件输入，暂不支持在画布中使用")))
    }

    func testVeoNodePassesDAGValidation() {
        let textNode = WorkflowNode(
            id: "text",
            title: "文本输入",
            config: .textInput(TextInputNodeConfig(text: "测试"))
        )
        let veoConfig = VideoGenNodeConfig()
        let veoNode = WorkflowNode(
            id: "video",
            title: "Veo 视频",
            position: WorkflowPoint(x: 300, y: 0),
            config: .videoGen(veoConfig)
        )

        let edge = WorkflowEdge(
            sourceNodeId: "text",
            sourcePortId: textNode.outputPorts.first!.id,
            targetNodeId: "video",
            targetPortId: veoNode.inputPorts.first!.id
        )

        let definition = WorkflowDefinition(
            name: "Veo 测试",
            nodes: [textNode, veoNode],
            edges: [edge]
        )

        let errors = definition.fullValidate()
        let seedanceErrors = errors.filter {
            if case .invalidConfig(let msg) = $0 { return msg.contains("Seedance") || msg.contains("Wan") }
            return false
        }
        XCTAssertTrue(seedanceErrors.isEmpty, "Veo 节点不应被 Seedance/Wan 规则拒绝")
    }

    // MARK: - WorkflowNodeStatus Tests

    func testWorkflowNodeStatusIcon() {
        XCTAssertEqual(WorkflowNodeStatus.pending.icon, "circle")
        XCTAssertEqual(WorkflowNodeStatus.running.icon, "circle.dotted")
        XCTAssertEqual(WorkflowNodeStatus.succeeded.icon, "checkmark.circle.fill")
        XCTAssertEqual(WorkflowNodeStatus.failed.icon, "xmark.circle.fill")
        XCTAssertEqual(WorkflowNodeStatus.skipped.icon, "forward.circle")
        XCTAssertEqual(WorkflowNodeStatus.cancelled.icon, "stop.circle.fill")
    }

    func testWorkflowNodeStatusColor() {
        // Just verify they don't crash; color equality across platforms is fragile
        _ = WorkflowNodeStatus.pending.color
        _ = WorkflowNodeStatus.running.color
        _ = WorkflowNodeStatus.succeeded.color
        _ = WorkflowNodeStatus.failed.color
        _ = WorkflowNodeStatus.skipped.color
        _ = WorkflowNodeStatus.cancelled.color
    }

    // MARK: - WorkflowNodeRunDetail Tests

    func testNodeRunDetailElapsedSeconds() {
        var detail = WorkflowNodeRunDetail()
        XCTAssertNil(detail.elapsedSeconds)

        detail.startedAt = Date()
        XCTAssertNotNil(detail.elapsedSeconds)
        XCTAssertGreaterThanOrEqual(detail.elapsedSeconds!, 0)

        detail.completedAt = detail.startedAt!.addingTimeInterval(5)
        XCTAssertEqual(detail.elapsedSeconds, 5)
    }

    func testNodeRunDetailElapsedText() {
        var detail = WorkflowNodeRunDetail()
        XCTAssertNil(detail.elapsedText)

        detail.startedAt = Date()
        detail.completedAt = detail.startedAt!.addingTimeInterval(12)
        XCTAssertEqual(detail.elapsedText, "12s")

        detail.completedAt = detail.startedAt!.addingTimeInterval(125)
        XCTAssertEqual(detail.elapsedText, "2m5s")
    }

    // MARK: - Cached Structural Fingerprint Tests

    func testRunStateCachedFingerprintInitiallyNil() {
        let state = WorkflowRunState()
        XCTAssertNil(state.cachedStructuralFingerprint)
    }

    func testRunStateCachesFingerprint() {
        let def = WorkflowDefinition.sample()
        var state = WorkflowRunState()
        state.cachedStructuralFingerprint = def.structuralFingerprint
        XCTAssertNotNil(state.cachedStructuralFingerprint)
        XCTAssertEqual(state.cachedStructuralFingerprint, def.structuralFingerprint)
    }

    func testDifferentDefinitionsHaveDifferentFingerprints() {
        let def1 = WorkflowDefinition.sample()
        var def2 = def1
        def2.nodes.append(WorkflowNode(title: "额外节点", config: .textInput(TextInputNodeConfig(text: "test"))))
        XCTAssertNotEqual(def1.structuralFingerprint, def2.structuralFingerprint)
    }

    func testConfigFingerprintChangesWhenConfigChanges() {
        var def1 = WorkflowDefinition.sample()
        var def2 = def1
        // Same structure, different config content
        if var node = def2.nodes.first(where: { $0.type == .textInput }) {
            node.config = .textInput(TextInputNodeConfig(text: "不同的提示词"))
            if let idx = def2.nodes.firstIndex(where: { $0.id == node.id }) {
                def2.nodes[idx] = node
            }
        }
        XCTAssertEqual(def1.structuralFingerprint, def2.structuralFingerprint, "结构相同")
        XCTAssertNotEqual(def1.configFingerprint, def2.configFingerprint, "配置不同应产生不同指纹")
    }

    func testConfigFingerprintStableWhenUnchanged() {
        let def1 = WorkflowDefinition.sample()
        let def2 = def1
        XCTAssertEqual(def1.configFingerprint, def2.configFingerprint)
    }

    // MARK: - WorkflowStepRunRecord New Fields Tests

    func testStepRunRecordEncodesNewFields() throws {
        var step = WorkflowStep(type: .imageGen, label: "图片生成")
        step.id = "test-node-id"
        var record = WorkflowStepRunRecord(step: step, status: "succeeded")
        record.elapsedSeconds = 42
        record.inputSummary = "提示词:测试"
        record.outputSummary = "1 张图片"

        let encoder = JSONEncoder()
        let data = try encoder.encode(record)
        let decoded = try JSONDecoder().decode(WorkflowStepRunRecord.self, from: data)

        XCTAssertEqual(decoded.elapsedSeconds, 42)
        XCTAssertEqual(decoded.inputSummary, "提示词:测试")
        XCTAssertEqual(decoded.outputSummary, "1 张图片")
    }

    func testStepRunRecordNewFieldsAreOptional() throws {
        let step = WorkflowStep(type: .textInput, label: "文本")
        let record = WorkflowStepRunRecord(step: step, status: "succeeded")

        let encoder = JSONEncoder()
        let data = try encoder.encode(record)
        let decoded = try JSONDecoder().decode(WorkflowStepRunRecord.self, from: data)

        XCTAssertNil(decoded.elapsedSeconds)
        XCTAssertNil(decoded.inputSummary)
        XCTAssertNil(decoded.outputSummary)
    }

    // MARK: - Strip URL Secrets Tests

    func testStripURLSecrets() {
        let urlWithToken = "https://cdn.example.com/img.png?token=abc123&expires=999"
        let stripped = WorkflowStore.stripURLSecrets(urlWithToken)
        XCTAssertEqual(stripped, "https://cdn.example.com/img.png")
    }

    func testStripURLSecretsPreservesCleanURL() {
        let cleanURL = "https://cdn.example.com/img.png"
        let stripped = WorkflowStore.stripURLSecrets(cleanURL)
        XCTAssertEqual(stripped, cleanURL)
    }

    func testSafeSummaryStripsImageURLSecrets() {
        let urlWithToken = "https://cdn.example.com/img.png?token=secret123"
        let value = WorkflowValue.image(WorkflowImage(localFile: nil, remoteURL: urlWithToken))
        let summary = WorkflowStore.safeSummary(for: value)
        XCTAssertTrue(summary.contains("https://cdn.example.com/img.png"))
        XCTAssertFalse(summary.contains("secret123"))
    }

    func testSafeSummaryStripsVideoURLSecrets() {
        let urlWithToken = "https://cdn.example.com/video.mp4?token=secret456"
        let value = WorkflowValue.video(WorkflowVideo(remoteURL: urlWithToken))
        let summary = WorkflowStore.safeSummary(for: value)
        XCTAssertTrue(summary.contains("https://cdn.example.com/video.mp4"))
        XCTAssertFalse(summary.contains("secret456"))
    }

    func testSafeSummaryFallsBackForNonURLValues() {
        let textValue = WorkflowValue.text("hello world")
        XCTAssertEqual(WorkflowStore.safeSummary(for: textValue), textValue.summary)
    }

    // MARK: - Linear Chain Detection

    func testIsLinearChainForLinearTemplate() {
        let def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        XCTAssertTrue(def.isLinearChain, "textToImageToVideo should be a linear chain")
    }

    func testIsLinearChainForEmptyDefinition() {
        let def = WorkflowDefinition(name: "empty")
        XCTAssertTrue(def.isLinearChain, "Empty definition should be considered linear")
    }

    func testIsNotLinearChainForBranchingTemplate() {
        let def = WorkflowDefinition.referenceToVideo.makeDefinition()
        XCTAssertFalse(def.isLinearChain, "referenceToVideo has branching (2 inputs to video node), not linear")
    }

    func testIsNotLinearChainForStartEndTemplate() {
        let def = WorkflowDefinition.startEndFrameToVideo.makeDefinition()
        XCTAssertFalse(def.isLinearChain, "startEndFrameToVideo has multiple parallel branches")
    }

    func testIsLinearChainSingleNode() {
        let node = WorkflowNode(title: "Input", config: .textInput(TextInputNodeConfig(text: "hello")))
        let def = WorkflowDefinition(name: "single", nodes: [node], edges: [])
        XCTAssertTrue(def.isLinearChain, "Single node should be linear")
    }

    // MARK: - Linear Round-Trip (textToImageToVideo)

    func testToLinearStepsProducesCorrectCount() {
        let def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let steps = def.toLinearSteps()
        XCTAssertEqual(steps.count, 4, "textToImageToVideo has 4 nodes")
    }

    func testToLinearStepsPreservesNodeIDs() {
        let def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let steps = def.toLinearSteps()
        for (node, step) in zip(def.nodes, steps) {
            // Walk chain order may differ from nodes array, so just check step IDs come from nodes
            XCTAssertTrue(def.nodes.contains(where: { $0.id == step.id }),
                          "Step ID \(step.id) should match a node ID")
        }
    }

    func testFromLinearStepsPreservesStepIDs() {
        let def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let steps = def.toLinearSteps()
        let rebuilt = WorkflowDefinition.fromLinearSteps(steps, name: "test")
        for step in steps {
            XCTAssertTrue(rebuilt.nodes.contains(where: { $0.id == step.id }),
                          "Node ID should match step ID after round-trip")
        }
    }

    func testRoundTripFullValidatePasses() {
        let def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let steps = def.toLinearSteps()
        let rebuilt = WorkflowDefinition.fromLinearSteps(steps, name: "test")
        let errors = rebuilt.fullValidate()
        XCTAssertTrue(errors.isEmpty, "Round-tripped definition should pass fullValidate, got: \(errors)")
    }

    func testRoundTripConnectsImageToVideoImagePort() {
        let def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let steps = def.toLinearSteps()
        let rebuilt = WorkflowDefinition.fromLinearSteps(steps, name: "test")

        // Find the video node (should have .videoGen config)
        guard let videoNode = rebuilt.nodes.first(where: { if case .videoGen = $0.config { return true }; return false }) else {
            XCTFail("No video node found")
            return
        }

        // The edge targeting the video node's image input should come from the image node's image output
        let imageInputEdges = rebuilt.edges.filter { $0.targetNodeId == videoNode.id }
        let imagePort = videoNode.inputPorts.first(where: { $0.portType == .image })
        XCTAssertNotNil(imagePort, "Video node should have an image input port")

        if let imagePort {
            let edgeToImage = imageInputEdges.first(where: { $0.targetPortId == imagePort.id })
            XCTAssertNotNil(edgeToImage, "Image input port should have an incoming edge")

            if let edgeToImage {
                let sourceNode = rebuilt.nodes.first(where: { $0.id == edgeToImage.sourceNodeId })
                XCTAssertNotNil(sourceNode)
                if case .imageGen = sourceNode?.config {
                    // Correct: image output → image input
                } else {
                    XCTFail("Image input should be connected from imageGen node, got \(sourceNode?.config)")
                }
            }
        }
    }

    // MARK: - Port Matching

    func testFromLinearStepsMatchesTextToPrompt() {
        // textInput → imageGen: text output should connect to prompt (text) input
        let steps = [
            WorkflowStep(type: .textInput, label: "Input", config: WorkflowStepConfig(text: "a cat")),
            WorkflowStep(type: .imageGen, label: "Image"),
        ]
        let def = WorkflowDefinition.fromLinearSteps(steps, name: "test")
        let errors = def.fullValidate()
        XCTAssertTrue(errors.isEmpty, "textInput→imageGen should be valid, got: \(errors)")
    }

    func testFromLinearStepsMatchesImageToVideoImagePort() {
        // imageGen → videoGen: image output should connect to image input (not prompt text input)
        let steps = [
            WorkflowStep(type: .imageGen, label: "Image"),
            WorkflowStep(type: .videoGen, label: "Video"),
        ]
        let def = WorkflowDefinition.fromLinearSteps(steps, name: "test")

        guard let videoNode = def.nodes.first(where: { if case .videoGen = $0.config { return true }; return false }) else {
            XCTFail("No video node")
            return
        }

        // The edge to video node should target the image port, not the prompt port
        let edgesToVideo = def.edges.filter { $0.targetNodeId == videoNode.id }
        XCTAssertEqual(edgesToVideo.count, 1, "Should have exactly 1 edge to video node")

        if let edge = edgesToVideo.first {
            let targetPort = videoNode.inputPorts.first(where: { $0.id == edge.targetPortId })
            XCTAssertEqual(targetPort?.portType, .image, "Edge should target image port, not text/prompt")
        }
    }

    // MARK: - Non-Linear Template Cannot Convert

    func testNonLinearTemplateReturnsEmptySteps() {
        let def = WorkflowDefinition.referenceToVideo.makeDefinition()
        let steps = def.toLinearSteps()
        XCTAssertTrue(steps.isEmpty, "Non-linear template should return empty steps")
    }
}
