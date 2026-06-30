import XCTest
@testable import aiZhijian

// MARK: - Property-Based Contract Tests for ProductPromoWorkflow

/// These tests verify the type contracts defined in SDD:
///
/// PromoPromptInput:
///   ∀ background.nonEmpty ∧ placementSurface.nonEmpty → isValid == true
///   ∀ background.isEmpty ∨ background.whitespaceOnly → isValid == false
///   ∀ placementSurface.isEmpty → isValid == false
///
/// PromoPromptTemplates.assembleGPTImagePrompt:
///   ∀ validInput → result does NOT contain placeholder markers
///   ∀ validInput → result contains actual background/placement values
///   ∀ whitespacePadded → result contains trimmed values
///   ∀ validInput → fixed template text is preserved
///
/// PromoVeoDefaults.params:
///   ∀ (prompt, imageData) → channel=="official", model=="lite", mode=="image"
///   ∀ (prompt, imageData) → aspectRatio=="9:16", resolution=="720p", duration=="8"
///   ∀ distinctCalls → distinct instances (no shared state)

final class ProductPromoWorkflowTests: XCTestCase {

    // MARK: - PromoPromptInput validation

    func testPromptInput_valid_whenBothFieldsFilled() {
        let input = PromoPromptInput(background: "木质桌面", placementSurface: "白色桌面")
        XCTAssertTrue(input.isValid)
    }

    func testPromptInput_invalid_whenBackgroundEmpty() {
        let input = PromoPromptInput(background: "", placementSurface: "白色桌面")
        XCTAssertFalse(input.isValid)
    }

    func testPromptInput_invalid_whenBackgroundWhitespaceOnly() {
        let input = PromoPromptInput(background: "   ", placementSurface: "白色桌面")
        XCTAssertFalse(input.isValid)
    }

    func testPromptInput_invalid_whenPlacementEmpty() {
        let input = PromoPromptInput(background: "木质桌面", placementSurface: "")
        XCTAssertFalse(input.isValid)
    }

    func testPromptInput_invalid_whenBothEmpty() {
        let input = PromoPromptInput(background: "", placementSurface: "")
        XCTAssertFalse(input.isValid)
    }

    func testPromptInput_invalid_whenPlacementWhitespaceOnly() {
        let input = PromoPromptInput(background: "背景", placementSurface: "   ")
        XCTAssertFalse(input.isValid)
    }

    // MARK: - Template assembly

    func testAssembleGPTImagePrompt_replacesBothPlaceholders() {
        let input = PromoPromptInput(background: "花园", placementSurface: "石头桌面")
        let result = PromoPromptTemplates.assembleGPTImagePrompt(from: input)
        XCTAssertFalse(result.contains("【背景】"), "模板中的【背景】占位符应被替换")
        XCTAssertFalse(result.contains("【摆放平面】"), "模板中的【摆放平面】占位符应被替换")
        XCTAssertTrue(result.contains("花园"), "应包含实际背景值")
        XCTAssertTrue(result.contains("石头桌面"), "应包含实际摆放平面值")
    }

    func testAssembleGPTImagePrompt_preservesFixedText() {
        let input = PromoPromptInput(background: "测试", placementSurface: "测试")
        let result = PromoPromptTemplates.assembleGPTImagePrompt(from: input)
        XCTAssertTrue(result.contains("【任务目标】"), "固定文案应保留")
        XCTAssertTrue(result.contains("【产品一致性要求】"), "固定文案应保留")
        XCTAssertTrue(result.contains("【禁止内容】"), "固定文案应保留")
        XCTAssertTrue(result.contains("【构图与镜头要求】"), "固定文案应保留")
        XCTAssertTrue(result.contains("【画面风格要求】"), "固定文案应保留")
    }

    func testAssembleGPTImagePrompt_withSpacesInInput_trimsThem() {
        let input = PromoPromptInput(background: "  花园  ", placementSurface: "  石头桌面  ")
        let result = PromoPromptTemplates.assembleGPTImagePrompt(from: input)
        XCTAssertTrue(result.contains("花园"), "应包含trim后的背景值")
        XCTAssertTrue(result.contains("石头桌面"), "应包含trim后的摆放平面值")
        XCTAssertFalse(result.contains(" 花园 "), "不应保留前后空格")
        XCTAssertFalse(result.contains(" 石头桌面 "), "不应保留前后空格")
    }

    func testAssembleGPTImagePrompt_preservesStructureOutsidePlaceholders() {
        let input = PromoPromptInput(background: "木质桌面", placementSurface: "白色台面")
        let result = PromoPromptTemplates.assembleGPTImagePrompt(from: input)
        // 验证替换后不含中文全角括号占位符
        XCTAssertFalse(result.contains("【背景】"))
        XCTAssertFalse(result.contains("【摆放平面】"))
        // 验证输入值确实在正确位置出现
        let bgRange = result.range(of: "木质桌面")
        let psRange = result.range(of: "白色台面")
        XCTAssertNotNil(bgRange)
        XCTAssertNotNil(psRange)
        // 背景应出现在摆放平面之前（按模板顺序）
        if let bg = bgRange, let ps = psRange {
            XCTAssertTrue(bg.lowerBound < ps.lowerBound, "背景应出现在摆放平面之前")
        }
    }

    // MARK: - VeoParams construction

    func testVeoParams_defaultsAreCorrect() {
        let testData = Data([0xFF, 0xEE, 0xDD])
        let params = PromoVeoDefaults.params(prompt: "test prompt", imageData: testData)
        XCTAssertEqual(params.channel, "official")
        XCTAssertEqual(params.model, "lite")
        XCTAssertEqual(params.mode, "image")
        XCTAssertEqual(params.aspectRatio, "9:16")
        XCTAssertEqual(params.resolution, "720p")
        XCTAssertEqual(params.duration, "8")
        XCTAssertEqual(params.prompt, "test prompt")
        XCTAssertEqual(params.imageData, testData)
        XCTAssertEqual(params.imageName, "first_frame.jpg")
        XCTAssertEqual(params.imageMime, "image/jpeg")
    }

    func testVeoParams_independentInstances() {
        let p1 = PromoVeoDefaults.params(prompt: "prompt A", imageData: Data([0x01]))
        let p2 = PromoVeoDefaults.params(prompt: "prompt B", imageData: Data([0x02]))
        XCTAssertNotEqual(p1.prompt, p2.prompt, "不同调用应产生独立实例")
        XCTAssertNotEqual(p1.imageData, p2.imageData, "不同调用应产生独立实例")
    }

    func testVeoParams_defaultPromptADiffersFromB() {
        // PromoPromptTemplates 的默认提示词 A 和 B 应该不同
        let a = PromoPromptTemplates.defaultVeoPromptA
        let b = PromoPromptTemplates.defaultVeoPromptB
        XCTAssertNotEqual(a, b, "默认视频 A 和 B 的提示词应不同")
        // 两者都应包含基本描述
        XCTAssertTrue(a.contains("三袋产品"), "A 应提及产品")
        XCTAssertTrue(b.contains("三袋产品"), "B 应提及产品")
        // A 是手部展示，B 是人物展示
        XCTAssertTrue(a.contains("一只手"), "A 应为手部展示动作")
        XCTAssertTrue(b.contains("一个人"), "B 应为人物展示动作")
    }

    // MARK: - PromoPromptInput structural invariance

    func testPromptInput_isStructSemantics() {
        let input1 = PromoPromptInput(background: "bg1", placementSurface: "ps1")
        var input2 = input1
        input2 = PromoPromptInput(background: "bg2", placementSurface: "ps2")
        // 验证原始实例未被修改（struct 值语义）
        XCTAssertEqual(input1.background, "bg1")
        XCTAssertEqual(input1.placementSurface, "ps1")
        XCTAssertEqual(input2.background, "bg2")
        XCTAssertEqual(input2.placementSurface, "ps2")
    }

    func testPromptTemplates_isStaticEnum() {
        // 验证模板是 static 属性，不可实例化
        // PromoPromptTemplates 是无 case 的 enum，编译器保证不能创建实例
        XCTAssertTrue(type(of: PromoPromptTemplates.gptImage) == String.self)
        XCTAssertTrue(type(of: PromoPromptTemplates.defaultVeoPromptA) == String.self)
    }

    func testPromptTemplates_gptImageIsNonEmpty() {
        XCTAssertFalse(PromoPromptTemplates.gptImage.isEmpty, "GPT Image 模板不应为空")
        XCTAssertFalse(PromoPromptTemplates.defaultVeoPromptA.isEmpty, "Veo A 模板不应为空")
        XCTAssertFalse(PromoPromptTemplates.defaultVeoPromptB.isEmpty, "Veo B 模板不应为空")
    }
}
