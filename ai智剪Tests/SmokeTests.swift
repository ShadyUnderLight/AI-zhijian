import XCTest

final class SmokeTests: XCTestCase {

    // MARK: - WorkflowValue

    func testWorkflowValueTextSummary() {
        let v = WorkflowValue.text("hello")
        XCTAssertEqual(v.summary, "hello")
        XCTAssertEqual(v.textValue, "hello")
        XCTAssertEqual(v.portType, .text)
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
}
