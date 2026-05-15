import XCTest
@testable import aiZhijian

final class SmokeTests: XCTestCase {

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
        var bogusPort = WorkflowPort(name: "fake", portType: .text, nodeId: "nonexistent")
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
        XCTAssertFalse(VeoRules.isValidCombination(channel: "budget", model: "lite"))

        XCTAssertEqual(VeoRules.fixedDuration(channel: "budget", model: "fast", mode: "text"), "8")
        XCTAssertFalse(VeoRules.supportsDuration(channel: "budget", model: "fast", mode: "text"))
        XCTAssertTrue(VeoRules.shouldSendDurationValue(channel: "budget", model: "fast", mode: "text"))
    }

    // MARK: - WorkflowConfigs

    func testWorkflowConfigsValidateExpectedDefaults() {
        XCTAssertTrue(TextInputNodeConfig(text: "hello").validate().isEmpty)
        XCTAssertEqual(TextInputNodeConfig(text: "   ").validate(), [.invalidConfig("文本输入不能为空")])

        var video = VideoGenNodeConfig()
        XCTAssertTrue(video.validate().isEmpty)

        video.model = "lite"
        XCTAssertTrue(video.validate().contains(.invalidConfig("Veo 不支持模型 lite，可用: fast, pro")))
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

    func testPresetParamsPreserveKind() {
        XCTAssertEqual(PresetParams.gptImage(GptImagePresetParams()).kind, .gptImage)
        XCTAssertEqual(PresetParams.veo(VeoPresetParams()).kind, .veo)
        XCTAssertEqual(PresetKind.banana.displayName, "Banana")
    }

    // MARK: - WorkflowRunPersistence

    func testWorkflowStepRunRecordText() {
        let step = WorkflowStep(type: .textInput, label: "输入")
        let record = WorkflowStepRunRecord(step: step, status: "已完成", result: .text("hello world"))
        XCTAssertEqual(record.resultText, "hello world")
        XCTAssertEqual(record.status, "已完成")
        XCTAssertNil(record.resultImageURLs)
    }

    func testWorkflowStepRunRecordImages() {
        let step = WorkflowStep(type: .imageGen, label: "生图")
        let urls = ["https://a.com/1.png", "https://a.com/2.png"]
        let record = WorkflowStepRunRecord(step: step, status: "已完成", result: .images(urls))
        XCTAssertEqual(record.resultImageURLs, urls)
        XCTAssertNil(record.resultText)
    }

    func testWorkflowStepRunRecordVideo() {
        let step = WorkflowStep(type: .videoGen, label: "视频")
        let record = WorkflowStepRunRecord(step: step, status: "已完成", result: .video("https://v.com/out.mp4"))
        XCTAssertEqual(record.resultVideoURL, "https://v.com/out.mp4")
    }

    func testWorkflowStepRunRecordFailed() {
        let step = WorkflowStep(type: .promptTemplate, label: "模板")
        let record = WorkflowStepRunRecord(step: step, status: "失败", error: "模板为空", result: nil)
        XCTAssertEqual(record.errorMessage, "模板为空")
        XCTAssertEqual(record.status, "失败")
    }

    func testWorkflowStepRunRecordAttachAssetPath() {
        let step = WorkflowStep(type: .imageGen, label: "生图")
        var record = WorkflowStepRunRecord(step: step, status: "已完成")
        record.attachAssetPath("banana.png")
        XCTAssertEqual(record.resultAssetPath, "banana.png")
    }

    func testWorkflowRunRecordCodableRoundTrip() throws {
        let step = WorkflowStep(type: .textInput, label: "输入")
        let stepRecord = WorkflowStepRunRecord(step: step, status: "已完成", result: .text("测试"))
        let record = WorkflowRunRecord(
            runId: "r1",
            workflowId: "w1",
            workflowName: "测试工作流",
            stepsSnapshot: [step],
            stepRecords: [stepRecord],
            overallStatus: "已完成",
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
            overallStatus: "已完成", startedAt: now, completedAt: now,
            stepCount: 3, succeededCount: 2,
            firstError: nil
        )
        let data = try JSONEncoder().encode(summary)
        let decoded = try JSONDecoder().decode(WorkflowRunSummary.self, from: data)
        XCTAssertEqual(decoded.runId, "r1")
        XCTAssertEqual(decoded.stepCount, 3)
        XCTAssertEqual(decoded.succeededCount, 2)
    }

    func testWorkflowRunPersistenceDirectoryExists() {
        let base = WorkflowRunPersistence.baseDirectory
        XCTAssertTrue(base.path.contains("Application Support"))
        XCTAssertTrue(base.path.contains("AI 智剪/WorkflowRuns"))
    }

    func testWorkflowRunPersistenceIndexSaveAndLoad() {
        let runId = "test-index-\(UUID().uuidString)"
        var index = WorkflowRunIndex()
        let summary = WorkflowRunSummary(
            runId: runId, workflowId: "w1", workflowName: "w",
            overallStatus: "已完成", startedAt: Date(), completedAt: Date(),
            stepCount: 1, succeededCount: 1, firstError: nil
        )
        index.upsert(summary)
        WorkflowRunPersistence.saveIndex(index)

        let loaded = WorkflowRunPersistence.loadIndex()
        let found = loaded.runs.first { $0.runId == runId }
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.workflowName, "w")

        var cleaned = loaded
        cleaned.removeRun(runId)
        WorkflowRunPersistence.saveIndex(cleaned)
    }

    func testWorkflowRunPersistenceRunSaveAndLoad() {
        let runId = "test-run-\(UUID().uuidString)"
        let step = WorkflowStep(type: .textInput, label: "输入")
        let stepRecord = WorkflowStepRunRecord(step: step, status: "已完成", result: .text("hello"))
        let record = WorkflowRunRecord(
            runId: runId, workflowId: "w1", workflowName: "test-wf",
            stepsSnapshot: [step], stepRecords: [stepRecord],
            overallStatus: "已完成", startedAt: Date(), completedAt: Date()
        )
        WorkflowRunPersistence.saveRun(record)

        let loaded = WorkflowRunPersistence.loadRun(runId: runId)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.runId, runId)
        XCTAssertEqual(loaded?.stepRecords.first?.resultText, "hello")

        WorkflowRunPersistence.deleteRun(runId: runId)
        XCTAssertNil(WorkflowRunPersistence.loadRun(runId: runId))
    }

    func testWorkflowRunPersistenceAssetSaveAndLoad() {
        let runId = "test-asset-\(UUID().uuidString)"
        let imageData = Data("fake-png-data".utf8)
        let path = WorkflowRunPersistence.saveAsset(data: imageData, name: "test.png", runId: runId)
        XCTAssertNotNil(path)
        if let path {
            let loaded = WorkflowRunPersistence.loadAsset(runId: runId, fileName: path)
            XCTAssertEqual(loaded, imageData)
        }
        WorkflowRunPersistence.deleteRun(runId: runId)
    }

    func testWorkflowRunPersistenceDeleteRunsForWorkflow() {
        let wfId = "test-wf-cleanup-\(UUID().uuidString)"
        let runId = "test-run-cleanup-\(UUID().uuidString)"

        var index = WorkflowRunPersistence.loadIndex()
        let summary = WorkflowRunSummary(
            runId: runId, workflowId: wfId, workflowName: "will-delete",
            overallStatus: "已完成", startedAt: Date(), completedAt: Date(),
            stepCount: 1, succeededCount: 1, firstError: nil
        )
        index.upsert(summary)
        WorkflowRunPersistence.saveIndex(index)

        let record = WorkflowRunRecord(
            runId: runId, workflowId: wfId, workflowName: "will-delete",
            stepsSnapshot: [], stepRecords: [],
            overallStatus: "已完成", startedAt: Date(), completedAt: Date()
        )
        WorkflowRunPersistence.saveRun(record)

        WorkflowRunPersistence.deleteRuns(for: wfId)

        let after = WorkflowRunPersistence.loadIndex()
        XCTAssertNil(after.runs.first(where: { $0.runId == runId }))
        XCTAssertNil(WorkflowRunPersistence.loadRun(runId: runId))
    }

    func testWorkflowRunIndexMaxEntries() {
        var index = WorkflowRunIndex()
        for i in 0..<150 {
            let summary = WorkflowRunSummary(
                runId: "r\(i)", workflowId: "w", workflowName: "w",
                overallStatus: "已完成", startedAt: Date(), completedAt: Date(),
                stepCount: 1, succeededCount: 1, firstError: nil
            )
            index.upsert(summary)
        }
        XCTAssertLessThanOrEqual(index.runs.count, 100)
        XCTAssertEqual(index.runs.first?.runId, "r149")
    }

    func testWorkflowRunIndexRemoveForWorkflow() {
        var index = WorkflowRunIndex()
        let s1 = WorkflowRunSummary(
            runId: "r1", workflowId: "w1", workflowName: "w1",
            overallStatus: "已完成", startedAt: Date(), completedAt: Date(),
            stepCount: 1, succeededCount: 1, firstError: nil
        )
        let s2 = WorkflowRunSummary(
            runId: "r2", workflowId: "w2", workflowName: "w2",
            overallStatus: "已完成", startedAt: Date(), completedAt: Date(),
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
            overallStatus: "失败", startedAt: Date(), completedAt: Date(),
            stepCount: 3, succeededCount: 2,
            firstError: "提示词不能为空"
        )
        let data = try! JSONEncoder().encode(summary)
        let decoded = try! JSONDecoder().decode(WorkflowRunSummary.self, from: data)
        XCTAssertEqual(decoded.firstError, "提示词不能为空")
        XCTAssertEqual(decoded.overallStatus, "失败")
    }
}
