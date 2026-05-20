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
        XCTAssertEqual(WorkflowNodeStatus.skipped.displayName, "已复用")
        XCTAssertEqual(WorkflowNodeStatus.cancelled.displayName, "已取消")
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

    // MARK: - Missing Input Source Validation

    func testValidationDetectsMissingInputSource() {
        let imageNode = WorkflowNode(
            id: "img",
            title: "图片生成",
            config: .imageGen(ImageGenNodeConfig())
        )
        let definition = WorkflowDefinition(
            name: "disconnected",
            nodes: [imageNode],
            edges: []
        )

        let errors = definition.validate()
        let missingErrors = errors.filter { if case .missingInputSource = $0 { return true }; return false }
        XCTAssertFalse(missingErrors.isEmpty, "Should detect missing input source for disconnected imageGen node")
    }

    func testValidationMissingInputSourceIncludesNodeId() {
        let imageNode = WorkflowNode(
            id: "img",
            title: "图片生成",
            config: .imageGen(ImageGenNodeConfig())
        )
        let definition = WorkflowDefinition(
            name: "disconnected",
            nodes: [imageNode],
            edges: []
        )

        let errors = definition.validate()
        if let missingError = errors.first(where: {
            if case .missingInputSource = $0 { return true }; return false
        }) {
            XCTAssertEqual(missingError.affectedNodeId, "img")
            if let portId = missingError.affectedPortId {
                XCTAssertTrue(imageNode.inputPorts.contains(where: { $0.id == portId }))
            }
        } else {
            XCTFail("Should find missingInputSource error")
        }
    }

    func testValidationSkipsAnyTypePorts() {
        let resultNode = WorkflowNode(
            id: "out",
            title: "结果输出",
            config: .resultOutput(ResultOutputNodeConfig())
        )
        let definition = WorkflowDefinition(
            name: "any-only",
            nodes: [resultNode],
            edges: []
        )

        let errors = definition.validate()
        let missingErrors = errors.filter { if case .missingInputSource = $0 { return true }; return false }
        XCTAssertTrue(missingErrors.isEmpty, "Should not flag .any type ports as missing input")
    }

    func testValidationAllowsPartiallyConnectedNode() {
        let textNode = WorkflowNode(
            id: "text",
            title: "文本输入",
            config: .textInput(TextInputNodeConfig(text: "test"))
        )
        var videoConfig = VideoGenNodeConfig()
        videoConfig.mode = .image
        let videoNode = WorkflowNode(
            id: "video",
            title: "视频生成",
            config: .videoGen(videoConfig)
        )

        let videoPromptPort = videoNode.inputPorts.first(where: { $0.role == .prompt })!
        let videoImagePort = videoNode.inputPorts.first(where: { $0.role == .image })!
        let textPort = textNode.outputPorts.first!

        let definition = WorkflowDefinition(
            name: "partial",
            nodes: [textNode, videoNode],
            edges: [
                WorkflowEdge(sourceNodeId: "text", sourcePortId: textPort.id,
                             targetNodeId: "video", targetPortId: videoPromptPort.id),
                WorkflowEdge(sourceNodeId: "text", sourcePortId: textPort.id,
                             targetNodeId: "video", targetPortId: videoImagePort.id)
            ]
        )

        let errors = definition.validate()
        let missingErrors = errors.filter { if case .missingInputSource = $0 { return true }; return false }
        XCTAssertTrue(missingErrors.isEmpty, "VideoGen in image mode with prompt+image connected should not trigger missingInputSource")
    }

    // MARK: - Validation Error Metadata

    func testValidationErrorAffectedNodeId() {
        XCTAssertNotNil(WorkflowValidationError.missingNode(nodeId: "n1").affectedNodeId)
        XCTAssertNotNil(WorkflowValidationError.duplicateNodeId("n2").affectedNodeId)
        XCTAssertNotNil(WorkflowValidationError.missingInputSource(
            portId: "p1", nodeId: "n3", nodeTitle: "测试节点", portName: "test", expectedType: .image
        ).affectedNodeId)
        XCTAssertNil(WorkflowValidationError.invalidConfig("msg").affectedNodeId)
    }

    func testValidationErrorAffectedPortId() {
        XCTAssertNotNil(WorkflowValidationError.missingPort(portId: "p1").affectedPortId)
        XCTAssertNotNil(WorkflowValidationError.sourcePortNotOutput(portId: "p2").affectedPortId)
        XCTAssertNotNil(WorkflowValidationError.missingInputSource(
            portId: "p3", nodeId: "n1", nodeTitle: "测试节点", portName: "test", expectedType: .text
        ).affectedPortId)
        XCTAssertNil(WorkflowValidationError.cycleDetected(nodeIds: ["n1", "n2"]).affectedPortId)
    }

    func testValidationErrorMessageContainsActionableInfo() {
        let error: WorkflowValidationError = .missingInputSource(
            portId: "port-1", nodeId: "node-1", nodeTitle: "视频生成", portName: "图片", expectedType: .image
        )
        let description = error.errorDescription ?? ""
        XCTAssertTrue(description.contains("视频生成"))
        XCTAssertTrue(description.contains("图片"))
        XCTAssertTrue(description.contains("图片"))
    }

    // MARK: - Existing Templates Pass Full Validate

    func testTextToImageToVideoTemplatePassesFullValidate() {
        let def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let errors = def.fullValidate()
        XCTAssertTrue(errors.isEmpty, "textToImageToVideo template should pass fullValidate, got: \(errors)")
    }

    func testReferenceToVideoTemplatePassesFullValidate() {
        let def = WorkflowDefinition.referenceToVideo.makeDefinition()
        let errors = def.fullValidate()
        XCTAssertTrue(errors.isEmpty, "referenceToVideo template should pass fullValidate, got: \(errors)")
    }

    func testStartEndFrameToVideoTemplatePassesFullValidate() {
        let def = WorkflowDefinition.startEndFrameToVideo.makeDefinition()
        let errors = def.fullValidate()
        XCTAssertTrue(errors.isEmpty, "startEndFrameToVideo template should pass fullValidate, got: \(errors)")
    }

    func testPromptToImageToVideoTemplatePassesFullValidate() {
        let def = WorkflowDefinition.promptToImageToVideo.makeDefinition()
        let errors = def.fullValidate()
        XCTAssertTrue(errors.isEmpty, "promptToImageToVideo template should pass fullValidate, got: \(errors)")
    }

    func testEmptyDefinitionPassesFullValidate() {
        let def = WorkflowDefinition(name: "empty")
        let errors = def.fullValidate()
        XCTAssertTrue(errors.isEmpty, "Empty definition should pass fullValidate")
    }

    func testSingleNodeWithNoInputsPassesFullValidate() {
        let def = WorkflowDefinition(
            name: "single",
            nodes: [
                WorkflowNode(title: "文本输入", config: .textInput(TextInputNodeConfig(text: "hello")))
            ],
            edges: []
        )
        let errors = def.fullValidate()
        XCTAssertTrue(errors.isEmpty, "textInput node has no input ports, should pass")
    }

    // MARK: - Mode-Aware Required Port Validation

    func testVeoImageModeRequiresImagePort() {
        let textNode = WorkflowNode(
            id: "text", title: "文本输入",
            config: .textInput(TextInputNodeConfig(text: "test"))
        )
        var vcfg = VideoGenNodeConfig()
        vcfg.genType = .veo
        vcfg.mode = .image
        let videoNode = WorkflowNode(
            id: "v", title: "视频生成",
            config: .videoGen(vcfg)
        )
        let promptPort = videoNode.inputPorts.first(where: { $0.role == .prompt })!
        let textPort = textNode.outputPorts.first!

        let def = WorkflowDefinition(
            name: "missing-image",
            nodes: [textNode, videoNode],
            edges: [
                WorkflowEdge(sourceNodeId: "text", sourcePortId: textPort.id,
                             targetNodeId: "v", targetPortId: promptPort.id)
            ]
        )

        let errors = def.fullValidate()
        let missingErrors = errors.filter { if case .missingInputSource = $0 { return true }; return false }
        XCTAssertFalse(missingErrors.isEmpty, "Veo image mode requires image port")
        let imageError = missingErrors.first(where: {
            if case .missingInputSource(_, _, _, let name, _) = $0 { return name == "图片" }; return false
        })
        XCTAssertNotNil(imageError, "Missing image port should be flagged")
    }

    func testVeoStartEndModeRequiresFirstFramePort() {
        let textNode = WorkflowNode(
            id: "text", title: "文本输入",
            config: .textInput(TextInputNodeConfig(text: "test"))
        )
        var vcfg = VideoGenNodeConfig()
        vcfg.genType = .veo
        vcfg.mode = .startEnd
        let videoNode = WorkflowNode(
            id: "v", title: "视频生成",
            config: .videoGen(vcfg)
        )
        let promptPort = videoNode.inputPorts.first(where: { $0.role == .prompt })!
        let textPort = textNode.outputPorts.first!

        let def = WorkflowDefinition(
            name: "missing-firstframe",
            nodes: [textNode, videoNode],
            edges: [
                WorkflowEdge(sourceNodeId: "text", sourcePortId: textPort.id,
                             targetNodeId: "v", targetPortId: promptPort.id)
            ]
        )

        let errors = def.fullValidate()
        let missingErrors = errors.filter { if case .missingInputSource = $0 { return true }; return false }
        let firstFrameError = missingErrors.first(where: {
            if case .missingInputSource(_, _, _, let name, _) = $0 { return name == "首帧图片" }; return false
        })
        XCTAssertNotNil(firstFrameError, "Veo startEnd mode requires firstFrame port")
    }

    func testVeoTextModeOnlyRequiresPrompt() {
        let textNode = WorkflowNode(
            id: "text", title: "文本输入",
            config: .textInput(TextInputNodeConfig(text: "test"))
        )
        var vcfg = VideoGenNodeConfig()
        vcfg.genType = .veo
        vcfg.mode = .text
        let videoNode = WorkflowNode(
            id: "v", title: "视频生成",
            config: .videoGen(vcfg)
        )
        let promptPort = videoNode.inputPorts.first(where: { $0.role == .prompt })!
        let textPort = textNode.outputPorts.first!

        let def = WorkflowDefinition(
            name: "text-mode",
            nodes: [textNode, videoNode],
            edges: [
                WorkflowEdge(sourceNodeId: "text", sourcePortId: textPort.id,
                             targetNodeId: "v", targetPortId: promptPort.id)
            ]
        )

        let errors = def.fullValidate()
        let missingErrors = errors.filter { if case .missingInputSource = $0 { return true }; return false }
        XCTAssertTrue(missingErrors.isEmpty, "Veo text mode should only require prompt, got: \(missingErrors)")
    }

    func testSeedanceFirstLastRequiresFirstFrame() {
        let textNode = WorkflowNode(
            id: "text", title: "文本输入",
            config: .textInput(TextInputNodeConfig(text: "test"))
        )
        var vcfg = VideoGenNodeConfig()
        vcfg.genType = .seedance
        vcfg.model = "dreamina-seedance-2-0-260128"
        vcfg.mode = .firstLast
        let videoNode = WorkflowNode(
            id: "v", title: "视频生成",
            config: .videoGen(vcfg)
        )
        let promptPort = videoNode.inputPorts.first(where: { $0.role == .prompt })!
        let textPort = textNode.outputPorts.first!

        let def = WorkflowDefinition(
            name: "seedance-firstlast",
            nodes: [textNode, videoNode],
            edges: [
                WorkflowEdge(sourceNodeId: "text", sourcePortId: textPort.id,
                             targetNodeId: "v", targetPortId: promptPort.id)
            ]
        )

        let errors = def.fullValidate()
        let missingErrors = errors.filter { if case .missingInputSource = $0 { return true }; return false }
        let firstFrameError = missingErrors.first(where: {
            if case .missingInputSource(_, _, _, let name, _) = $0 { return name == "首帧图片" }; return false
        })
        XCTAssertNotNil(firstFrameError, "Seedance firstLast mode requires firstFrame port")
    }

    func testVeoImageModeConnectedBothPortsPasses() {
        let textNode = WorkflowNode(
            id: "text", title: "文本输入",
            config: .textInput(TextInputNodeConfig(text: "test"))
        )
        var vcfg = VideoGenNodeConfig()
        vcfg.genType = .veo
        vcfg.mode = .image
        let videoNode = WorkflowNode(
            id: "v", title: "视频生成",
            config: .videoGen(vcfg)
        )
        let promptPort = videoNode.inputPorts.first(where: { $0.role == .prompt })!
        let imagePort = videoNode.inputPorts.first(where: { $0.role == .image })!
        let textPort = textNode.outputPorts.first!

        let def = WorkflowDefinition(
            name: "complete-image",
            nodes: [textNode, videoNode],
            edges: [
                WorkflowEdge(sourceNodeId: "text", sourcePortId: textPort.id,
                             targetNodeId: "v", targetPortId: promptPort.id),
                WorkflowEdge(sourceNodeId: "text", sourcePortId: textPort.id,
                             targetNodeId: "v", targetPortId: imagePort.id)
            ]
        )

        let errors = def.fullValidate()
        let missingErrors = errors.filter { if case .missingInputSource = $0 { return true }; return false }
        XCTAssertTrue(missingErrors.isEmpty, "Veo image mode with both ports connected should pass, got: \(missingErrors)")
    }

    func testErrorDescriptionUsesNodeTitle() {
        let error: WorkflowValidationError = .missingInputSource(
            portId: "p1", nodeId: "n1", nodeTitle: "视频生成", portName: "图片", expectedType: .image
        )
        let desc = error.errorDescription ?? ""
        XCTAssertTrue(desc.contains("视频生成"), "Error description should use node title, got: \(desc)")
        XCTAssertTrue(desc.contains("图片"), "Error description should use port name, got: \(desc)")
        XCTAssertFalse(desc.contains("n1"), "Error description should NOT expose node ID, got: \(desc)")
    }

    func testImageGenRequiresPromptPort() {
        let imageNode = WorkflowNode(
            id: "img", title: "图片生成",
            config: .imageGen(ImageGenNodeConfig())
        )
        let def = WorkflowDefinition(
            name: "no-prompt",
            nodes: [imageNode],
            edges: []
        )

        let errors = def.fullValidate()
        let missingErrors = errors.filter { if case .missingInputSource = $0 { return true }; return false }
        let promptError = missingErrors.first(where: {
            if case .missingInputSource(_, _, _, let name, _) = $0 { return name == "提示词" }; return false
        })
        XCTAssertNotNil(promptError, "ImageGen should require prompt input")
    }

    func testVeoImageModeWithoutPromptPasses() {
        let textNode = WorkflowNode(
            id: "text", title: "文本输入",
            config: .textInput(TextInputNodeConfig(text: "test"))
        )
        var vcfg = VideoGenNodeConfig()
        vcfg.genType = .veo
        vcfg.mode = .image
        let videoNode = WorkflowNode(
            id: "v", title: "视频生成",
            config: .videoGen(vcfg)
        )
        let imagePort = videoNode.inputPorts.first(where: { $0.role == .image })!
        let textPort = textNode.outputPorts.first!

        let def = WorkflowDefinition(
            name: "image-only",
            nodes: [textNode, videoNode],
            edges: [
                WorkflowEdge(sourceNodeId: "text", sourcePortId: textPort.id,
                             targetNodeId: "v", targetPortId: imagePort.id)
            ]
        )

        let errors = def.fullValidate()
        let missingErrors = errors.filter { if case .missingInputSource = $0 { return true }; return false }
        XCTAssertTrue(missingErrors.isEmpty, "Veo image mode should work without explicit prompt, got: \(missingErrors)")
    }

    func testVeoTextModeWithoutPromptFails() {
        let videoNode = WorkflowNode(
            id: "v", title: "视频生成",
            config: .videoGen(VideoGenNodeConfig())
        )
        let def = WorkflowDefinition(
            name: "text-mode-no-prompt",
            nodes: [videoNode],
            edges: []
        )

        let errors = def.fullValidate()
        let missingErrors = errors.filter { if case .missingInputSource = $0 { return true }; return false }
        XCTAssertFalse(missingErrors.isEmpty, "Veo text mode must require prompt")
        let promptError = missingErrors.first(where: {
            if case .missingInputSource(_, _, _, let name, _) = $0 { return name == "提示词" }; return false
        })
        XCTAssertNotNil(promptError, "Veo text mode should flag missing prompt port")
    }

    // MARK: - Seedance Reference Does Not Require Image

    func testSeedanceReferencePromptOnlyPasses() {
        let textNode = WorkflowNode(
            id: "text", title: "文本输入",
            config: .textInput(TextInputNodeConfig(text: "test"))
        )
        var vcfg = VideoGenNodeConfig()
        vcfg.genType = .seedance
        vcfg.model = "dreamina-seedance-2-0-260128"
        vcfg.mode = .reference
        let videoNode = WorkflowNode(
            id: "v", title: "Seedance 参考",
            config: .videoGen(vcfg)
        )
        let promptPort = videoNode.inputPorts.first(where: { $0.role == .prompt })!
        let textPort = textNode.outputPorts.first!

        let def = WorkflowDefinition(
            name: "seedance-ref-prompt",
            nodes: [textNode, videoNode],
            edges: [
                WorkflowEdge(sourceNodeId: "text", sourcePortId: textPort.id,
                             targetNodeId: "v", targetPortId: promptPort.id)
            ]
        )

        let errors = def.fullValidate()
        let missingErrors = errors.filter { if case .missingInputSource = $0 { return true }; return false }
        XCTAssertTrue(missingErrors.isEmpty, "Seedance reference with prompt-only should pass, got: \(missingErrors)")
    }

    func testSeedanceReferenceImageOnlyPasses() {
        let textNode = WorkflowNode(
            id: "text", title: "文本输入",
            config: .textInput(TextInputNodeConfig(text: "test"))
        )
        var vcfg = VideoGenNodeConfig()
        vcfg.genType = .seedance
        vcfg.model = "dreamina-seedance-2-0-260128"
        vcfg.mode = .reference
        let videoNode = WorkflowNode(
            id: "v", title: "Seedance 参考",
            config: .videoGen(vcfg)
        )
        let imagePort = videoNode.inputPorts.first(where: { $0.role == .image })!
        let textPort = textNode.outputPorts.first!

        let def = WorkflowDefinition(
            name: "seedance-ref-image",
            nodes: [textNode, videoNode],
            edges: [
                WorkflowEdge(sourceNodeId: "text", sourcePortId: textPort.id,
                             targetNodeId: "v", targetPortId: imagePort.id)
            ]
        )

        let errors = def.fullValidate()
        let missingErrors = errors.filter { if case .missingInputSource = $0 { return true }; return false }
        XCTAssertTrue(missingErrors.isEmpty, "Seedance reference with image-only should pass, got: \(missingErrors)")
    }

    func testSeedanceReferenceWithoutInputsFails() {
        var vcfg = VideoGenNodeConfig()
        vcfg.genType = .seedance
        vcfg.model = "dreamina-seedance-2-0-260128"
        vcfg.mode = .reference
        let videoNode = WorkflowNode(
            id: "v", title: "Seedance 参考",
            config: .videoGen(vcfg)
        )

        let def = WorkflowDefinition(
            name: "seedance-ref-empty",
            nodes: [videoNode],
            edges: []
        )

        let errors = def.fullValidate()
        let anyErrors = errors.filter { if case .missingAnyRequiredInput = $0 { return true }; return false }
        XCTAssertFalse(anyErrors.isEmpty, "Seedance reference with no inputs should fail: needs prompt OR image, got: \(errors)")
        if let err = anyErrors.first {
            let desc = err.errorDescription ?? ""
            XCTAssertTrue(desc.contains("提示词") && desc.contains("图片"),
                          "Error should mention both port names, got: \(desc)")
        }
    }

    func testVeoReferenceStillRequiresImage() {
        let textNode = WorkflowNode(
            id: "text", title: "文本输入",
            config: .textInput(TextInputNodeConfig(text: "test"))
        )
        var vcfg = VideoGenNodeConfig()
        vcfg.genType = .veo
        vcfg.channel = .official
        vcfg.model = "pro"
        vcfg.mode = .reference
        let videoNode = WorkflowNode(
            id: "v", title: "Veo 参考",
            config: .videoGen(vcfg)
        )
        let promptPort = videoNode.inputPorts.first(where: { $0.role == .prompt })!
        let textPort = textNode.outputPorts.first!

        let def = WorkflowDefinition(
            name: "veo-ref-no-image",
            nodes: [textNode, videoNode],
            edges: [
                WorkflowEdge(sourceNodeId: "text", sourcePortId: textPort.id,
                             targetNodeId: "v", targetPortId: promptPort.id)
            ]
        )

        let errors = def.fullValidate()
        let missingErrors = errors.filter { if case .missingInputSource = $0 { return true }; return false }
        let imageError = missingErrors.first(where: {
            if case .missingInputSource(_, _, _, let name, _) = $0 { return name == "图片" }; return false
        })
        XCTAssertNotNil(imageError, "Veo reference should still require image port")
    }

    // MARK: - PromptTemplate Variable-Aware Ports

    func testPromptTemplateRequiresReferencedVariablePort() {
        let promptNode = WorkflowNode(
            id: "pt", title: "提示词模板",
            config: .promptTemplate(PromptTemplateNodeConfig(template: "描述：{{文本}}")),
            inputPorts: [WorkflowPort(name: "文本", portType: .text, nodeId: "", role: .styleVariable)]
        )
        let def = WorkflowDefinition(
            name: "template-ref-var",
            nodes: [promptNode],
            edges: []
        )

        let errors = def.fullValidate()
        let missingErrors = errors.filter { if case .missingInputSource = $0 { return true }; return false }
        let textError = missingErrors.first(where: {
            if case .missingInputSource(_, _, _, let name, _) = $0 { return name == "文本" }; return false
        })
        XCTAssertNotNil(textError, "Template referencing {{文本}} should require 文本 port")
    }

    func testPromptTemplateSkipsUnreferencedPort() {
        let promptNode = WorkflowNode(
            id: "pt", title: "提示词模板",
            config: .promptTemplate(PromptTemplateNodeConfig(template: "一只猫，{{风格}}")),
            inputPorts: [
                WorkflowPort(name: "文本", portType: .text, nodeId: "", role: .styleVariable),
                WorkflowPort(name: "风格", portType: .text, nodeId: "", role: .styleVariable),
            ]
        )
        let def = WorkflowDefinition(
            name: "template-skip",
            nodes: [promptNode],
            edges: []
        )

        let errors = def.fullValidate()
        let missingErrors = errors.filter { if case .missingInputSource = $0 { return true }; return false }
        // Only "风格" should be required (referenced in template); "文本" should be skipped
        let textError = missingErrors.first(where: {
            if case .missingInputSource(_, _, _, let name, _) = $0 { return name == "文本" }; return false
        })
        XCTAssertNil(textError, "Unreferenced port 文本 should not be flagged as missing")
        let styleError = missingErrors.first(where: {
            if case .missingInputSource(_, _, _, let name, _) = $0 { return name == "风格" }; return false
        })
        XCTAssertNotNil(styleError, "Referenced port 风格 should be flagged as missing")
    }

    func testPromptTemplateEmptyTemplateNoRequiredPorts() {
        let promptNode = WorkflowNode(
            id: "pt", title: "提示词模板",
            config: .promptTemplate(PromptTemplateNodeConfig(template: "固定文本，无变量")),
            inputPorts: [WorkflowPort(name: "文本", portType: .text, nodeId: "", role: .styleVariable)]
        )
        let def = WorkflowDefinition(
            name: "template-no-var",
            nodes: [promptNode],
            edges: []
        )

        let errors = def.fullValidate()
        let missingErrors = errors.filter { if case .missingInputSource = $0 { return true }; return false }
        XCTAssertTrue(missingErrors.isEmpty, "Template with no {{var}} should not require ports, got: \(missingErrors)")
    }

    // MARK: - Per-node Config Fingerprint Tests

    func testPerNodeConfigFingerprintChangesWhenConfigChanges() {
        let nodeA = WorkflowNode(title: "文本输入", config: .textInput(TextInputNodeConfig(text: "hello")))
        let nodeB = WorkflowNode(title: "文本输入", config: .textInput(TextInputNodeConfig(text: "world")))
        XCTAssertNotEqual(nodeA.configFingerprint, nodeB.configFingerprint)
    }

    func testPerNodeConfigFingerprintStableWhenUnchanged() {
        var node1 = WorkflowNode(id: "n1", title: "文本输入", config: .textInput(TextInputNodeConfig(text: "hello")))
        var node2 = WorkflowNode(id: "n1", title: "文本输入", config: .textInput(TextInputNodeConfig(text: "hello")))
        XCTAssertEqual(node1.configFingerprint, node2.configFingerprint)
    }

    func testPerNodeConfigFingerprintDiffersBetweenNodeTypes() {
        let textNode = WorkflowNode(title: "文本", config: .textInput(TextInputNodeConfig(text: "hello")))
        let imageNode = WorkflowNode(title: "图片", config: .imageGen(ImageGenNodeConfig()))
        XCTAssertNotEqual(textNode.configFingerprint, imageNode.configFingerprint)
    }

    // MARK: - Per-node Config Fingerprints Convenience

    func testPerNodeConfigFingerprintsHasEntryPerNode() {
        let def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let dict = def.perNodeConfigFingerprints
        XCTAssertEqual(dict.count, def.nodes.count)
        for node in def.nodes {
            XCTAssertEqual(dict[node.id], node.configFingerprint)
        }
    }

    // MARK: - Downstream Node IDs

    func testDownstreamNodeIdsLinearChain() {
        let def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let nodes = def.nodes
        let textId = nodes.first(where: { if case .textInput = $0.config { return true }; return false })!.id
        let imageId = nodes.first(where: { if case .imageGen = $0.config { return true }; return false })!.id
        let videoId = nodes.first(where: { if case .videoGen = $0.config { return true }; return false })!.id
        let resultId = nodes.first(where: { if case .resultOutput = $0.config { return true }; return false })!.id

        let downstreamOfText = def.downstreamNodeIds(of: [textId])
        XCTAssertEqual(downstreamOfText.count, 3)
        XCTAssertTrue(downstreamOfText.contains(imageId))
        XCTAssertTrue(downstreamOfText.contains(videoId))
        XCTAssertTrue(downstreamOfText.contains(resultId))

        let downstreamOfImage = def.downstreamNodeIds(of: [imageId])
        XCTAssertEqual(downstreamOfImage.count, 2)
        XCTAssertTrue(downstreamOfImage.contains(videoId))
        XCTAssertTrue(downstreamOfImage.contains(resultId))

        let downstreamOfResult = def.downstreamNodeIds(of: [resultId])
        XCTAssertTrue(downstreamOfResult.isEmpty)
    }

    func testDownstreamNodeIdsFork() {
        let def = WorkflowDefinition.referenceToVideo.makeDefinition()
        let downstream = def.downstreamNodeIds(of: [def.nodes.first!.id])
        XCTAssertFalse(downstream.isEmpty, "Fork: upstream change should reach video node")
    }

    func testDownstreamNodeIdsLeafHasNoDownstream() {
        let def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let nodes = def.nodes
        let resultId = nodes.first(where: { if case .resultOutput = $0.config { return true }; return false })!.id
        XCTAssertTrue(def.downstreamNodeIds(of: [resultId]).isEmpty)
    }

    func testDownstreamNodeIdsEmptyChangedSet() {
        let def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        XCTAssertTrue(def.downstreamNodeIds(of: []).isEmpty)
    }

    // MARK: - Selective Cache Invalidation (structural unchanged, config-only)

    @MainActor
    func testRetryConfigChangePreservesUnchangedUpstream() {
        var def1 = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let store = WorkflowStore(api: APIService.shared)
        let videoNodeId = def1.nodes.first(where: { if case .videoGen = $0.config { return true }; return false })!.id
        let imageId = def1.nodes.first(where: { if case .imageGen = $0.config { return true }; return false })!.id
        let textId = def1.nodes.first(where: { if case .textInput = $0.config { return true }; return false })!.id
        let resultId = def1.nodes.first(where: { if case .resultOutput = $0.config { return true }; return false })!.id

        store.runState.isRunning = true
        store.runState.overallStatus = .running
        store.runState.cachedStructuralFingerprint = def1.structuralFingerprint
        store.runState.cachedConfigFingerprint = def1.configFingerprint
        store.runState.cachedPerNodeConfigFingerprints = def1.perNodeConfigFingerprints

        for node in def1.nodes {
            store.runState.nodeStatuses[node.id] = .succeeded
            var portCache: [String: WorkflowValue] = [:]
            for port in node.outputPorts {
                portCache[port.id] = .text("cached-\(port.name)")
            }
            store.runState.cachedNodeOutputs[node.id] = portCache
        }
        store.runState.isRunning = false
        store.runState.overallStatus = .failed

        if let idx = def1.nodes.firstIndex(where: { $0.id == videoNodeId }) {
            if case .videoGen(let oldCfg) = def1.nodes[idx].config {
                var newCfg = oldCfg
                newCfg.count = 2
                def1.nodes[idx].config = .videoGen(newCfg)
            }
        }
        XCTAssertEqual(def1.structuralFingerprint, store.runState.cachedStructuralFingerprint)
        XCTAssertNotEqual(def1.configFingerprint, store.runState.cachedConfigFingerprint)

        store.retryFromFailedNode(def1, workflowId: "test-retry-1", workflowName: "test")

        XCTAssertEqual(store.runState.nodeStatuses[textId], .succeeded, "upstream text node should stay succeeded")
        XCTAssertEqual(store.runState.nodeStatuses[imageId], .succeeded, "upstream image node should stay succeeded")
        XCTAssertNotNil(store.runState.cachedNodeOutputs[textId], "upstream cache should be preserved")
        XCTAssertNotNil(store.runState.cachedNodeOutputs[imageId], "upstream cache should be preserved")
        XCTAssertEqual(store.runState.nodeStatuses[videoNodeId], .pending, "changed video node should be reset")
        XCTAssertNil(store.runState.cachedNodeOutputs[videoNodeId], "changed video node cache should be cleared")
    }

    @MainActor
    func testRetryNoChangePreservesFailedOnlyBehavior() {
        let def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let store = WorkflowStore(api: APIService.shared)
        let nodeIds = def.nodes.map(\.id)

        store.runState.isRunning = true
        store.runState.overallStatus = .running
        store.runState.cachedStructuralFingerprint = def.structuralFingerprint
        store.runState.cachedConfigFingerprint = def.configFingerprint
        store.runState.cachedPerNodeConfigFingerprints = def.perNodeConfigFingerprints

        for node in def.nodes.prefix(2) {
            store.runState.nodeStatuses[node.id] = .succeeded
            var portCache: [String: WorkflowValue] = [:]
            for port in node.outputPorts {
                portCache[port.id] = .text("cached-\(port.name)")
            }
            store.runState.cachedNodeOutputs[node.id] = portCache
        }
        store.runState.nodeStatuses[nodeIds[2]] = .failed
        store.runState.nodeStatuses[nodeIds[3]] = .succeeded
        store.runState.isRunning = false
        store.runState.overallStatus = .failed

        store.retryFromFailedNode(def, workflowId: "test-retry-2", workflowName: "test")

        XCTAssertEqual(store.runState.nodeStatuses[nodeIds[0]], .succeeded)
        XCTAssertEqual(store.runState.nodeStatuses[nodeIds[1]], .succeeded)
        XCTAssertEqual(store.runState.nodeStatuses[nodeIds[2]], .pending, "failed node should be reset")
        // nodeIds[3] is downstream of nodeIds[2] → also invalidated
        XCTAssertEqual(store.runState.nodeStatuses[nodeIds[3]], .pending,
                       "downstream of failed node should also be reset")
    }

    @MainActor
    func testRetryStructuralChangeFallbacksToFullInvalidation() {
        var def1 = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let store = WorkflowStore(api: APIService.shared)

        store.runState.isRunning = true
        store.runState.overallStatus = .running
        store.runState.cachedStructuralFingerprint = def1.structuralFingerprint
        store.runState.cachedConfigFingerprint = def1.configFingerprint
        store.runState.cachedPerNodeConfigFingerprints = def1.perNodeConfigFingerprints
        for node in def1.nodes {
            store.runState.nodeStatuses[node.id] = .succeeded
            var portCache: [String: WorkflowValue] = [:]
            for port in node.outputPorts {
                portCache[port.id] = .text("cached-\(port.name)")
            }
            store.runState.cachedNodeOutputs[node.id] = portCache
        }
        store.runState.isRunning = false
        store.runState.overallStatus = .failed

        def1.nodes.append(WorkflowNode(title: "新节点", config: .textInput(TextInputNodeConfig(text: "new"))))

        store.retryFromFailedNode(def1, workflowId: "test-retry-3", workflowName: "test")

        XCTAssertTrue(store.runState.cachedNodeOutputs.isEmpty, "structural change should clear all cache")
        let allPending = store.runState.nodeStatuses.values.allSatisfy { $0 == .pending }
        XCTAssertTrue(allPending, "structural change should reset all nodes to pending")
        XCTAssertEqual(store.runState.nodeStatuses.count, def1.nodes.count, "new nodes should be in statuses")
    }

    @MainActor
    func testRetryCachesPerNodeFingerprints() {
        let def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let store = WorkflowStore(api: APIService.shared)

        store.runState.isRunning = true
        store.runState.overallStatus = .running
        store.runState.cachedStructuralFingerprint = def.structuralFingerprint
        store.runState.cachedConfigFingerprint = def.configFingerprint
        store.runState.cachedPerNodeConfigFingerprints = def.perNodeConfigFingerprints
        for node in def.nodes {
            store.runState.nodeStatuses[node.id] = .succeeded
        }
        store.runState.isRunning = false
        store.runState.overallStatus = .failed

        store.retryFromFailedNode(def, workflowId: "test-retry-4", workflowName: "test")

        let cached = store.runState.cachedPerNodeConfigFingerprints
        XCTAssertEqual(cached.count, def.nodes.count)
        for node in def.nodes {
            XCTAssertEqual(cached[node.id], node.configFingerprint)
        }
    }

    // MARK: - FullValidate Guard in Retry

    @MainActor
    func testRetryRefusesInvalidDefinition() {
        var def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let store = WorkflowStore(api: APIService.shared)

        store.runState.isRunning = true
        store.runState.overallStatus = .running
        store.runState.cachedStructuralFingerprint = def.structuralFingerprint
        store.runState.cachedConfigFingerprint = def.configFingerprint
        for node in def.nodes {
            store.runState.nodeStatuses[node.id] = .succeeded
        }
        store.runState.isRunning = false
        store.runState.overallStatus = .failed

        def.nodes[0].config = .textInput(TextInputNodeConfig(text: ""))

        store.retryFromFailedNode(def, workflowId: "test-retry-invalid", workflowName: "test")

        XCTAssertEqual(store.runState.overallStatus, .failed, "retry should be refused for invalid definition")
    }

    // MARK: - Cache Integrity Check Before Skip

    @MainActor
    func testIncompleteCacheDoesNotSkipNode() async throws {
        let def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let store = WorkflowStore(api: APIService.shared)
        let textNode = def.nodes.first(where: { if case .textInput = $0.config { return true }; return false })!
        let imageNode = def.nodes.first(where: { if case .imageGen = $0.config { return true }; return false })!
        let videoNode = def.nodes.first(where: { if case .videoGen = $0.config { return true }; return false })!
        let resultNode = def.nodes.first(where: { if case .resultOutput = $0.config { return true }; return false })!

        store.runState.isRunning = true
        store.runState.overallStatus = .running
        store.runState.cachedStructuralFingerprint = def.structuralFingerprint
        store.runState.cachedConfigFingerprint = def.configFingerprint
        store.runState.cachedPerNodeConfigFingerprints = def.perNodeConfigFingerprints

        for node in def.nodes {
            store.runState.nodeStatuses[node.id] = .succeeded
        }
        let textOutputPort = textNode.outputPorts.first!
        store.runState.cachedNodeOutputs[textNode.id] = [textOutputPort.id: .text("cached")]

        store.runState.isRunning = false
        store.runState.overallStatus = .failed

        store.retryFromFailedNode(def, workflowId: "test-cache-int", workflowName: "test")

        // Wait for executeDAG task to complete (max 5s)
        let deadline = Date().addingTimeInterval(5)
        while store.runState.isRunning && Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTAssertFalse(store.runState.isRunning, "executeDAG should have completed")
        XCTAssertNotEqual(store.runState.nodeStatuses[imageNode.id], .skipped,
                          "incomplete-cache image node must not be skipped")
        XCTAssertNotEqual(store.runState.nodeStatuses[imageNode.id], .pending,
                          "incomplete-cache image node must be re-executed, not stuck pending")
    }

    // MARK: - Duplicate Node ID Safety

    func testPerNodeConfigFingerprintsHandlesDuplicateIDs() {
        let node = WorkflowNode(id: "dup", title: "节点", config: .textInput(TextInputNodeConfig(text: "a")))
        let def = WorkflowDefinition(name: "test", nodes: [node, node], edges: [])
        let dict = def.perNodeConfigFingerprints
        XCTAssertEqual(dict.count, 1, "duplicate IDs should collapse to one entry")
        XCTAssertEqual(dict["dup"], node.configFingerprint)
    }

    // MARK: - Downstream Correctly Excludes Seed Nodes

    func testDownstreamNodeIdsExcludesSeedNodes() {
        let def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let nodes = def.nodes
        let textId = nodes.first(where: { if case .textInput = $0.config { return true }; return false })!.id
        let result = def.downstreamNodeIds(of: [textId])
        XCTAssertFalse(result.contains(textId), "downstream should not include the seed node itself")
    }

    // MARK: - Per-node Structural Fingerprint Tests

    func testPerNodeStructuralFingerprintStableWhenUnchanged() {
        let node = WorkflowNode(id: "n1", title: "文本输入", config: .textInput(TextInputNodeConfig(text: "a")))
        let fp1 = node.structuralFingerprint
        let fp2 = node.structuralFingerprint
        XCTAssertEqual(fp1, fp2, "same instance should produce same fingerprint")
    }

    func testPerNodeStructuralFingerprintChangesWhenPortsDiffer() {
        let node1 = WorkflowNode(id: "n1", title: "文本输入", config: .textInput(TextInputNodeConfig(text: "a")))
        let node2 = WorkflowNode(id: "n1", title: "文本输入", config: .textInput(TextInputNodeConfig(text: "a")),
                                 inputPorts: [WorkflowPort(name: "extra", portType: .text, nodeId: "", role: .styleVariable)])
        XCTAssertNotEqual(node1.structuralFingerprint, node2.structuralFingerprint)
    }

    func testPerNodeStructuralFingerprintsIncludesEdgeContext() {
        let def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let structFPs = def.perNodeStructuralFingerprints
        XCTAssertEqual(structFPs.count, def.nodes.count)

        var def2 = def
        let resultId = def2.nodes.first(where: { if case .resultOutput = $0.config { return true }; return false })!.id
        def2.edges.removeAll(where: { $0.targetNodeId == resultId })

        let structFPs2 = def2.perNodeStructuralFingerprints
        XCTAssertNotEqual(structFPs[resultId], structFPs2[resultId],
                          "edge removal should change target node (result) structural fingerprint")
    }

    // MARK: - Structural Diff Selective Invalidation

    @MainActor
    func testRetryAddNodeSelectiveInvalidation() {
        var def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let store = WorkflowStore(api: APIService.shared)
        let textId = def.nodes.first(where: { if case .textInput = $0.config { return true }; return false })!.id
        let imageId = def.nodes.first(where: { if case .imageGen = $0.config { return true }; return false })!.id
        let videoId = def.nodes.first(where: { if case .videoGen = $0.config { return true }; return false })!.id

        store.runState.isRunning = true
        store.runState.overallStatus = .running
        store.runState.cachedStructuralFingerprint = def.structuralFingerprint
        store.runState.cachedConfigFingerprint = def.configFingerprint
        store.runState.cachedPerNodeConfigFingerprints = def.perNodeConfigFingerprints
        store.runState.cachedPerNodeStructuralFingerprints = def.perNodeStructuralFingerprints
        for node in def.nodes {
            store.runState.nodeStatuses[node.id] = .succeeded
            var portCache: [String: WorkflowValue] = [:]
            for port in node.outputPorts {
                portCache[port.id] = .text("cached-\(port.name)")
            }
            store.runState.cachedNodeOutputs[node.id] = portCache
        }
        store.runState.isRunning = false
        store.runState.overallStatus = .failed

        let newResultNode = WorkflowNode(title: "新结果",
                                          config: .resultOutput(ResultOutputNodeConfig(label: "extra")))
        let videoOutput = def.nodes.first(where: { $0.id == videoId })!.outputPorts.first!
        let newEdge = WorkflowEdge(sourceNodeId: videoId,
                                    sourcePortId: videoOutput.id,
                                    targetNodeId: newResultNode.id,
                                    targetPortId: newResultNode.inputPorts.first!.id)
        def.nodes.append(newResultNode)
        def.edges.append(newEdge)

        let errors = def.fullValidate()
        XCTAssertTrue(errors.isEmpty, "fullValidate should pass but got: \(errors.map { $0.errorDescription ?? "?" })")

        store.retryFromFailedNode(def, workflowId: "test-add", workflowName: "test")

        XCTAssertEqual(store.runState.overallStatus, .running, "retry should have been accepted")
        XCTAssertEqual(store.runState.nodeStatuses[newResultNode.id], .pending, "new node should be pending")
        XCTAssertEqual(store.runState.nodeStatuses[textId], .succeeded, "unrelated upstream should stay succeeded")
        XCTAssertEqual(store.runState.nodeStatuses[imageId], .succeeded, "unrelated upstream should stay succeeded")
        XCTAssertEqual(store.runState.nodeStatuses[videoId], .succeeded, "source of new outgoing edge should stay succeeded")
        XCTAssertNotNil(store.runState.cachedNodeOutputs[textId], "upstream cache preserved")
        XCTAssertNotNil(store.runState.cachedNodeOutputs[videoId], "video cache preserved")
    }

    @MainActor
    func testRetryDeleteNodeSelectiveInvalidation() {
        var def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let store = WorkflowStore(api: APIService.shared)
        let textId = def.nodes.first(where: { if case .textInput = $0.config { return true }; return false })!.id
        let imageId = def.nodes.first(where: { if case .imageGen = $0.config { return true }; return false })!.id
        let videoId = def.nodes.first(where: { if case .videoGen = $0.config { return true }; return false })!.id
        let resultId = def.nodes.first(where: { if case .resultOutput = $0.config { return true }; return false })!.id

        store.runState.isRunning = true
        store.runState.overallStatus = .running
        store.runState.cachedStructuralFingerprint = def.structuralFingerprint
        store.runState.cachedConfigFingerprint = def.configFingerprint
        store.runState.cachedPerNodeConfigFingerprints = def.perNodeConfigFingerprints
        store.runState.cachedPerNodeStructuralFingerprints = def.perNodeStructuralFingerprints
        for node in def.nodes {
            store.runState.nodeStatuses[node.id] = .succeeded
            var portCache: [String: WorkflowValue] = [:]
            for port in node.outputPorts {
                portCache[port.id] = .text("cached-\(port.name)")
            }
            store.runState.cachedNodeOutputs[node.id] = portCache
        }
        store.runState.isRunning = false
        store.runState.overallStatus = .failed

        def.nodes.removeAll(where: { $0.id == resultId })
        def.edges.removeAll(where: { $0.sourceNodeId == resultId || $0.targetNodeId == resultId })

        let errors = def.fullValidate()
        XCTAssertTrue(errors.isEmpty, "fullValidate should pass but got: \(errors.map { $0.errorDescription ?? "?" })")

        store.retryFromFailedNode(def, workflowId: "test-del", workflowName: "test")

        XCTAssertEqual(store.runState.overallStatus, .running, "retry should have been accepted")
        XCTAssertEqual(store.runState.nodeStatuses[textId], .succeeded, "upstream should stay succeeded")
        XCTAssertEqual(store.runState.nodeStatuses[imageId], .succeeded, "upstream should stay succeeded")
        XCTAssertEqual(store.runState.nodeStatuses[videoId], .succeeded, "source of deleted consumer should stay succeeded")
        XCTAssertNotNil(store.runState.cachedNodeOutputs[textId], "upstream cache preserved")
        XCTAssertNotNil(store.runState.cachedNodeOutputs[videoId], "video cache preserved")
    }

    @MainActor
    func testRetryAddEdgeSelectiveInvalidation() {
        var def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let store = WorkflowStore(api: APIService.shared)
        let imageId = def.nodes.first(where: { if case .imageGen = $0.config { return true }; return false })!.id
        let videoId = def.nodes.first(where: { if case .videoGen = $0.config { return true }; return false })!.id
        let textId = def.nodes.first(where: { if case .textInput = $0.config { return true }; return false })!.id

        store.runState.isRunning = true
        store.runState.overallStatus = .running
        store.runState.cachedStructuralFingerprint = def.structuralFingerprint
        store.runState.cachedConfigFingerprint = def.configFingerprint
        store.runState.cachedPerNodeConfigFingerprints = def.perNodeConfigFingerprints
        store.runState.cachedPerNodeStructuralFingerprints = def.perNodeStructuralFingerprints
        for node in def.nodes {
            store.runState.nodeStatuses[node.id] = .succeeded
            var portCache: [String: WorkflowValue] = [:]
            for port in node.outputPorts {
                portCache[port.id] = .text("cached-\(port.name)")
            }
            store.runState.cachedNodeOutputs[node.id] = portCache
        }
        store.runState.isRunning = false
        store.runState.overallStatus = .failed

        let imageOutput = def.nodes.first(where: { $0.id == imageId })!.outputPorts.first!
        let videoFirstFramePort = def.nodes.first(where: { $0.id == videoId })!.inputPorts.first(where: { $0.role == .firstFrame })!
        let newEdge = WorkflowEdge(sourceNodeId: imageId,
                                    sourcePortId: imageOutput.id,
                                    targetNodeId: videoId,
                                    targetPortId: videoFirstFramePort.id)
        def.edges.append(newEdge)

        let errors = def.fullValidate()
        XCTAssertTrue(errors.isEmpty, "fullValidate should pass but got: \(errors.map { $0.errorDescription ?? "?" })")

        store.retryFromFailedNode(def, workflowId: "test-adder", workflowName: "test")

        XCTAssertEqual(store.runState.overallStatus, .running, "retry should have been accepted")
        XCTAssertEqual(store.runState.nodeStatuses[imageId], .succeeded, "source of new outgoing edge should stay succeeded")
        XCTAssertEqual(store.runState.nodeStatuses[videoId], .pending, "target of new edge (incoming changed) should be pending")
        XCTAssertEqual(store.runState.nodeStatuses[textId], .succeeded, "unchanged upstream should survive")
        XCTAssertNotNil(store.runState.cachedNodeOutputs[textId], "upstream cache preserved")
        XCTAssertNotNil(store.runState.cachedNodeOutputs[imageId], "image source cache preserved")
    }

    @MainActor
    func testRetryCombinedStructuralAndConfigChange() {
        var def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let store = WorkflowStore(api: APIService.shared)
        let textId = def.nodes.first(where: { if case .textInput = $0.config { return true }; return false })!.id
        let imageId = def.nodes.first(where: { if case .imageGen = $0.config { return true }; return false })!.id

        store.runState.isRunning = true
        store.runState.overallStatus = .running
        store.runState.cachedStructuralFingerprint = def.structuralFingerprint
        store.runState.cachedConfigFingerprint = def.configFingerprint
        store.runState.cachedPerNodeConfigFingerprints = def.perNodeConfigFingerprints
        store.runState.cachedPerNodeStructuralFingerprints = def.perNodeStructuralFingerprints
        for node in def.nodes {
            store.runState.nodeStatuses[node.id] = .succeeded
            var portCache: [String: WorkflowValue] = [:]
            for port in node.outputPorts {
                portCache[port.id] = .text("cached-\(port.name)")
            }
            store.runState.cachedNodeOutputs[node.id] = portCache
        }
        store.runState.isRunning = false
        store.runState.overallStatus = .failed

        def.nodes.append(WorkflowNode(title: "新节点", config: .textInput(TextInputNodeConfig(text: "new"))))
        if let idx = def.nodes.firstIndex(where: { $0.id == imageId }) {
            if case .imageGen(let oldCfg) = def.nodes[idx].config {
                var newCfg = oldCfg
                newCfg.quality = .high
                def.nodes[idx].config = .imageGen(newCfg)
            }
        }

        store.retryFromFailedNode(def, workflowId: "test-combined", workflowName: "test")

        XCTAssertEqual(store.runState.nodeStatuses[textId], .succeeded,
                       "unchanged upstream should survive combined str+cfg change")
        XCTAssertNotNil(store.runState.cachedNodeOutputs[textId])
        XCTAssertEqual(store.runState.nodeStatuses[imageId], .pending,
                       "config-changed node should be pending even if structure also changed")
    }

    @MainActor
    func testRetryCachesPerNodeStructuralFingerprints() {
        let def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let store = WorkflowStore(api: APIService.shared)

        store.runState.isRunning = true
        store.runState.overallStatus = .running
        store.runState.cachedStructuralFingerprint = def.structuralFingerprint
        store.runState.cachedConfigFingerprint = def.configFingerprint
        store.runState.cachedPerNodeConfigFingerprints = def.perNodeConfigFingerprints
        store.runState.cachedPerNodeStructuralFingerprints = def.perNodeStructuralFingerprints
        for node in def.nodes {
            store.runState.nodeStatuses[node.id] = .succeeded
        }
        store.runState.isRunning = false
        store.runState.overallStatus = .failed

        store.retryFromFailedNode(def, workflowId: "test-strfp", workflowName: "test")

        let cached = store.runState.cachedPerNodeStructuralFingerprints
        XCTAssertEqual(cached.count, def.nodes.count)
    }

    // MARK: - Port Role/Name Changes Invalidate Fingerprint

    func testPortRoleChangeChangesStructuralFingerprint() {
        let port1 = WorkflowPort(name: "图片", portType: .image, nodeId: "n1", role: .image)
        let port2 = WorkflowPort(name: "图片", portType: .image, nodeId: "n1", role: .firstFrame)
        let node1 = WorkflowNode(id: "n1", title: "test", config: .videoGen(VideoGenNodeConfig()),
                                  inputPorts: [port1], outputPorts: [])
        let node2 = WorkflowNode(id: "n1", title: "test", config: .videoGen(VideoGenNodeConfig()),
                                  inputPorts: [port2], outputPorts: [])
        XCTAssertNotEqual(node1.structuralFingerprint, node2.structuralFingerprint,
                          "port role change should change structural fingerprint")
    }

    func testPortNameChangeChangesStructuralFingerprint() {
        let port1 = WorkflowPort(name: "图片", portType: .image, nodeId: "n1", role: .image)
        let port2 = WorkflowPort(name: "参考图", portType: .image, nodeId: "n1", role: .image)
        let node1 = WorkflowNode(id: "n1", title: "test", config: .videoGen(VideoGenNodeConfig()),
                                  inputPorts: [port1], outputPorts: [])
        let node2 = WorkflowNode(id: "n1", title: "test", config: .videoGen(VideoGenNodeConfig()),
                                  inputPorts: [port2], outputPorts: [])
        XCTAssertNotEqual(node1.structuralFingerprint, node2.structuralFingerprint,
                          "port name change should change structural fingerprint")
    }

    func testGlobalStructuralFingerprintIncludesNameAndRole() {
        let nodeA = WorkflowNode(id: "v", title: "video", config: .videoGen(VideoGenNodeConfig()))
        let def1 = WorkflowDefinition(name: "test", nodes: [nodeA], edges: [])
        let fp1 = def1.structuralFingerprint

        let customPort = WorkflowPort(name: "custom", portType: .image, nodeId: "v", role: .firstFrame)
        let nodeB = WorkflowNode(id: "v", title: "video", config: .videoGen(VideoGenNodeConfig()),
                                  inputPorts: [customPort], outputPorts: nodeA.outputPorts)
        let def2 = WorkflowDefinition(name: "test", nodes: [nodeB], edges: [])
        let fp2 = def2.structuralFingerprint

        XCTAssertNotEqual(fp1, fp2, "global structural fingerprint should detect port name/role change")
    }

    // MARK: - Source Node Not Invalidated by Outgoing Edge Changes

    @MainActor
    func testRetryNewOutgoingEdgePreservesSourceCache() {
        var def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let store = WorkflowStore(api: APIService.shared)
        let imageId = def.nodes.first(where: { if case .imageGen = $0.config { return true }; return false })!.id
        let videoId = def.nodes.first(where: { if case .videoGen = $0.config { return true }; return false })!.id

        store.runState.isRunning = true
        store.runState.overallStatus = .running
        store.runState.cachedStructuralFingerprint = def.structuralFingerprint
        store.runState.cachedConfigFingerprint = def.configFingerprint
        store.runState.cachedPerNodeConfigFingerprints = def.perNodeConfigFingerprints
        store.runState.cachedPerNodeStructuralFingerprints = def.perNodeStructuralFingerprints
        for node in def.nodes {
            store.runState.nodeStatuses[node.id] = .succeeded
            var portCache: [String: WorkflowValue] = [:]
            for port in node.outputPorts {
                portCache[port.id] = .text("cached-\(port.name)")
            }
            store.runState.cachedNodeOutputs[node.id] = portCache
        }
        store.runState.isRunning = false
        store.runState.overallStatus = .failed

        let imageOutput = def.nodes.first(where: { $0.id == imageId })!.outputPorts.first!
        let videoFirstFramePort = def.nodes.first(where: { $0.id == videoId })!.inputPorts.first(where: { $0.role == .firstFrame })!
        def.edges.append(WorkflowEdge(sourceNodeId: imageId, sourcePortId: imageOutput.id,
                                       targetNodeId: videoId, targetPortId: videoFirstFramePort.id))

        let errors = def.fullValidate()
        XCTAssertTrue(errors.isEmpty, "fullValidate should pass: \(errors)")

        store.retryFromFailedNode(def, workflowId: "test-out-src", workflowName: "test")

        XCTAssertEqual(store.runState.nodeStatuses[imageId], .succeeded,
                       "source of new outgoing edge should NOT be invalidated")
        XCTAssertNotNil(store.runState.cachedNodeOutputs[imageId], "source cache should be preserved")
        XCTAssertEqual(store.runState.nodeStatuses[videoId], .pending,
                       "target with new incoming edge should be pending")
    }

    // MARK: - Failed/Cancelled Cleanup in Structure Branch

    @MainActor
    func testRetryStructuralChangeCleansFailedNodesOutsideInvalidated() {
        var def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let store = WorkflowStore(api: APIService.shared)
        let imageId = def.nodes.first(where: { if case .imageGen = $0.config { return true }; return false })!.id
        let textId = def.nodes.first(where: { if case .textInput = $0.config { return true }; return false })!.id

        store.runState.isRunning = true
        store.runState.overallStatus = .running
        store.runState.cachedStructuralFingerprint = def.structuralFingerprint
        store.runState.cachedConfigFingerprint = def.configFingerprint
        store.runState.cachedPerNodeConfigFingerprints = def.perNodeConfigFingerprints
        store.runState.cachedPerNodeStructuralFingerprints = def.perNodeStructuralFingerprints
        store.runState.nodeStatuses[textId] = .succeeded
        store.runState.nodeStatuses[imageId] = .failed
        store.runState.stepErrors[imageId] = "old error"
        store.runState.nodeLogs[imageId] = ["old log"]
        store.runState.nodeDetails[imageId] = WorkflowNodeRunDetail(startedAt: Date())
        for node in def.nodes {
            var portCache: [String: WorkflowValue] = [:]
            for port in node.outputPorts {
                portCache[port.id] = .text("cached-\(port.name)")
            }
            store.runState.cachedNodeOutputs[node.id] = portCache
        }
        store.runState.isRunning = false
        store.runState.overallStatus = .failed

        def.nodes.append(WorkflowNode(title: "新节点", config: .textInput(TextInputNodeConfig(text: "new"))))

        store.retryFromFailedNode(def, workflowId: "test-clean", workflowName: "test")

        XCTAssertEqual(store.runState.nodeStatuses[textId], .succeeded, "unrelated succeeded should stay")
        XCTAssertEqual(store.runState.nodeStatuses[imageId], .pending, "failed outside invalidated should become pending")
        XCTAssertNil(store.runState.stepErrors[imageId], "old error should be cleared")
        XCTAssertNil(store.runState.nodeLogs[imageId], "old logs should be cleared")
    }

    // MARK: - retryFromNode Tests

    @MainActor
    func testRetryFromNodeClearsCacheForTargetAndDownstream() {
        let def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let store = WorkflowStore(api: APIService.shared)
        let textId = def.nodes.first(where: { if case .textInput = $0.config { return true }; return false })!.id
        let imageId = def.nodes.first(where: { if case .imageGen = $0.config { return true }; return false })!.id
        let videoId = def.nodes.first(where: { if case .videoGen = $0.config { return true }; return false })!.id
        let resultId = def.nodes.first(where: { if case .resultOutput = $0.config { return true }; return false })!.id

        store.runState.cachedStructuralFingerprint = def.structuralFingerprint
        store.runState.cachedConfigFingerprint = def.configFingerprint
        store.runState.cachedPerNodeConfigFingerprints = def.perNodeConfigFingerprints
        store.runState.cachedPerNodeStructuralFingerprints = def.perNodeStructuralFingerprints

        for node in def.nodes {
            store.runState.nodeStatuses[node.id] = .succeeded
            var portCache: [String: WorkflowValue] = [:]
            for port in node.outputPorts {
                portCache[port.id] = .text("cached-\(port.name)")
            }
            store.runState.cachedNodeOutputs[node.id] = portCache
        }
        store.runState.isRunning = false
        store.runState.overallStatus = .succeeded

        store.retryFromNode(imageId, in: def, workflowId: "test-rfn", workflowName: "test")

        // Upstream should be preserved
        XCTAssertEqual(store.runState.nodeStatuses[textId], .succeeded,
                       "upstream text node should stay succeeded")
        XCTAssertNotNil(store.runState.cachedNodeOutputs[textId],
                        "upstream text cache should be preserved")

        // Target node should be pending with cleared cache
        XCTAssertEqual(store.runState.nodeStatuses[imageId], .pending,
                       "target image node should be pending")
        XCTAssertNil(store.runState.cachedNodeOutputs[imageId],
                     "target image cache should be cleared")

        // Downstream nodes should be pending with cleared cache
        XCTAssertEqual(store.runState.nodeStatuses[videoId], .pending,
                       "downstream video node should be pending")
        XCTAssertNil(store.runState.cachedNodeOutputs[videoId],
                     "downstream video cache should be cleared")
        XCTAssertEqual(store.runState.nodeStatuses[resultId], .pending,
                       "downstream result node should be pending")
        XCTAssertNil(store.runState.cachedNodeOutputs[resultId],
                     "downstream result cache should be cleared")

        store.cancelRun()
    }

    @MainActor
    func testRetryFromNodeRefusesInvalidDefinition() {
        var def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let store = WorkflowStore(api: APIService.shared)
        let videoId = def.nodes.first(where: { if case .videoGen = $0.config { return true }; return false })!.id

        for node in def.nodes {
            store.runState.nodeStatuses[node.id] = .succeeded
        }
        store.runState.isRunning = false
        store.runState.overallStatus = .failed

        def.nodes[0].config = .textInput(TextInputNodeConfig(text: ""))

        store.retryFromNode(videoId, in: def, workflowId: "test-rfn-invalid", workflowName: "test")
        XCTAssertEqual(store.runState.overallStatus, .failed,
                       "retryFromNode should be refused for invalid definition")
    }

    @MainActor
    func testRetryFromNodeRefusesNonexistentNode() {
        let def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let store = WorkflowStore(api: APIService.shared)

        store.runState.overallStatus = .failed
        store.retryFromNode("nonexistent-id", in: def, workflowId: "test", workflowName: "test")
        XCTAssertEqual(store.runState.overallStatus, .failed,
                       "retryFromNode should be refused for nonexistent node")
    }

    @MainActor
    func testRetryFromNodePreservesParallelBranchCache() {
        let def = WorkflowDefinition.referenceToVideo.makeDefinition()
        let store = WorkflowStore(api: APIService.shared)
        let nodeIds = def.nodes.map(\.id)

        store.runState.cachedStructuralFingerprint = def.structuralFingerprint
        store.runState.cachedConfigFingerprint = def.configFingerprint
        store.runState.cachedPerNodeConfigFingerprints = def.perNodeConfigFingerprints
        store.runState.cachedPerNodeStructuralFingerprints = def.perNodeStructuralFingerprints

        for node in def.nodes {
            store.runState.nodeStatuses[node.id] = .succeeded
            var portCache: [String: WorkflowValue] = [:]
            for port in node.outputPorts {
                portCache[port.id] = .text("cached-\(port.name)")
            }
            store.runState.cachedNodeOutputs[node.id] = portCache
        }
        store.runState.isRunning = false
        store.runState.overallStatus = .succeeded

        // Retry from the first node (text input) — the other branch's node should be preserved
        let firstNodeId = nodeIds[0]
        store.retryFromNode(firstNodeId, in: def, workflowId: "test-parallel", workflowName: "test")

        let downstream = def.downstreamNodeIds(of: [firstNodeId])
        for nodeId in nodeIds {
            if downstream.contains(nodeId) {
                XCTAssertEqual(store.runState.nodeStatuses[nodeId], .pending,
                               "downstream \(nodeId) should be pending")
            } else if nodeId != firstNodeId {
                XCTAssertEqual(store.runState.nodeStatuses[nodeId], .succeeded,
                               "parallel branch \(nodeId) should stay succeeded")
                XCTAssertNotNil(store.runState.cachedNodeOutputs[nodeId],
                                "parallel branch \(nodeId) cache should be preserved")
            }
        }

        store.cancelRun()
    }

    // MARK: - reuseNode Tests

    @MainActor
    func testReuseNodeMarksNodeSucceeded() {
        let def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let store = WorkflowStore(api: APIService.shared)
        let imageId = def.nodes.first(where: { if case .imageGen = $0.config { return true }; return false })!.id
        let imageNode = def.nodes.first(where: { $0.id == imageId })!

        store.runState.nodeStatuses[imageId] = .failed
        store.runState.stepErrors[imageId] = "previous error"
        var portCache: [String: WorkflowValue] = [:]
        for port in imageNode.outputPorts {
            portCache[port.id] = .text("cached-output")
        }
        store.runState.cachedNodeOutputs[imageId] = portCache

        store.reuseNode(imageId, in: def)

        XCTAssertEqual(store.runState.nodeStatuses[imageId], .succeeded,
                       "reuseNode should mark node as succeeded")
        XCTAssertNil(store.runState.stepErrors[imageId],
                     "reuseNode should clear previous error")
    }

    @MainActor
    func testReuseNodeRefusesWhenRunning() {
        let def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let store = WorkflowStore(api: APIService.shared)
        let textId = def.nodes.first(where: { if case .textInput = $0.config { return true }; return false })!.id
        let textNode = def.nodes.first(where: { $0.id == textId })!

        store.runState.isRunning = true
        store.runState.nodeStatuses[textId] = .running
        var portCache: [String: WorkflowValue] = [:]
        for port in textNode.outputPorts {
            portCache[port.id] = .text("cached")
        }
        store.runState.cachedNodeOutputs[textId] = portCache

        store.reuseNode(textId, in: def)

        XCTAssertEqual(store.runState.nodeStatuses[textId], .running,
                       "reuseNode should not change running node")
    }

    @MainActor
    func testReuseNodeRefusesWhenNoCache() {
        let def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let store = WorkflowStore(api: APIService.shared)
        let textId = def.nodes.first(where: { if case .textInput = $0.config { return true }; return false })!.id

        store.runState.nodeStatuses[textId] = .failed

        store.reuseNode(textId, in: def)

        XCTAssertEqual(store.runState.nodeStatuses[textId], .failed,
                       "reuseNode should not change node without cached outputs")
    }

    // MARK: - nodesToReExecute Tests

    @MainActor
    func testNodesToReExecuteReturnsAllWhenNoState() {
        let def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let store = WorkflowStore(api: APIService.shared)
        let reExec = store.nodesToReExecute(in: def)
        XCTAssertEqual(reExec.count, def.nodes.count,
                       "all nodes should execute when there is no run state")
    }

    @MainActor
    func testNodesToReExecuteReturnsCorrectSet() {
        let def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let store = WorkflowStore(api: APIService.shared)
        let textId = def.nodes.first(where: { if case .textInput = $0.config { return true }; return false })!.id
        let textNode = def.nodes.first(where: { $0.id == textId })!
        let videoId = def.nodes.first(where: { if case .videoGen = $0.config { return true }; return false })!.id

        store.runState.cachedStructuralFingerprint = def.structuralFingerprint
        store.runState.cachedConfigFingerprint = def.configFingerprint
        store.runState.cachedPerNodeConfigFingerprints = def.perNodeConfigFingerprints
        store.runState.cachedPerNodeStructuralFingerprints = def.perNodeStructuralFingerprints

        // Set text node as succeeded with cache, video node as failed
        store.runState.nodeStatuses[textId] = .succeeded
        var textCache: [String: WorkflowValue] = [:]
        for port in textNode.outputPorts {
            textCache[port.id] = .text("cached")
        }
        store.runState.cachedNodeOutputs[textId] = textCache
        store.runState.nodeStatuses[videoId] = .failed

        let reExec = store.nodesToReExecute(in: def)
        XCTAssertFalse(reExec.contains(textId),
                       "cached succeeded node should not be in re-exec set")
        XCTAssertTrue(reExec.contains(videoId),
                       "failed node should be in re-exec set")
    }

    // MARK: - runWorkflowDefinitionPreservingCache Tests

    @MainActor
    func testRunWithCachePreservesUnchangedNodes() {
        let def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let store = WorkflowStore(api: APIService.shared)
        let textId = def.nodes.first(where: { if case .textInput = $0.config { return true }; return false })!.id

        store.runState.cachedStructuralFingerprint = def.structuralFingerprint
        store.runState.cachedConfigFingerprint = def.configFingerprint
        store.runState.cachedPerNodeConfigFingerprints = def.perNodeConfigFingerprints
        store.runState.cachedPerNodeStructuralFingerprints = def.perNodeStructuralFingerprints

        for node in def.nodes {
            store.runState.nodeStatuses[node.id] = .succeeded
            var portCache: [String: WorkflowValue] = [:]
            for port in node.outputPorts {
                portCache[port.id] = .text("cached-\(port.name)")
            }
            store.runState.cachedNodeOutputs[node.id] = portCache
        }
        store.runState.isRunning = false
        store.runState.overallStatus = .succeeded

        let started = store.runWorkflowDefinitionPreservingCache(def, workflowId: "test-preserve", workflowName: "test")
        XCTAssertTrue(started, "run should start")
        // All nodes should still have their cache (nothing changed)
        XCTAssertNotNil(store.runState.cachedNodeOutputs[textId], "unchanged text cache should be preserved")
        store.cancelRun()
    }

    @MainActor
    func testRunWithCacheFingerprintDiffInvalidatesChangedNodes() {
        var def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let store = WorkflowStore(api: APIService.shared)
        let textId = def.nodes.first(where: { if case .textInput = $0.config { return true }; return false })!.id
        let imageId = def.nodes.first(where: { if case .imageGen = $0.config { return true }; return false })!.id
        let videoId = def.nodes.first(where: { if case .videoGen = $0.config { return true }; return false })!.id
        let resultId = def.nodes.first(where: { if case .resultOutput = $0.config { return true }; return false })!.id

        store.runState.cachedStructuralFingerprint = def.structuralFingerprint
        store.runState.cachedConfigFingerprint = def.configFingerprint
        store.runState.cachedPerNodeConfigFingerprints = def.perNodeConfigFingerprints
        store.runState.cachedPerNodeStructuralFingerprints = def.perNodeStructuralFingerprints

        for node in def.nodes {
            store.runState.nodeStatuses[node.id] = .succeeded
            var portCache: [String: WorkflowValue] = [:]
            for port in node.outputPorts {
                portCache[port.id] = .text("cached-\(port.name)")
            }
            store.runState.cachedNodeOutputs[node.id] = portCache
        }
        store.runState.isRunning = false
        store.runState.overallStatus = .succeeded

        // Change image node config (different fingerprint)
        if let idx = def.nodes.firstIndex(where: { $0.id == imageId }) {
            if case .imageGen(let cfg) = def.nodes[idx].config {
                var newCfg = cfg
                newCfg.quality = .high
                def.nodes[idx].config = .imageGen(newCfg)
            }
        }

        let started = store.runWorkflowDefinitionPreservingCache(def, workflowId: "test-diff", workflowName: "test")
        XCTAssertTrue(started, "run should start")

        // Upstream unchanged
        XCTAssertEqual(store.runState.nodeStatuses[textId], .succeeded, "upstream text should stay succeeded")
        XCTAssertNotNil(store.runState.cachedNodeOutputs[textId], "upstream text cache should be preserved")
        // Changed node + downstream invalidated
        XCTAssertEqual(store.runState.nodeStatuses[imageId], .pending, "config-changed image should be pending")
        XCTAssertNil(store.runState.cachedNodeOutputs[imageId], "config-changed image cache cleared")
        XCTAssertEqual(store.runState.nodeStatuses[videoId], .pending, "image downstream video should be pending")
        XCTAssertNil(store.runState.cachedNodeOutputs[videoId], "image downstream video cache cleared")
        XCTAssertEqual(store.runState.nodeStatuses[resultId], .pending, "video downstream result should be pending")
        store.cancelRun()
    }

    @MainActor
    func testRunWithCacheFallsBackToFreshWhenNoPriorState() {
        let def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let store = WorkflowStore(api: APIService.shared)

        // No runState.nodeStatuses → should fall back to fresh run
        let started = store.runWorkflowDefinitionPreservingCache(def, workflowId: "test-fresh", workflowName: "test")
        XCTAssertTrue(started, "run should fall back to fresh")
        store.cancelRun()
    }

    @MainActor
    func testRetryFromNodeAlsoInvalidatesFingerprintChangedNodes() {
        var def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let store = WorkflowStore(api: APIService.shared)
        let textId = def.nodes.first(where: { if case .textInput = $0.config { return true }; return false })!.id
        let imageId = def.nodes.first(where: { if case .imageGen = $0.config { return true }; return false })!.id
        let videoId = def.nodes.first(where: { if case .videoGen = $0.config { return true }; return false })!.id
        let resultId = def.nodes.first(where: { if case .resultOutput = $0.config { return true }; return false })!.id

        store.runState.cachedStructuralFingerprint = def.structuralFingerprint
        store.runState.cachedConfigFingerprint = def.configFingerprint
        store.runState.cachedPerNodeConfigFingerprints = def.perNodeConfigFingerprints
        store.runState.cachedPerNodeStructuralFingerprints = def.perNodeStructuralFingerprints

        for node in def.nodes {
            store.runState.nodeStatuses[node.id] = .succeeded
            var portCache: [String: WorkflowValue] = [:]
            for port in node.outputPorts {
                portCache[port.id] = .text("cached-\(port.name)")
            }
            store.runState.cachedNodeOutputs[node.id] = portCache
        }
        store.runState.isRunning = false
        store.runState.overallStatus = .succeeded

        // Change text node config (fingerprint changes for text)
        if let idx = def.nodes.firstIndex(where: { $0.id == textId }) {
            if case .textInput(let cfg) = def.nodes[idx].config {
                var newCfg = cfg
                newCfg.text = "completely new prompt"
                def.nodes[idx].config = .textInput(newCfg)
            }
        }

        // Retry from video node (unrelated to the changed text node)
        store.retryFromNode(videoId, in: def, workflowId: "test-rfn-diff", workflowName: "test")

        // Text node's config changed → should be invalidated by fingerprint diff
        // even though it's not in video's downstream
        XCTAssertEqual(store.runState.nodeStatuses[textId], .pending,
                       "config-changed text node should be invalidated despite not being in downstream")
        XCTAssertNil(store.runState.cachedNodeOutputs[textId],
                     "config-changed text cache should be cleared")
        // image is text's downstream → also invalidated
        XCTAssertEqual(store.runState.nodeStatuses[imageId], .pending,
                       "text downstream image should be invalidated")
        // video node is manual target → pending
        XCTAssertEqual(store.runState.nodeStatuses[videoId], .pending,
                       "manual target video should be pending")
        // result is video's downstream → pending
        XCTAssertEqual(store.runState.nodeStatuses[resultId], .pending,
                       "video downstream result should be pending")
        store.cancelRun()
    }

    // MARK: - Downstream propagation on failure / incomplete cache

    @MainActor
    func testNodesToReExecutePropagatesDownstreamForFailedNode() {
        let def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let store = WorkflowStore(api: APIService.shared)
        let textId = def.nodes.first(where: { if case .textInput = $0.config { return true }; return false })!.id
        let imageId = def.nodes.first(where: { if case .imageGen = $0.config { return true }; return false })!.id
        let videoId = def.nodes.first(where: { if case .videoGen = $0.config { return true }; return false })!.id
        let resultId = def.nodes.first(where: { if case .resultOutput = $0.config { return true }; return false })!.id

        let textNode = def.nodes.first(where: { $0.id == textId })!
        let videoNode = def.nodes.first(where: { $0.id == videoId })!
        let resultNode = def.nodes.first(where: { $0.id == resultId })!

        store.runState.cachedStructuralFingerprint = def.structuralFingerprint
        store.runState.cachedConfigFingerprint = def.configFingerprint
        store.runState.cachedPerNodeConfigFingerprints = def.perNodeConfigFingerprints
        store.runState.cachedPerNodeStructuralFingerprints = def.perNodeStructuralFingerprints

        // text + video + result: succeeded with full cache
        store.runState.nodeStatuses[textId] = .succeeded
        store.runState.cachedNodeOutputs[textId] = [textNode.outputPorts.first!.id: .text("text-ok")]
        store.runState.nodeStatuses[videoId] = .succeeded
        store.runState.cachedNodeOutputs[videoId] = [videoNode.outputPorts.first!.id: .text("video-ok")]
        store.runState.nodeStatuses[resultId] = .succeeded
        // resultOutput has no output ports → no need to cache

        // image: failed → must propagate to downstream
        store.runState.nodeStatuses[imageId] = .failed
        store.runState.stepErrors[imageId] = "previous error"

        let reExec = store.nodesToReExecute(in: def)

        // text is succeeded+cached → skip
        XCTAssertFalse(reExec.contains(textId), "succeeded+cached text should not re-execute")
        // image is failed → root → must execute
        XCTAssertTrue(reExec.contains(imageId), "failed image must re-execute")
        // video+result are downstream of image → must also execute
        XCTAssertTrue(reExec.contains(videoId), "video downstream of failed image must re-execute")
        XCTAssertTrue(reExec.contains(resultId), "result downstream of failed image must re-execute")
    }

    @MainActor
    func testRunWithCachePropagatesDownstreamForFailedNode() {
        let def = WorkflowDefinition.textToImageToVideo.makeDefinition()
        let store = WorkflowStore(api: APIService.shared)
        let textId = def.nodes.first(where: { if case .textInput = $0.config { return true }; return false })!.id
        let imageId = def.nodes.first(where: { if case .imageGen = $0.config { return true }; return false })!.id
        let videoId = def.nodes.first(where: { if case .videoGen = $0.config { return true }; return false })!.id
        let resultId = def.nodes.first(where: { if case .resultOutput = $0.config { return true }; return false })!.id

        let textNode = def.nodes.first(where: { $0.id == textId })!
        let videoNode = def.nodes.first(where: { $0.id == videoId })!

        store.runState.cachedStructuralFingerprint = def.structuralFingerprint
        store.runState.cachedConfigFingerprint = def.configFingerprint
        store.runState.cachedPerNodeConfigFingerprints = def.perNodeConfigFingerprints
        store.runState.cachedPerNodeStructuralFingerprints = def.perNodeStructuralFingerprints

        store.runState.nodeStatuses[textId] = .succeeded
        store.runState.cachedNodeOutputs[textId] = [textNode.outputPorts.first!.id: .text("text-ok")]
        store.runState.nodeStatuses[imageId] = .failed
        store.runState.stepErrors[imageId] = "previous error"
        store.runState.nodeStatuses[videoId] = .succeeded
        store.runState.cachedNodeOutputs[videoId] = [videoNode.outputPorts.first!.id: .text("video-old")]
        store.runState.nodeStatuses[resultId] = .succeeded
        // resultOutput has no output ports → no need to cache

        store.runState.isRunning = false
        store.runState.overallStatus = .failed

        let started = store.runWorkflowDefinitionPreservingCache(def, workflowId: "test-downstream", workflowName: "test")
        XCTAssertTrue(started, "run should start")

        // Upstream preserved
        XCTAssertEqual(store.runState.nodeStatuses[textId], .succeeded, "upstream text stays succeeded")
        XCTAssertNotNil(store.runState.cachedNodeOutputs[textId], "upstream text cache preserved")
        // Failed node + downstream all cleared
        XCTAssertEqual(store.runState.nodeStatuses[imageId], .pending, "failed image is pending")
        XCTAssertNil(store.runState.cachedNodeOutputs[imageId], "failed image cache cleared")
        XCTAssertEqual(store.runState.nodeStatuses[videoId], .pending, "video downstream of failed is pending")
        XCTAssertNil(store.runState.cachedNodeOutputs[videoId], "video downstream cache cleared")
        XCTAssertEqual(store.runState.nodeStatuses[resultId], .pending, "result downstream of failed is pending")
        XCTAssertNil(store.runState.cachedNodeOutputs[resultId], "result downstream cache cleared")

        store.cancelRun()
    }
}
