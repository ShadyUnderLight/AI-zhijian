import XCTest
@testable import aiZhijian

@MainActor
final class PreflightServiceTests: XCTestCase {

    // MARK: - PreflightResponse Decoding

    func testDecodePreflightResponseSuccess() throws {
        let json = """
        {
            "success": true,
            "estimatedPriceUsd": "0.05",
            "estimatedDurationSeconds": 120,
            "balanceSufficient": true
        }
        """
        let resp = try JSONDecoder().decode(PreflightResponse.self, from: Data(json.utf8))
        XCTAssertTrue(resp.success)
        XCTAssertEqual(resp.estimatedPriceUsd, "0.05")
        XCTAssertEqual(resp.estimatedDurationSeconds, 120)
        XCTAssertTrue(resp.balanceSufficient ?? false)
        XCTAssertNil(resp.blockingReasons)
        XCTAssertNil(resp.message)
    }

    func testDecodePreflightResponseInsufficient() throws {
        let json = """
        {
            "success": true,
            "estimatedPriceUsd": "2.50",
            "estimatedDurationSeconds": 300,
            "balanceSufficient": false,
            "blockingReasons": ["余额不足", "额度超限"],
            "message": "当前余额不足以支付该任务"
        }
        """
        let resp = try JSONDecoder().decode(PreflightResponse.self, from: Data(json.utf8))
        XCTAssertTrue(resp.success)
        XCTAssertEqual(resp.estimatedPriceUsd, "2.50")
        XCTAssertEqual(resp.estimatedDurationSeconds, 300)
        XCTAssertFalse(resp.balanceSufficient ?? true)
        XCTAssertEqual(resp.blockingReasons, ["余额不足", "额度超限"])
        XCTAssertEqual(resp.message, "当前余额不足以支付该任务")
    }

    func testDecodePreflightResponseFailure() throws {
        let json = """
        {
            "success": false,
            "message": "参数不支持"
        }
        """
        let resp = try JSONDecoder().decode(PreflightResponse.self, from: Data(json.utf8))
        XCTAssertFalse(resp.success)
        XCTAssertEqual(resp.message, "参数不支持")
        XCTAssertNil(resp.estimatedPriceUsd)
    }

    func testDecodePreflightPriceUsdAsDouble() throws {
        let json = """
        {
            "success": true,
            "estimatedPriceUsd": 0.1234,
            "estimatedDurationSeconds": 60,
            "balanceSufficient": true
        }
        """
        let resp = try JSONDecoder().decode(PreflightResponse.self, from: Data(json.utf8))
        XCTAssertTrue(resp.success)
        XCTAssertEqual(resp.estimatedPriceUsd, "0.1234")
    }

    func testDecodePreflightPriceUsdAsInt() throws {
        let json = """
        {
            "success": true,
            "estimatedPriceUsd": 5,
            "estimatedDurationSeconds": 60,
            "balanceSufficient": true
        }
        """
        let resp = try JSONDecoder().decode(PreflightResponse.self, from: Data(json.utf8))
        XCTAssertTrue(resp.success)
        XCTAssertEqual(resp.estimatedPriceUsd, "5")
    }

    func testDecodePreflightPriceUsdMissing() throws {
        let json = """
        {
            "success": true,
            "estimatedDurationSeconds": 60,
            "balanceSufficient": true
        }
        """
        let resp = try JSONDecoder().decode(PreflightResponse.self, from: Data(json.utf8))
        XCTAssertTrue(resp.success)
        XCTAssertNil(resp.estimatedPriceUsd)
    }

    func testDecodePreflightMinimalFields() throws {
        let json = """
        {
            "success": true
        }
        """
        let resp = try JSONDecoder().decode(PreflightResponse.self, from: Data(json.utf8))
        XCTAssertTrue(resp.success)
        XCTAssertNil(resp.estimatedPriceUsd)
        XCTAssertNil(resp.estimatedDurationSeconds)
        XCTAssertNil(resp.balanceSufficient)
    }

    // MARK: - GenerationPreflightService State

    func testInitialStateIsIdle() {
        let service = GenerationPreflightService(api: APIService.shared)
        XCTAssertEqual(service.state, .idle)
    }

    func testResetReturnsToIdle() {
        let service = GenerationPreflightService(api: APIService.shared)
        service.reset()
        XCTAssertEqual(service.state, .idle)
    }

    func testScheduleCancelBeforeDebounceStaysIdle() async {
        let params: JobParams = .gptImage(GptImageJobParams(
            prompt: "test", channel: "official", aspectRatio: "1:1",
            resolution: "2k", quality: "medium", photoReal: false
        ))
        let svc = GenerationPreflightService(api: APIService.shared)
        svc.schedule(for: params)
        svc.reset()
        try? await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(svc.state, .idle)
    }

    // MARK: - Preflight Body Construction

    func testGptImageBody() {
        let params: JobParams = .gptImage(GptImageJobParams(
            prompt: "test prompt", channel: "official", aspectRatio: "16:9",
            resolution: "4k", quality: "high", photoReal: true,
            referenceImages: [FileRef(data: Data(), name: "test.png", mime: "image/png")]
        ))
        let body = test_makeBody(params)
        XCTAssertEqual(body["model"] as? String, "gpt-image-2")
        XCTAssertEqual(body["channel"] as? String, "official")
        XCTAssertEqual(body["aspectRatio"] as? String, "16:9")
        XCTAssertEqual(body["resolution"] as? String, "4k")
        XCTAssertEqual(body["quality"] as? String, "high")
        XCTAssertEqual(body["photoReal"] as? Bool, true)
        XCTAssertEqual(body["isImageToImage"] as? Bool, true)
        XCTAssertEqual(body["referenceCount"] as? Int, 1)
    }

    func testBananaBody() {
        let params: JobParams = .banana(BananaJobParams(
            prompt: "test", provider: "official",
            referenceImages: [FileRef(data: Data(), name: "a.png", mime: "image/png")]
        ))
        let body = test_makeBody(params)
        XCTAssertEqual(body["model"] as? String, "banana")
        XCTAssertEqual(body["provider"] as? String, "official")
        XCTAssertEqual(body["referenceCount"] as? Int, 1)
    }

    func testSeedanceBody() {
        let params: JobParams = .seedance(SeedanceJobParams(
            prompt: "test", mode: "reference", model: "dreamina-seedance-2-0-260128",
            ratio: "adaptive", resolution: "720p", duration: 5, count: 2,
            generateAudio: true
        ))
        let body = test_makeBody(params)
        XCTAssertEqual(body["model"] as? String, "seedance20")
        XCTAssertEqual(body["mode"] as? String, "reference")
        XCTAssertEqual(body["internalModel"] as? String, "dreamina-seedance-2-0-260128")
        XCTAssertEqual(body["duration"] as? Int, 5)
        XCTAssertEqual(body["count"] as? Int, 2)
        XCTAssertEqual(body["generateAudio"] as? Bool, true)
    }

    func testWanBody() {
        let params: JobParams = .wan(WanJobParams(
            mode: "image", prompt: "test", width: 720, height: 1280, seconds: 5, enable48G: true,
            imageData: Data(), imageName: "input.png", imageMime: "image/png"
        ))
        let body = test_makeBody(params)
        XCTAssertEqual(body["model"] as? String, "wan21")
        XCTAssertEqual(body["mode"] as? String, "image")
        XCTAssertEqual(body["width"] as? Int, 720)
        XCTAssertEqual(body["height"] as? Int, 1280)
        XCTAssertEqual(body["duration"] as? Int, 5)
        XCTAssertEqual(body["enable48G"] as? Bool, true)
        XCTAssertEqual(body["hasImage"] as? Bool, true)
    }

    func testVeoBody() {
        var p = VeoJobParams()
        p.channel = "official"; p.model = "fast"; p.mode = "text"
        p.prompt = "test"; p.aspectRatio = "9:16"; p.resolution = "720p"
        p.duration = "8"; p.generateAudio = false
        let body = test_makeBody(.veo(p))
        XCTAssertEqual(body["model"] as? String, "veo-video")
        XCTAssertEqual(body["channel"] as? String, "official")
        XCTAssertEqual(body["internalModel"] as? String, "fast")
        XCTAssertEqual(body["mode"] as? String, "text")
    }

    func testGrokBody() {
        let params: JobParams = .grok(GrokJobParams(
            prompt: "test", channel: "budget", mode: "text",
            aspectRatio: "9:16", resolution: "720p", duration: "6"
        ))
        let body = test_makeBody(params)
        XCTAssertEqual(body["model"] as? String, "grok-video")
        XCTAssertEqual(body["channel"] as? String, "budget")
        XCTAssertEqual(body["mode"] as? String, "text")
        XCTAssertEqual(body["duration"] as? String, "6")
    }

    func testBodyHasPromptField() {
        let withPrompt: JobParams = .gptImage(GptImageJobParams(
            prompt: "hello", channel: "official", aspectRatio: "1:1",
            resolution: "2k", quality: "medium", photoReal: false
        ))
        XCTAssertEqual(test_makeBody(withPrompt)["hasPrompt"] as? Bool, true)

        let emptyPrompt: JobParams = .gptImage(GptImageJobParams(
            prompt: "", channel: "official", aspectRatio: "1:1",
            resolution: "2k", quality: "medium", photoReal: false
        ))
        XCTAssertEqual(test_makeBody(emptyPrompt)["hasPrompt"] as? Bool, false)
    }

    // MARK: - Decoding Compatibility

    func testDecodeDurationSecondsAsString() throws {
        let json = """
        {"success":true,"estimatedDurationSeconds":"120","balanceSufficient":true}
        """
        let resp = try JSONDecoder().decode(PreflightResponse.self, from: Data(json.utf8))
        XCTAssertEqual(resp.estimatedDurationSeconds, 120)
    }

    func testDecodeDurationSecondsAsDouble() throws {
        let json = """
        {"success":true,"estimatedDurationSeconds":120.7,"balanceSufficient":true}
        """
        let resp = try JSONDecoder().decode(PreflightResponse.self, from: Data(json.utf8))
        XCTAssertEqual(resp.estimatedDurationSeconds, 120)
    }

    func testDecodePriceUsdDoubleNoRounding() throws {
        let json = """
        {"success":true,"estimatedPriceUsd":0.123456,"balanceSufficient":true}
        """
        let resp = try JSONDecoder().decode(PreflightResponse.self, from: Data(json.utf8))
        XCTAssertEqual(resp.estimatedPriceUsd, "0.123456")
    }

    // MARK: - State helpers

    func testStateIsBlocking() {
        let info = GenerationPreflightService.Result(
            estimatedPriceUsd: "1.0", estimatedDurationSeconds: 60,
            balanceSufficient: false, blockingReasons: ["余额不足"], itemCount: 1
        )
        XCTAssertTrue(GenerationPreflightService.State.insufficient(info).isBlocking)
        XCTAssertFalse(GenerationPreflightService.State.ready(info).isBlocking)
        XCTAssertFalse(GenerationPreflightService.State.idle.isBlocking)
        XCTAssertFalse(GenerationPreflightService.State.loading.isBlocking)
        XCTAssertFalse(GenerationPreflightService.State.unavailable.isBlocking)
        XCTAssertTrue(GenerationPreflightService.State.error("err").isBlocking)
    }
}

extension PreflightServiceTests {
    private func test_makeBody(_ params: JobParams) -> [String: Any] {
        let service = GenerationPreflightService(api: APIService.shared)
        return service.makeBody(params)
    }
}
