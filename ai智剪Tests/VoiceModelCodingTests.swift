import XCTest
@testable import aiZhijian

// MARK: - 语音模型 Codable 兼容性测试
//
// 业务背景: 语音生成页面加载声音列表时显示"数据解析失败"。
// 根因: 后端 API 返回 snake_case JSON (voice_id, preview_url)，
//       但 EleVoice / MiniMaxVoice 没有 CodingKeys 映射。
//
// 类型契约:
//   - 必须能解码 snake_case JSON (服务器真实返回格式)
//   - 必须能解码 camelCase JSON (round-trip 兼容)
//   - round-trip: encode → decode → 值不变
//   - 可选字段缺失 → 解码为 nil
//   - 必填字段缺失 → decode 抛错

final class VoiceModelCodingTests: XCTestCase {

    private let decoder = JSONDecoder()

    // MARK: - EleVoice: snake_case 解码 (当前会失败!)

    func testEleVoice_DecodesSnakeCase() throws {
        // 模拟 ElevenLabs API 真实返回的 snake_case JSON
        let json = """
        {
            "voice_id": "21m00Tcm4TlvDq8ikWAM",
            "name": "Rachel",
            "preview_url": "https://storage.googleapis.com/elevenlabs/audio/preview.mp3",
            "category": "premade",
            "labels": {"accent": "american", "age": "young"}
        }
        """.data(using: .utf8)!

        let voice = try decoder.decode(EleVoice.self, from: json)

        XCTAssertEqual(voice.voiceId, "21m00Tcm4TlvDq8ikWAM")
        XCTAssertEqual(voice.name, "Rachel")
        XCTAssertEqual(voice.previewUrl, "https://storage.googleapis.com/elevenlabs/audio/preview.mp3")
        XCTAssertEqual(voice.category, "premade")
        XCTAssertEqual(voice.labels?["accent"], "american")
        XCTAssertEqual(voice.labels?["age"], "young")
    }

    func testEleVoice_DecodesSnakeCaseMinimal() throws {
        // 只含必填字段
        let json = """
        {"voice_id": "abc123"}
        """.data(using: .utf8)!

        let voice = try decoder.decode(EleVoice.self, from: json)
        XCTAssertEqual(voice.voiceId, "abc123")
        XCTAssertNil(voice.name)
        XCTAssertNil(voice.previewUrl)
        XCTAssertNil(voice.category)
        XCTAssertNil(voice.labels)
    }

    // MARK: - EleVoice: snake_case 与编码器输出一致

    func testEleVoice_DecodesSnakeCaseFull() throws {
        // 与 JSONEncoder 现在产生的格式一致 (CodingKeys 映射到 snake_case)
        let json = """
        {
            "voice_id": "snake456",
            "name": "Test Voice",
            "preview_url": "https://example.com/test.mp3"
        }
        """.data(using: .utf8)!

        let voice = try decoder.decode(EleVoice.self, from: json)
        XCTAssertEqual(voice.voiceId, "snake456")
        XCTAssertEqual(voice.name, "Test Voice")
    }

    // MARK: - EleVoice: round-trip

    func testEleVoice_RoundTrip() throws {
        let original = EleVoice(
            voiceId: "roundtrip-1",
            name: "Round Trip",
            previewUrl: "https://example.com/rt.mp3",
            category: "premade",
            labels: ["key": "value"]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try decoder.decode(EleVoice.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    // MARK: - EleVoice: 必填字段缺失

    func testEleVoice_RejectsMissingVoiceId() {
        let json = """
        {"name": "No ID"}
        """.data(using: .utf8)!

        XCTAssertThrowsError(try decoder.decode(EleVoice.self, from: json)) { error in
            guard case DecodingError.keyNotFound? = error as? DecodingError else {
                XCTFail("Expected keyNotFound, got \(error)")
                return
            }
        }
    }

    // MARK: - EleVoiceListResponse: snake_case

    func testEleVoiceListResponse_DecodesSnakeCase() throws {
        let json = """
        {
            "voices": [
                {"voice_id": "v1", "name": "Voice 1"},
                {"voice_id": "v2", "name": "Voice 2"}
            ]
        }
        """.data(using: .utf8)!

        let resp = try decoder.decode(EleVoiceListResponse.self, from: json)
        XCTAssertEqual(resp.voices?.count, 2)
        XCTAssertEqual(resp.voices?.first?.voiceId, "v1")
        XCTAssertEqual(resp.voices?.last?.name, "Voice 2")
    }

    func testEleVoiceListResponse_DecodesEmptyVoices() throws {
        let json = """
        {"voices": []}
        """.data(using: .utf8)!

        let resp = try decoder.decode(EleVoiceListResponse.self, from: json)
        XCTAssertEqual(resp.voices?.count, 0)
    }

    func testEleVoiceListResponse_DecodesNullVoices() throws {
        let json = """
        {"success": true}
        """.data(using: .utf8)!

        let resp = try decoder.decode(EleVoiceListResponse.self, from: json)
        XCTAssertNil(resp.voices)
        XCTAssertNil(resp.message)
    }

    // MARK: - MiniMaxVoice: snake_case

    func testMiniMaxVoice_DecodesSnakeCase() throws {
        let json = """
        {
            "voice_id": "mm_voice_001",
            "name": "甜美女生",
            "preview_audio_path": "https://minimax.example.com/preview.wav"
        }
        """.data(using: .utf8)!

        let voice = try decoder.decode(MiniMaxVoice.self, from: json)
        XCTAssertEqual(voice.voiceId, "mm_voice_001")
        XCTAssertEqual(voice.name, "甜美女生")
        XCTAssertEqual(voice.previewAudioPath, "https://minimax.example.com/preview.wav")
    }

    func testMiniMaxVoice_DecodesSnakeCaseMinimal() throws {
        let json = """
        {"voice_id": "mm_minimal"}
        """.data(using: .utf8)!

        let voice = try decoder.decode(MiniMaxVoice.self, from: json)
        XCTAssertEqual(voice.voiceId, "mm_minimal")
        XCTAssertNil(voice.name)
        XCTAssertNil(voice.previewAudioPath)
    }

    // MARK: - MiniMaxVoice: snake_case 与编码器输出一致

    func testMiniMaxVoice_DecodesSnakeCaseFull() throws {
        let json = """
        {
            "voice_id": "mm_snake",
            "name": "Snake Voice",
            "preview_audio_path": "https://example.com/snake.wav"
        }
        """.data(using: .utf8)!

        let voice = try decoder.decode(MiniMaxVoice.self, from: json)
        XCTAssertEqual(voice.voiceId, "mm_snake")
    }

    // MARK: - MiniMaxVoice: round-trip

    func testMiniMaxVoice_RoundTrip() throws {
        let original = MiniMaxVoice(
            voiceId: "mm_rt",
            name: "Round Trip",
            previewAudioPath: "https://example.com/rt.wav"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try decoder.decode(MiniMaxVoice.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    // MARK: - MiniMaxVoice: 必填字段缺失

    func testMiniMaxVoice_RejectsMissingVoiceId() {
        let json = """
        {"name": "No ID"}
        """.data(using: .utf8)!

        XCTAssertThrowsError(try decoder.decode(MiniMaxVoice.self, from: json)) { error in
            guard case DecodingError.keyNotFound? = error as? DecodingError else {
                XCTFail("Expected keyNotFound, got \(error)")
                return
            }
        }
    }

    // MARK: - MiniMaxVoiceListResponse: snake_case

    func testMiniMaxVoiceListResponse_DecodesSnakeCase() throws {
        let json = """
        {
            "voices": [
                {"voice_id": "mm1", "name": "MiniMax 1"},
                {"voice_id": "mm2", "name": "MiniMax 2"}
            ]
        }
        """.data(using: .utf8)!

        let resp = try decoder.decode(MiniMaxVoiceListResponse.self, from: json)
        XCTAssertEqual(resp.voices?.count, 2)
        XCTAssertEqual(resp.voices?.first?.voiceId, "mm1")
    }

    func testMiniMaxVoiceListResponse_DecodesEmptyVoices() throws {
        let json = """
        {"voices": []}
        """.data(using: .utf8)!

        let resp = try decoder.decode(MiniMaxVoiceListResponse.self, from: json)
        XCTAssertEqual(resp.voices?.count, 0)
    }

    // MARK: - 边界值: 特殊字符

    func testEleVoice_DecodesWithSpecialCharacters() throws {
        let json = """
        {
            "voice_id": "v_1",
            "name": "声音 / 测试 (special)",
            "preview_url": "https://example.com/a b.mp3"
        }
        """.data(using: .utf8)!

        let voice = try decoder.decode(EleVoice.self, from: json)
        XCTAssertEqual(voice.name, "声音 / 测试 (special)")
        XCTAssertEqual(voice.previewUrl, "https://example.com/a b.mp3")
    }

    // MARK: - 一次性解码完整响应

    func testFullVoiceListApiResponse_DecodesFromSnakeCase() throws {
        // 模拟 /api/media/elevenlabs/voices 的完整响应
        let json = """
        {
            "success": true,
            "voices": [
                {"voice_id": "v1", "name": "Alice", "preview_url": "https://ex.com/a.mp3", "category": "premade"},
                {"voice_id": "v2", "name": "Bob", "preview_url": "https://ex.com/b.mp3", "category": "professional"}
            ],
            "message": "OK"
        }
        """.data(using: .utf8)!

        let resp = try decoder.decode(EleVoiceListResponse.self, from: json)
        XCTAssertTrue(resp.success ?? false)
        XCTAssertEqual(resp.voices?.count, 2)
        XCTAssertEqual(resp.voices?[1].previewUrl, "https://ex.com/b.mp3")
        XCTAssertEqual(resp.message, "OK")

        // 验证这个 response 在 APIService.get() 的泛型路径中也能正常工作
        // 类型推断: get("/api/media/elevenlabs/voices") -> EleVoiceListResponse
    }

    func testFullMiniMaxVoiceListResponse_DecodesFromSnakeCase() throws {
        let json = """
        {
            "voices": [
                {"voice_id": "mv1", "name": "MiniMax Voice 1", "preview_audio_path": "https://mm.com/p1.wav"},
                {"voice_id": "mv2"}
            ]
        }
        """.data(using: .utf8)!

        let resp = try decoder.decode(MiniMaxVoiceListResponse.self, from: json)
        XCTAssertEqual(resp.voices?.count, 2)
        XCTAssertEqual(resp.voices?[1].voiceId, "mv2")
        XCTAssertNil(resp.voices?[1].name)
        XCTAssertNil(resp.voices?[1].previewAudioPath)
    }

    // MARK: - EleTTSModel: snake_case

    func testEleTTSModel_DecodesSnakeCase() throws {
        let json = """
        {
            "model_id": "eleven_multilingual_v2",
            "name": "Eleven Multilingual v2",
            "description": "Supports 29 languages"
        }
        """.data(using: .utf8)!

        let model = try decoder.decode(EleTTSModel.self, from: json)
        XCTAssertEqual(model.modelId, "eleven_multilingual_v2")
        XCTAssertEqual(model.name, "Eleven Multilingual v2")
        XCTAssertEqual(model.description, "Supports 29 languages")
    }

    func testEleTTSModel_DecodesSnakeCaseMinimal() throws {
        let json = """
        {"model_id": "eleven_monolingual_v1"}
        """.data(using: .utf8)!

        let model = try decoder.decode(EleTTSModel.self, from: json)
        XCTAssertEqual(model.modelId, "eleven_monolingual_v1")
        XCTAssertNil(model.name)
        XCTAssertNil(model.description)
    }

    func testEleTTSModel_RoundTrip() throws {
        let original = EleTTSModel(modelId: "test_m", name: "Test", description: "A test")
        let data = try JSONEncoder().encode(original)
        let decoded = try decoder.decode(EleTTSModel.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - EleCloneResponse: snake_case

    func testEleCloneResponse_DecodesSnakeCase() throws {
        let json = """
        {
            "success": true,
            "voice_id": "new_cloned_voice_123",
            "message": "Voice created successfully"
        }
        """.data(using: .utf8)!

        let resp = try decoder.decode(EleCloneResponse.self, from: json)
        XCTAssertTrue(resp.success ?? false)
        XCTAssertEqual(resp.voiceId, "new_cloned_voice_123")
        XCTAssertEqual(resp.message, "Voice created successfully")
    }

    // MARK: - EleHistoryItem: snake_case

    func testEleHistoryItem_DecodesSnakeCase() throws {
        let json = """
        {
            "history_item_id": "hist_001",
            "text": "Hello world",
            "date_unix": 1700000000,
            "character_id": "char_abc",
            "voice_id": "voice_xyz"
        }
        """.data(using: .utf8)!

        let item = try decoder.decode(EleHistoryItem.self, from: json)
        XCTAssertEqual(item.historyItemId, "hist_001")
        XCTAssertEqual(item.text, "Hello world")
        XCTAssertEqual(item.dateUnix, 1700000000)
        XCTAssertEqual(item.characterId, "char_abc")
        XCTAssertEqual(item.voiceId, "voice_xyz")
    }

    func testEleHistoryItem_DecodesSnakeCaseOptional() throws {
        let json = """
        {"history_item_id": "hist_002"}
        """.data(using: .utf8)!

        let item = try decoder.decode(EleHistoryItem.self, from: json)
        XCTAssertEqual(item.historyItemId, "hist_002")
        XCTAssertNil(item.text)
        XCTAssertNil(item.dateUnix)
        XCTAssertNil(item.characterId)
        XCTAssertNil(item.voiceId)
    }

    // MARK: - MiniMaxCloneResponse: snake_case

    func testMiniMaxCloneResponse_DecodesSnakeCase() throws {
        let json = """
        {
            "success": true,
            "voice_id": "mm_clone_456",
            "message": "Clone created"
        }
        """.data(using: .utf8)!

        let resp = try decoder.decode(MiniMaxCloneResponse.self, from: json)
        XCTAssertTrue(resp.success ?? false)
        XCTAssertEqual(resp.voiceId, "mm_clone_456")
        XCTAssertEqual(resp.message, "Clone created")
    }

    // MARK: - labels resilience

    func testEleVoice_DecodesWithNonStringLabels_GracefullyFallsBack() throws {
        // labels 返回非字符串 value（如数字标签），不应崩溃
        let json = """
        {
            "voice_id": "v_labels_safe",
            "name": "Safe Voice",
            "labels": {"accent": "american", "tier": 1}
        }
        """.data(using: .utf8)!

        let voice = try decoder.decode(EleVoice.self, from: json)
        XCTAssertEqual(voice.voiceId, "v_labels_safe")
        XCTAssertEqual(voice.name, "Safe Voice")
        // 非字符串 value 导致整个 labels 优雅降级为 nil
        XCTAssertNil(voice.labels, "包含非字符串 value 时应降级为 nil 而非崩溃")
    }

    func testEleVoice_DecodesWithNullLabels() throws {
        let json = """
        {
            "voice_id": "v_null_labels",
            "labels": null
        }
        """.data(using: .utf8)!

        let voice = try decoder.decode(EleVoice.self, from: json)
        XCTAssertEqual(voice.voiceId, "v_null_labels")
        XCTAssertNil(voice.labels)
    }

    func testEleVoice_DecodesWithStringLabels() throws {
        let json = """
        {
            "voice_id": "v_string_labels",
            "labels": {"accent": "british", "gender": "female"}
        }
        """.data(using: .utf8)!

        let voice = try decoder.decode(EleVoice.self, from: json)
        XCTAssertEqual(voice.labels?["accent"], "british")
        XCTAssertEqual(voice.labels?["gender"], "female")
    }

    // MARK: - EleModelListResponse + EleHistoryResponse: snake_case 防御

    func testEleModelListResponse_DecodesSnakeCase() throws {
        let json = """
        {
            "models": [
                {"model_id": "m1", "name": "Model 1"},
                {"model_id": "m2", "name": "Model 2"}
            ]
        }
        """.data(using: .utf8)!

        let resp = try decoder.decode(EleModelListResponse.self, from: json)
        XCTAssertEqual(resp.models?.count, 2)
        XCTAssertEqual(resp.models?.first?.modelId, "m1")
    }

    func testEleHistoryResponse_DecodesSnakeCase() throws {
        let json = """
        {
            "history": [
                {"history_item_id": "h1", "voice_id": "v1", "text": "Hello"},
                {"history_item_id": "h2", "voice_id": "v2"}
            ]
        }
        """.data(using: .utf8)!

        let resp = try decoder.decode(EleHistoryResponse.self, from: json)
        XCTAssertEqual(resp.history?.count, 2)
        XCTAssertEqual(resp.history?.first?.historyItemId, "h1")
        XCTAssertEqual(resp.history?.last?.voiceId, "v2")
    }
}
