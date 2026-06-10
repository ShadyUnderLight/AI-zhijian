import XCTest
@testable import aiZhijian

final class SmokeTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkflowRunTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        WorkflowRunPersistence.baseDirectoryOverride = tempDir
    }

    override func tearDown() {
        WorkflowRunPersistence.baseDirectoryOverride = nil
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - FileRef

    func testFileRefCodableRoundTrip() throws {
        let ref = FileRef(data: Data("hello".utf8), name: "test.txt", mime: "text/plain")
        let data = try JSONEncoder().encode(ref)
        let decoded = try JSONDecoder().decode(FileRef.self, from: data)
        XCTAssertEqual(decoded, ref)
    }

    // MARK: - WorkflowValue

    func testWorkflowValueTextSummary() {
        let v = WorkflowValue.text("hello")
        XCTAssertEqual(v.summary, "hello")
        XCTAssertEqual(v.textValue, "hello")
        XCTAssertEqual(v.portType, .text)
    }

    func testWorkflowValueNone() {
        let v = WorkflowValue.none
        XCTAssertEqual(v.summary, "无")
        XCTAssertEqual(v.portType, .any)
    }

    func testWorkflowValueCodableRoundTrip() throws {
        let v1 = WorkflowValue.text("hello")
        let data = try JSONEncoder().encode(v1)
        let v2 = try JSONDecoder().decode(WorkflowValue.self, from: data)
        XCTAssertEqual(v1, v2)
    }

    // MARK: - WorkflowRunContext

    func testRunContextSetAndGetOutput() {
        let ctx = WorkflowRunContext()
        ctx.setOutput(nodeId: "n1", portId: "p1", value: .text("hello"))
        XCTAssertEqual(ctx.output(nodeId: "n1", portId: "p1")?.textValue, "hello")
    }

    func testRunContextMissingUpstreamThrows() throws {
        let ctx = WorkflowRunContext()
        let def = WorkflowDefinition.sample()
        let imageNode = def.nodes.first(where: { $0.config.nodeType == .imageGen })!
        let port = imageNode.inputPorts.first!
        XCTAssertThrowsError(try ctx.inputValue(for: port, in: def))
    }

    func testRunContextWrongTargetNodeThrows() throws {
        let ctx = WorkflowRunContext()
        let def = WorkflowDefinition.sample()
        var bogusPort = WorkflowPort(name: "fake", portType: .text, nodeId: "nonexistent", role: .text)
        XCTAssertThrowsError(try ctx.inputValue(for: bogusPort, in: def))
    }

    func testRunContextTargetPortNotInputThrows() throws {
        let ctx = WorkflowRunContext()
        let def = WorkflowDefinition.sample()
        let textNode = def.nodes.first!
        let outputPort = textNode.outputPorts.first!
        XCTAssertThrowsError(try ctx.inputValue(for: outputPort, in: def)) { error in
            guard let e = error as? WorkflowRunContextError,
                  case .targetPortNotInput = e else {
                XCTFail("Expected targetPortNotInput, got \(error)")
                return
            }
        }
    }

    // MARK: - TemplateResolver

    func testTemplateResolverSimple() {
        let inputs: [String: WorkflowValue] = ["animal": .text("fox")]
        let result = WorkflowTemplateResolver.resolve("生成一张{{animal}}的图片", with: inputs)
        XCTAssertEqual(result, "生成一张fox的图片")
    }

    // MARK: - StepResult Adapter

    func testStepResultToWorkflowValueAdapter() {
        let sr = StepResult.text("hello")
        let wv = WorkflowValue(from: sr)
        XCTAssertEqual(wv.textValue, "hello")
    }

    func testStepResultNoneToNone() {
        let wv = WorkflowValue(from: StepResult.none)
        if case .none = wv {} else { XCTFail("Expected .none") }
    }

    func testStepResultMultiImagesToWorkflowValue() {
        let wv = WorkflowValue(from: StepResult.images(["https://a.com/1.png", "https://a.com/2.png"]))
        if case .images(let imgs) = wv {
            XCTAssertEqual(imgs.count, 2)
        } else {
            XCTFail("Expected .images with 2 items")
        }
    }

    // MARK: - VeoRules

    func testVeoRulesExposeExpectedBaselineCombinations() {
        XCTAssertTrue(VeoRules.isValidCombination(channel: "budget", model: "fast"))
        XCTAssertTrue(VeoRules.validModeValues(channel: "official", model: "pro").contains("reference"))
        XCTAssertEqual(VeoRules.validModelValues(channel: "yunwu"), ["veo_3_1", "veo_3_1-fast", "veo_3_1-4K", "veo_3_1-fast-4K"])
        XCTAssertTrue(VeoRules.isValidCombination(channel: "yunwu", model: "veo_3_1-fast"))
        XCTAssertFalse(VeoRules.isValidCombination(channel: "yunwu", model: "pro"))
        XCTAssertEqual(VeoRules.validModeValues(channel: "yunwu", model: "veo_3_1-fast"), ["text", "image"])
        XCTAssertFalse(VeoRules.isValidCombination(channel: "budget", model: "lite"))

        XCTAssertEqual(VeoRules.fixedDuration(channel: "budget", model: "fast", mode: "text"), "8")
        XCTAssertFalse(VeoRules.supportsDuration(channel: "budget", model: "fast", mode: "text"))
        XCTAssertTrue(VeoRules.shouldSendDurationValue(channel: "budget", model: "fast", mode: "text"))
        XCTAssertFalse(VeoRules.supportsDuration(channel: "yunwu", model: "veo_3_1", mode: "text"))
        XCTAssertFalse(VeoRules.shouldSendDurationValue(channel: "yunwu", model: "veo_3_1", mode: "text"))
        XCTAssertEqual(VeoRules.validResolutions(channel: "yunwu", model: "veo_3_1-4K", mode: "image").map(\.0), ["720p"])
        XCTAssertEqual(VeoRules.channelDisplayName("yunwu"), "云雾API中转")
        XCTAssertFalse(VeoRules.supportsNegativePrompt(channel: "yunwu"))
        XCTAssertTrue(VeoRules.supportsNegativePrompt(channel: "official"))
        XCTAssertEqual(VeoRules.validModelValues(channel: "apimart"), ["veo3.1-fast", "veo3.1-quality", "veo3.1-lite"])
        XCTAssertTrue(VeoRules.validModeValues(channel: "apimart", model: "veo3.1-fast").contains("image"))
        XCTAssertEqual(VeoRules.fixedDuration(channel: "apimart", model: "veo3.1-fast", mode: "text"), "8")
        XCTAssertFalse(VeoRules.supportsDuration(channel: "apimart", model: "veo3.1-fast", mode: "text"))
        XCTAssertEqual(VeoRules.validAspectRatios(channel: "apimart", model: "veo3.1-fast", mode: "text").map(\.0), ["9:16", "16:9"])
        XCTAssertEqual(VeoRules.fixedDuration(channel: "apimart", model: "veo3.1-fast", mode: "reference"), "8")
        XCTAssertTrue(VeoRules.shouldSendDurationValue(channel: "apimart", model: "veo3.1-fast", mode: "reference"))
        XCTAssertTrue(VeoRules.supportsAspectRatio(channel: "apimart", model: "veo3.1-fast", mode: "reference"))
        XCTAssertEqual(VeoRules.imageReferenceLimit(channel: "apimart", model: "veo3.1-fast", mode: "reference"), 3)
        XCTAssertFalse(VeoRules.validModeValues(channel: "apimart", model: "veo3.1-quality").contains("reference"))
        XCTAssertFalse(VeoRules.validModeValues(channel: "apimart", model: "veo3.1-lite").contains("image"))
    }

    // MARK: - WorkflowConfigs

    func testWorkflowConfigsValidateExpectedDefaults() {
        XCTAssertTrue(TextInputNodeConfig(text: "hello").validate().isEmpty)
        XCTAssertEqual(TextInputNodeConfig(text: "   ").validate(), [.invalidConfig("文本输入不能为空")])

        var video = VideoGenNodeConfig()
        XCTAssertTrue(video.validate().isEmpty)

        video.model = "lite"
        XCTAssertTrue(video.validate().contains(.invalidConfig("Veo 不支持模型 lite，可用: fast, pro")))

        video.genType = .grok
        video.channel = .apimart
        video.model = ""
        video.duration = "30"
        XCTAssertTrue(video.validate().isEmpty)

        video.channel = .official
        XCTAssertTrue(video.validate().contains(.invalidConfig("Grok 当前渠道不支持 30s 时长")))

        video.genType = .veo
        video.channel = .apimart
        video.model = "veo3.1-fast"
        video.duration = "8"
        XCTAssertTrue(video.validate().isEmpty)
    }

    // MARK: - WorkflowDefinition

    func testWorkflowDefinitionRoundTripsThroughJSON() throws {
        let input = WorkflowNode(
            id: "input",
            title: "Input",
            config: .textInput(TextInputNodeConfig(text: "make a short video"))
        )
        let output = WorkflowNode(
            id: "output",
            title: "Output",
            config: .resultOutput(ResultOutputNodeConfig())
        )
        let workflow = WorkflowDefinition(
            id: "smoke",
            name: "Smoke",
            nodes: [input, output],
            edges: []
        )

        XCTAssertTrue(workflow.validate().isEmpty)

        let data = try JSONEncoder().encode(workflow)
        let decoded = try JSONDecoder().decode(WorkflowDefinition.self, from: data)

        XCTAssertEqual(decoded, workflow)
        XCTAssertEqual(decoded.nodeIds, ["input", "output"])
    }

    // MARK: - Workflow Templates

    func testTemplatesCount() {
        XCTAssertEqual(WorkflowDefinition.templates.count, 8)
    }

    func testEachTemplateHasUniqueID() {
        let ids = WorkflowDefinition.templates.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testEachTemplateValidatesWithoutErrors() {
        for template in WorkflowDefinition.templates {
            let def = template.makeDefinition()
            let errors = def.fullValidate()
            XCTAssertTrue(errors.isEmpty,
                         "模板「\(template.name)」验证失败: \(errors.map { $0.errorDescription ?? "未知" }.joined(separator: ", "))")
        }
    }

    func testEachTemplateHasNodesAndEdges() {
        for template in WorkflowDefinition.templates {
            let def = template.makeDefinition()
            XCTAssertFalse(def.nodes.isEmpty, "模板「\(template.name)」没有节点")
            XCTAssertFalse(def.edges.isEmpty, "模板「\(template.name)」没有连线")
        }
    }

    func testTemplateNodeCountMatchesDefinition() {
        for template in WorkflowDefinition.templates {
            let def = template.makeDefinition()
            XCTAssertEqual(template.nodeCount, def.nodes.count,
                           "模板「\(template.name)」的 nodeCount(\(template.nodeCount)) 与实际节点数(\(def.nodes.count)) 不一致")
        }
    }

    func testEachTemplateRoundTripsThroughJSON() throws {
        for template in WorkflowDefinition.templates {
            let def = template.makeDefinition()
            let data = try JSONEncoder().encode(def)
            let decoded = try JSONDecoder().decode(WorkflowDefinition.self, from: data)
            XCTAssertEqual(decoded.nodes.count, def.nodes.count,
                           "模板「\(template.name)」JSON roundtrip 节点数不一致")
            XCTAssertEqual(decoded.edges.count, def.edges.count,
                           "模板「\(template.name)」JSON roundtrip 连线数不一致")
        }
    }

    func testEachTemplateGeneratesUniqueIDs() {
        let def1 = WorkflowDefinition.templates[0].makeDefinition()
        let def2 = WorkflowDefinition.templates[0].makeDefinition()
        XCTAssertNotEqual(def1.id, def2.id, "同一模板多次创建应生成不同 ID")
        XCTAssertNotEqual(def1.nodes.first?.id, def2.nodes.first?.id, "同一模板节点应有不同 ID")
    }

    // MARK: - Template Semantic Tests

    func testReferenceTemplateHasImageEdgeToVeo() {
        let def = WorkflowDefinition.referenceToVideo.makeDefinition()
        let videoNode = def.nodes.first(where: { $0.config.nodeType == .videoGen })!
        let imageInput = videoNode.inputPorts.first(where: { $0.role == .image })!
        let hasImageEdge = def.edges.contains { $0.targetPortId == imageInput.id }
        XCTAssertTrue(hasImageEdge, "参考图模板的 Veo 节点图片端口必须有连线")
    }

    func testStartEndTemplateHasFirstFrameEdge() {
        let def = WorkflowDefinition.startEndFrameToVideo.makeDefinition()
        let videoNode = def.nodes.first(where: { $0.config.nodeType == .videoGen })!
        let firstFrameInput = videoNode.inputPorts.first(where: { $0.role == .firstFrame })!
        let hasFirstFrameEdge = def.edges.contains { $0.targetPortId == firstFrameInput.id }
        XCTAssertTrue(hasFirstFrameEdge, "首尾帧模板的首帧端口必须有连线")
    }

    func testStartEndTemplateHasPromptInputsForImageGen() {
        let def = WorkflowDefinition.startEndFrameToVideo.makeDefinition()
        let imageGenNodes = def.nodes.filter { $0.config.nodeType == .imageGen }
        for imgNode in imageGenNodes {
            let promptInput = imgNode.inputPorts.first(where: { $0.role == .prompt })!
            let hasPromptEdge = def.edges.contains { $0.targetPortId == promptInput.id }
            XCTAssertTrue(hasPromptEdge,
                         "首尾帧模板的「\(imgNode.title)」节点提示词端口必须有连线")
        }
    }

    func testStartEndTemplateImageGensHaveTextInputs() {
        let def = WorkflowDefinition.startEndFrameToVideo.makeDefinition()
        let imageGenNodes = def.nodes.filter { $0.config.nodeType == .imageGen }
        for imgNode in imageGenNodes {
            let textInputNodes = def.nodes.filter { $0.config.nodeType == .textInput }
            let hasTextInputEdge = def.edges.contains { edge in
                edge.targetNodeId == imgNode.id && textInputNodes.contains { $0.id == edge.sourceNodeId }
            }
            XCTAssertTrue(hasTextInputEdge,
                         "首尾帧模板的「\(imgNode.title)」必须连接到一个文本输入节点")
        }
    }

    func testSampleStillWorks() {
        let def = WorkflowDefinition.sample()
        XCTAssertEqual(def.name, "文生图转视频")
        XCTAssertFalse(def.nodes.isEmpty)
    }

    // MARK: - Template Variable Resolution

    func testPromptTemplateVariablesResolve() {
        for template in WorkflowDefinition.templates {
            let def = template.makeDefinition()
            let promptNodes = def.nodes.filter { $0.config.nodeType == .promptTemplate }
            for node in promptNodes {
                let templateText: String
                if case .promptTemplate(let cfg) = node.config {
                    templateText = cfg.template
                } else { continue }

                let variablePattern = try! NSRegularExpression(pattern: "\\{\\{([^}]+)\\}\\}")
                let matches = variablePattern.matches(in: templateText,
                    range: NSRange(templateText.startIndex..., in: templateText))

                for match in matches {
                    guard let range = Range(match.range(at: 1), in: templateText) else { continue }
                    let varName = String(templateText[range])
                    let hasMatchingPort = node.inputPorts.contains { $0.name == varName }
                    XCTAssertTrue(hasMatchingPort,
                                 "模板「\(template.name)」的 promptTemplate 节点有变量 {{{\(varName)}}} 但没有同名输入端口")
                }
            }
        }
    }

    func testLegacyPortWithoutRoleDecodes() throws {
        let json = """
        {"id":"p1","name":"提示词","portType":"text","nodeId":"n1"}
        """
        let port = try JSONDecoder().decode(WorkflowPort.self, from: Data(json.utf8))
        XCTAssertEqual(port.role, .prompt)
        XCTAssertEqual(port.name, "提示词")
    }

    func testPresetParamsPreserveKind() {
        XCTAssertEqual(PresetParams.gptImage(GptImagePresetParams()).kind, .gptImage)
        XCTAssertEqual(PresetParams.veo(VeoPresetParams()).kind, .veo)
        XCTAssertEqual(PresetKind.banana.displayName, "Banana")
    }

    // MARK: - CredentialStore

    func testCredentialStoreIsDisabledDuringTests() {
        XCTAssertTrue(AppRuntime.isRunningTests)
        XCTAssertTrue(AppRuntime.disablesCredentialStore)
    }

    func testCredentialStoreDoesNotTouchKeychainDuringTests() {
        let credentials = SavedLoginCredentials(username: "test", password: "secret")

        XCTAssertFalse(CredentialStore.save(credentials))
        XCTAssertNil(CredentialStore.load())
        XCTAssertTrue(CredentialStore.delete())
    }

    // MARK: - WorkflowRunPersistence: DTO

    func testWorkflowStepRunRecordText() {
        let step = WorkflowStep(type: .textInput, label: "输入")
        let record = WorkflowStepRunRecord(step: step, status: StepRunStatus.succeeded.rawValue, result: .text("hello world"))
        XCTAssertEqual(record.resultText, "hello world")
        XCTAssertEqual(record.status, "succeeded")
        XCTAssertNil(record.resultImageURLs)
    }

    func testWorkflowStepRunRecordImages() {
        let step = WorkflowStep(type: .imageGen, label: "生图")
        let urls = ["https://a.com/1.png", "https://a.com/2.png"]
        let record = WorkflowStepRunRecord(step: step, status: StepRunStatus.succeeded.rawValue, result: .images(urls))
        XCTAssertEqual(record.resultImageURLs, urls)
        XCTAssertNil(record.resultText)
    }

    func testWorkflowStepRunRecordVideo() {
        let step = WorkflowStep(type: .videoGen, label: "视频")
        let record = WorkflowStepRunRecord(step: step, status: StepRunStatus.succeeded.rawValue, result: .video("https://v.com/out.mp4"))
        XCTAssertEqual(record.resultVideoURL, "https://v.com/out.mp4")
    }

    func testWorkflowStepRunRecordFailed() {
        let step = WorkflowStep(type: .promptTemplate, label: "模板")
        let record = WorkflowStepRunRecord(step: step, status: StepRunStatus.failed.rawValue, error: "模板为空", result: nil)
        XCTAssertEqual(record.errorMessage, "模板为空")
        XCTAssertEqual(record.status, "failed")
    }

    func testWorkflowStepRunRecordAttachAssetPath() {
        let step = WorkflowStep(type: .imageGen, label: "生图")
        var record = WorkflowStepRunRecord(step: step, status: StepRunStatus.succeeded.rawValue)
        record.attachAssetPath("banana.png")
        XCTAssertEqual(record.resultAssetPath, "banana.png")
    }

    func testWorkflowRunRecordCodableRoundTrip() throws {
        let step = WorkflowStep(type: .textInput, label: "输入")
        let stepRecord = WorkflowStepRunRecord(step: step, status: StepRunStatus.succeeded.rawValue, result: .text("测试"))
        let record = WorkflowRunRecord(
            runId: "r1",
            workflowId: "w1",
            workflowName: "测试工作流",
            stepsSnapshot: [step],
            stepRecords: [stepRecord],
            overallStatus: StepRunStatus.succeeded.rawValue,
            startedAt: Date(timeIntervalSinceReferenceDate: 1000),
            completedAt: Date(timeIntervalSinceReferenceDate: 1100)
        )
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(WorkflowRunRecord.self, from: data)
        XCTAssertEqual(decoded.runId, "r1")
        XCTAssertEqual(decoded.workflowName, "测试工作流")
        XCTAssertEqual(decoded.stepRecords.count, 1)
        XCTAssertEqual(decoded.stepRecords[0].resultText, "测试")
    }

    func testWorkflowRunSummaryCodableRoundTrip() throws {
        let now = Date()
        let summary = WorkflowRunSummary(
            runId: "r1", workflowId: "w1", workflowName: "test",
            overallStatus: StepRunStatus.succeeded.rawValue, startedAt: now, completedAt: now,
            stepCount: 3, succeededCount: 2,
            firstError: nil
        )
        let data = try JSONEncoder().encode(summary)
        let decoded = try JSONDecoder().decode(WorkflowRunSummary.self, from: data)
        XCTAssertEqual(decoded.runId, "r1")
        XCTAssertEqual(decoded.stepCount, 3)
        XCTAssertEqual(decoded.succeededCount, 2)
    }

    // MARK: - WorkflowRunPersistence: Directory isolation

    func testWorkflowRunPersistenceUsesTempDirectory() {
        let base = WorkflowRunPersistence.baseDirectory
        XCTAssertEqual(base.path, tempDir.path)
    }

    // MARK: - WorkflowRunPersistence: Index

    func testWorkflowRunPersistenceIndexSaveAndLoad() {
        let runId = UUID().uuidString
        var index = WorkflowRunIndex()
        let summary = WorkflowRunSummary(
            runId: runId, workflowId: "w1", workflowName: "w",
            overallStatus: StepRunStatus.succeeded.rawValue, startedAt: Date(), completedAt: Date(),
            stepCount: 1, succeededCount: 1, firstError: nil
        )
        index.upsert(summary)
        let saved = WorkflowRunPersistence.saveIndex(index)
        XCTAssertTrue(saved)

        let loaded = WorkflowRunPersistence.loadIndex()
        let found = loaded.runs.first { $0.runId == runId }
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.workflowName, "w")
    }

    // MARK: - WorkflowRunPersistence: Run Records

    func testWorkflowRunPersistenceRunSaveAndLoad() {
        let runId = UUID().uuidString
        let step = WorkflowStep(type: .textInput, label: "输入")
        let stepRecord = WorkflowStepRunRecord(step: step, status: StepRunStatus.succeeded.rawValue, result: .text("hello"))
        let record = WorkflowRunRecord(
            runId: runId, workflowId: "w1", workflowName: "test-wf",
            stepsSnapshot: [step], stepRecords: [stepRecord],
            overallStatus: StepRunStatus.succeeded.rawValue, startedAt: Date(), completedAt: Date()
        )
        let saved = WorkflowRunPersistence.saveRun(record)
        XCTAssertTrue(saved)

        let loaded = WorkflowRunPersistence.loadRun(runId: runId)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.runId, runId)
        XCTAssertEqual(loaded?.stepRecords.first?.resultText, "hello")

        WorkflowRunPersistence.deleteRun(runId: runId)
        XCTAssertNil(WorkflowRunPersistence.loadRun(runId: runId))
    }

    func testWorkflowRunPersistenceRejectsNonUUIDRunId() {
        let record = WorkflowRunRecord(
            runId: "../evil", workflowId: "w1", workflowName: "bad",
            stepsSnapshot: [], stepRecords: [],
            overallStatus: StepRunStatus.running.rawValue, startedAt: Date(), completedAt: nil
        )
        let saved = WorkflowRunPersistence.saveRun(record)
        XCTAssertFalse(saved)
    }

    func testWorkflowRunPersistenceLoadRejectsNonUUIDRunId() {
        let loaded = WorkflowRunPersistence.loadRun(runId: "../evil")
        XCTAssertNil(loaded)
    }

    func testWorkflowRunPersistenceDeleteRejectsNonUUIDRunId() {
        WorkflowRunPersistence.deleteRun(runId: "../../malicious")
        // Should not crash or access outside base
    }

    // MARK: - WorkflowRunPersistence: Assets

    func testWorkflowRunPersistenceAssetSaveAndLoad() {
        let runId = UUID().uuidString
        let imageData = Data("fake-png-data".utf8)
        let path = WorkflowRunPersistence.saveAsset(data: imageData, name: "test.png", runId: runId)
        XCTAssertNotNil(path)
        if let path {
            let loaded = WorkflowRunPersistence.loadAsset(runId: runId, fileName: path)
            XCTAssertEqual(loaded, imageData)
        }
        WorkflowRunPersistence.deleteRun(runId: runId)
    }

    func testWorkflowRunPersistenceAssetRejectsPathTraversalName() {
        let runId = UUID().uuidString
        let path = WorkflowRunPersistence.saveAsset(data: Data(), name: "../evil.png", runId: runId)
        XCTAssertNil(path)
    }

    func testWorkflowRunPersistenceAssetRejectsSlashInName() {
        let runId = UUID().uuidString
        let path = WorkflowRunPersistence.saveAsset(data: Data(), name: "sub/evil.png", runId: runId)
        XCTAssertNil(path)
    }

    func testWorkflowRunPersistenceAssetRejectsEmptyName() {
        let runId = UUID().uuidString
        let path = WorkflowRunPersistence.saveAsset(data: Data(), name: "", runId: runId)
        XCTAssertNil(path)
    }

    // MARK: - WorkflowRunPersistence: Cleanup

    func testWorkflowRunPersistenceDeleteRunsForWorkflow() {
        let wfId = UUID().uuidString
        let runId1 = UUID().uuidString
        let runId2 = UUID().uuidString

        var index = WorkflowRunPersistence.loadIndex()
        let s1 = WorkflowRunSummary(
            runId: runId1, workflowId: wfId, workflowName: "wf",
            overallStatus: StepRunStatus.succeeded.rawValue, startedAt: Date(), completedAt: Date(),
            stepCount: 1, succeededCount: 1, firstError: nil
        )
        let s2 = WorkflowRunSummary(
            runId: runId2, workflowId: "other", workflowName: "other",
            overallStatus: StepRunStatus.succeeded.rawValue, startedAt: Date(), completedAt: Date(),
            stepCount: 1, succeededCount: 1, firstError: nil
        )
        index.upsert(s1)
        index.upsert(s2)
        WorkflowRunPersistence.saveIndex(index)

        let record = WorkflowRunRecord(
            runId: runId1, workflowId: wfId, workflowName: "wf",
            stepsSnapshot: [], stepRecords: [],
            overallStatus: StepRunStatus.succeeded.rawValue, startedAt: Date(), completedAt: Date()
        )
        WorkflowRunPersistence.saveRun(record)

        WorkflowRunPersistence.deleteRuns(for: wfId)

        let after = WorkflowRunPersistence.loadIndex()
        XCTAssertNil(after.runs.first(where: { $0.runId == runId1 }))
        XCTAssertNotNil(after.runs.first(where: { $0.runId == runId2 }))
        XCTAssertNil(WorkflowRunPersistence.loadRun(runId: runId1))
    }

    func testWorkflowRunPersistenceDeleteRunsFindsOrphanByScan() {
        let wfId = UUID().uuidString
        let runId = UUID().uuidString

        let record = WorkflowRunRecord(
            runId: runId, workflowId: wfId, workflowName: "orphan-wf",
            stepsSnapshot: [], stepRecords: [],
            overallStatus: StepRunStatus.succeeded.rawValue, startedAt: Date(), completedAt: Date()
        )
        WorkflowRunPersistence.saveRun(record)
        // Don't add to index — simulate index loss
        XCTAssertNil(WorkflowRunPersistence.loadIndex().runs.first(where: { $0.runId == runId }))

        WorkflowRunPersistence.deleteRuns(for: wfId)
        XCTAssertNil(WorkflowRunPersistence.loadRun(runId: runId))
    }

    func testWorkflowRunPersistencePruneEvictedRuns() {
        let runId = UUID().uuidString
        let record = WorkflowRunRecord(
            runId: runId, workflowId: "w1", workflowName: "w",
            stepsSnapshot: [], stepRecords: [],
            overallStatus: StepRunStatus.succeeded.rawValue, startedAt: Date(), completedAt: Date()
        )
        WorkflowRunPersistence.saveRun(record)

        let summary = WorkflowRunSummary(
            runId: runId, workflowId: "w1", workflowName: "w",
            overallStatus: StepRunStatus.succeeded.rawValue, startedAt: Date(), completedAt: Date(),
            stepCount: 1, succeededCount: 1, firstError: nil
        )
        WorkflowRunPersistence.pruneEvictedRuns([summary])

        XCTAssertNil(WorkflowRunPersistence.loadRun(runId: runId))
    }

    // MARK: - WorkflowRunIndex

    func testWorkflowRunIndexMaxEntries() {
        var index = WorkflowRunIndex()
        var lastEvicted = 0
        for i in 0..<150 {
            let summary = WorkflowRunSummary(
                runId: "r\(i)", workflowId: "w", workflowName: "w",
                overallStatus: StepRunStatus.succeeded.rawValue, startedAt: Date(), completedAt: Date(),
                stepCount: 1, succeededCount: 1, firstError: nil
            )
            let evicted = index.upsert(summary)
            if !evicted.isEmpty { lastEvicted = evicted.count }
        }
        XCTAssertLessThanOrEqual(index.runs.count, 100)
        XCTAssertEqual(index.runs.first?.runId, "r149")
        XCTAssertGreaterThan(lastEvicted, 0)
    }

    func testWorkflowRunIndexRemoveForWorkflow() {
        var index = WorkflowRunIndex()
        let s1 = WorkflowRunSummary(
            runId: "r1", workflowId: "w1", workflowName: "w1",
            overallStatus: StepRunStatus.succeeded.rawValue, startedAt: Date(), completedAt: Date(),
            stepCount: 1, succeededCount: 1, firstError: nil
        )
        let s2 = WorkflowRunSummary(
            runId: "r2", workflowId: "w2", workflowName: "w2",
            overallStatus: StepRunStatus.succeeded.rawValue, startedAt: Date(), completedAt: Date(),
            stepCount: 1, succeededCount: 1, firstError: nil
        )
        index.upsert(s1)
        index.upsert(s2)
        XCTAssertEqual(index.runs.count, 2)

        index.removeRuns(for: "w1")
        XCTAssertEqual(index.runs.count, 1)
        XCTAssertEqual(index.runs.first?.runId, "r2")
    }

    func testWorkflowRunIndexSupportsFirstError() {
        let summary = WorkflowRunSummary(
            runId: "r1", workflowId: "w1", workflowName: "w",
            overallStatus: StepRunStatus.failed.rawValue, startedAt: Date(), completedAt: Date(),
            stepCount: 3, succeededCount: 2,
            firstError: "提示词不能为空"
        )
        let data = try! JSONEncoder().encode(summary)
        let decoded = try! JSONDecoder().decode(WorkflowRunSummary.self, from: data)
        XCTAssertEqual(decoded.firstError, "提示词不能为空")
        XCTAssertEqual(decoded.overallStatus, "failed")
    }

    // MARK: - StepRunStatus

    func testStepRunStatusCodableRoundTrip() throws {
        let status = StepRunStatus.succeeded
        let data = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(StepRunStatus.self, from: data)
        XCTAssertEqual(decoded, .succeeded)
        XCTAssertEqual(decoded.rawValue, "succeeded")
    }

    func testStepRunStatusDisplayNameUnchanged() {
        XCTAssertEqual(StepRunStatus.pending.displayName, "等待中")
        XCTAssertEqual(StepRunStatus.running.displayName, "执行中")
        XCTAssertEqual(StepRunStatus.succeeded.displayName, "已完成")
        XCTAssertEqual(StepRunStatus.failed.displayName, "失败")
        XCTAssertEqual(StepRunStatus.cancelled.displayName, "已取消")
    }

    func testStepRunStatusRawValuesAreStable() {
        XCTAssertEqual(StepRunStatus.pending.rawValue, "pending")
        XCTAssertEqual(StepRunStatus.succeeded.rawValue, "succeeded")
        XCTAssertEqual(StepRunStatus.failed.rawValue, "failed")
        XCTAssertEqual(StepRunStatus.cancelled.rawValue, "cancelled")
    }

    // MARK: - QueueItemSnapshot backward compatibility

    func testQueueItemSnapshotDecodesWithoutNewFields() throws {
        let json = """
        {
            "id": "test-123",
            "kind": "gptImage",
            "status": "polling",
            "taskId": "task-abc",
            "resultUrls": [],
            "createdAt": 1000,
            "retryCount": 0,
            "summaryText": "a cat",
            "consecutivePollFailures": 0,
            "hasFileData": false
        }
        """
        let data = Data(json.utf8)
        let snapshot = try JSONDecoder().decode(QueueItemSnapshot.self, from: data)
        XCTAssertEqual(snapshot.id, "test-123")
        XCTAssertEqual(snapshot.status, .polling)
        XCTAssertEqual(snapshot.taskId, "task-abc")
        XCTAssertNil(snapshot.pollDetail)
        XCTAssertTrue(snapshot.statusHistory.isEmpty)
    }

    func testQueueItemSnapshotDecodesWithNewFields() throws {
        let now = Date()
        let event = StatusEvent(status: "供应商生成中", timestamp: now)
        let snapshot = QueueItemSnapshot(
            id: "s1", kind: .veo, status: .polling, taskId: "t1",
            createdAt: Date(), summaryText: "test", pollDetail: "供应商生成中",
            statusHistory: [event]
        )
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(QueueItemSnapshot.self, from: data)
        XCTAssertEqual(decoded.pollDetail, "供应商生成中")
        XCTAssertEqual(decoded.statusHistory.count, 1)
        XCTAssertEqual(decoded.statusHistory.first?.status, "供应商生成中")
    }

    // MARK: - Poll result URL compatibility

    func testTaskPollResponseAcceptsSingularImageUrl() throws {
        let json = """
        {
            "success": true,
            "dbStatus": "SUCCESS",
            "imageUrl": "https://example.com/result.png"
        }
        """
        let response = try JSONDecoder().decode(TaskPollResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.imageResultUrls, ["https://example.com/result.png"])
    }

    func testTaskPollResponseAcceptsResultUrlForVideo() throws {
        let json = """
        {
            "success": true,
            "status": "SUCCESS",
            "resultUrl": "https://example.com/result.mp4"
        }
        """
        let response = try JSONDecoder().decode(TaskPollResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.videoResultUrl, "https://example.com/result.mp4")
    }

    func testTaskPollResponseAcceptsSnakeCaseVideoUrl() throws {
        let json = """
        {
            "status": "SUCCESS",
            "video_url": "https://example.com/video.mp4"
        }
        """
        let response = try JSONDecoder().decode(TaskPollResponse.self, from: Data(json.utf8))
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.videoResultUrl, "https://example.com/video.mp4")
    }

    func testTaskPollResponseAcceptsStringResultUrls() throws {
        let json = """
        {
            "success": true,
            "dbStatus": "SUCCESS",
            "resultUrls": "https://example.com/single.png"
        }
        """
        let response = try JSONDecoder().decode(TaskPollResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.imageResultUrls, ["https://example.com/single.png"])
    }

    func testTaskPollResponseExtractsResultDataJsonUrls() throws {
        let json = """
        {
            "success": true,
            "dbStatus": "SUCCESS",
            "resultData": "{\\"result_urls\\":[\\"https://example.com/a.png\\",\\"https://example.com/b.png\\"]}"
        }
        """
        let response = try JSONDecoder().decode(TaskPollResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.imageResultUrls, ["https://example.com/a.png", "https://example.com/b.png"])
    }

    func testTaskPollResponseExtractsNestedResultUrl() throws {
        let json = """
        {
            "success": true,
            "status": "SUCCESS",
            "result": {
                "download_url": "https://example.com/nested.mp4"
            }
        }
        """
        let response = try JSONDecoder().decode(TaskPollResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.videoResultUrl, "https://example.com/nested.mp4")
    }

    func testTaskPollResponseDoesNotTreatNestedImageUrlAsVideo() throws {
        let json = """
        {
            "success": true,
            "status": "SUCCESS",
            "result": {
                "image_url": "https://example.com/thumbnail.png"
            }
        }
        """
        let response = try JSONDecoder().decode(TaskPollResponse.self, from: Data(json.utf8))
        XCTAssertNil(response.videoResultUrl)
        XCTAssertEqual(response.imageResultUrls, ["https://example.com/thumbnail.png"])
    }

    func testTaskPollResponseExtractsBase64ImageData() throws {
        let pngBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC"
        let json = """
        {
            "success": true,
            "dbStatus": "SUCCESS",
            "resultData": "\(pngBase64)"
        }
        """
        let response = try JSONDecoder().decode(TaskPollResponse.self, from: Data(json.utf8))
        let expected = Data(base64Encoded: pngBase64)!
        XCTAssertNotNil(response.imageResultData)
        XCTAssertEqual(response.imageResultData, expected)
    }

    // MARK: - Vendor status mapping

    func testTaskPollResponseTerminalStatusRecognition() {
        let completed = TaskPollResponse(
            success: true, dbStatus: nil, rhStatus: nil, status: " completed ",
            taskStatus: nil, resultUrls: nil, videoUrl: nil,
            outputUrl: nil, resultData: nil, errorMessage: nil,
            detailMessage: nil, ourTaskId: nil, rhTaskId: nil, message: nil
        )
        XCTAssertTrue(completed.isTerminal(for: .wan))
        XCTAssertTrue(completed.isTerminalSuccess(for: .wan))

        let canceled = TaskPollResponse(
            success: true, dbStatus: nil, rhStatus: nil, status: "canceled",
            taskStatus: nil, resultUrls: nil, videoUrl: nil,
            outputUrl: nil, resultData: nil, errorMessage: nil,
            detailMessage: nil, ourTaskId: nil, rhTaskId: nil, message: nil
        )
        XCTAssertTrue(canceled.isTerminal(for: .grok))
        XCTAssertTrue(canceled.isTerminalFailure(for: .grok))
    }

    func testTaskPollResponseStatusPriorityUsesAuthoritativeFieldFirst() {
        let result = TaskPollResponse(
            success: true, dbStatus: "PROCESSING", rhStatus: nil,
            status: "SUCCESS", taskStatus: nil, resultUrls: nil,
            videoUrl: nil, outputUrl: nil, resultData: nil, errorMessage: nil,
            detailMessage: nil, ourTaskId: nil, rhTaskId: nil, message: nil
        )
        XCTAssertEqual(result.normalizedStatus(for: .image), "PROCESSING")
        XCTAssertFalse(result.isTerminal(for: .image))
    }

    func testVendorStatusMappingRecognized() {
        let cases: [(String?, String?, String?, String)] = [
            ("PROCESSING", nil, nil, "供应商生成中"),
            (nil, "QUEUED", nil, "供应商排队中"),
            (nil, nil, "FETCHING", "取回结果中"),
            ("UPLOADING", nil, nil, "结果上传中"),
            (nil, "POST_PROCESSING", nil, "后处理中"),
        ]
        for (rh, db, task, expected) in cases {
            let result = TaskPollResponse(
                success: true, dbStatus: db, rhStatus: rh, status: nil,
                taskStatus: task, resultUrls: nil, videoUrl: nil,
                outputUrl: nil, resultData: nil, errorMessage: nil,
                detailMessage: nil, ourTaskId: nil, rhTaskId: nil, message: nil
            )
            let mapped = GenerationTaskExecutor.testMapIntermediateStatus(result)
            XCTAssertEqual(mapped, expected, "rh=\(rh ?? "nil") db=\(db ?? "nil") task=\(task ?? "nil")")
        }
    }

    func testVendorStatusMappingFallsThroughUnrecognizedRh() {
        let result = TaskPollResponse(
            success: true, dbStatus: "PROCESSING", rhStatus: "IN_RENDER_QUEUE",
            status: nil, taskStatus: nil, resultUrls: nil, videoUrl: nil,
            outputUrl: nil, resultData: nil, errorMessage: nil,
            detailMessage: nil, ourTaskId: nil, rhTaskId: nil, message: nil
        )
        let mapped = GenerationTaskExecutor.testMapIntermediateStatus(result)
        XCTAssertEqual(mapped, "供应商生成中")
    }

    func testVendorStatusMappingFallsThroughAcrossFields() {
        let result = TaskPollResponse(
            success: true, dbStatus: "UNKNOWN_VENDOR_STATE", rhStatus: nil,
            status: "QUEUED", taskStatus: "PROCESSING", resultUrls: nil,
            videoUrl: nil, outputUrl: nil, resultData: nil, errorMessage: nil,
            detailMessage: nil, ourTaskId: nil, rhTaskId: nil, message: nil
        )
        let mapped = GenerationTaskExecutor.testMapIntermediateStatus(result)
        XCTAssertEqual(mapped, "供应商排队中")
    }

    func testVendorStatusMappingReturnsNilWhenAllEmpty() {
        let result = TaskPollResponse(
            success: true, dbStatus: nil, rhStatus: nil, status: nil,
            taskStatus: nil, resultUrls: nil, videoUrl: nil,
            outputUrl: nil, resultData: nil, errorMessage: nil,
            detailMessage: nil, ourTaskId: nil, rhTaskId: nil, message: nil
        )
        let mapped = GenerationTaskExecutor.testMapIntermediateStatus(result)
        XCTAssertNil(mapped)
    }

    // MARK: - VeoRules

    func testVeoFixedDurationBudgetNonReference() {
        // 低价渠道 + 非 reference/extend 模式 => 固定 8s
        XCTAssertEqual(VeoRules.fixedDuration(channel: "budget", model: "fast", mode: "text"), "8")
        XCTAssertEqual(VeoRules.fixedDuration(channel: "budget", model: "fast", mode: "image"), "8")
        XCTAssertEqual(VeoRules.fixedDuration(channel: "budget", model: "fast", mode: "start_end"), "8")
    }

    func testVeoFixedDurationBudgetReferenceOrExtend() {
        // 低价渠道 + reference/extend 模式 => 无固定时长
        XCTAssertNil(VeoRules.fixedDuration(channel: "budget", model: "fast", mode: "reference"))
        XCTAssertNil(VeoRules.fixedDuration(channel: "budget", model: "fast", mode: "extend"))
    }

    func testVeoFixedDurationOfficial() {
        // 官方渠道 => 无固定时长
        XCTAssertNil(VeoRules.fixedDuration(channel: "official", model: "fast", mode: "text"))
        XCTAssertNil(VeoRules.fixedDuration(channel: "official", model: "standard", mode: "image"))
    }

    func testVeoSupportsDuration() {
        // 官方 fast text 支持时长
        XCTAssertTrue(VeoRules.supportsDuration(channel: "official", model: "fast", mode: "text"))
        XCTAssertFalse(VeoRules.supportsDuration(channel: "yunwu", model: "veo_3_1", mode: "text"))
        // 低价渠道不支持（固定时长，不可调整）
        XCTAssertFalse(VeoRules.supportsDuration(channel: "budget", model: "fast", mode: "text"))
        // reference/extend 模式不支持
        XCTAssertFalse(VeoRules.supportsDuration(channel: "official", model: "fast", mode: "reference"))
        XCTAssertFalse(VeoRules.supportsDuration(channel: "official", model: "fast", mode: "extend"))
        // lite + start_end 不支持
        XCTAssertFalse(VeoRules.supportsDuration(channel: "official", model: "lite", mode: "start_end"))
    }

    func testVeoSupportsAspectRatio() {
        // text、image、start_end 模式支持画幅
        XCTAssertTrue(VeoRules.supportsAspectRatio(mode: "text"))
        XCTAssertTrue(VeoRules.supportsAspectRatio(mode: "image"))
        XCTAssertTrue(VeoRules.supportsAspectRatio(mode: "start_end"))
        // reference/extend 不支持
        XCTAssertFalse(VeoRules.supportsAspectRatio(mode: "reference"))
        XCTAssertFalse(VeoRules.supportsAspectRatio(mode: "extend"))
    }
}
