import Foundation

// MARK: - Script Table Row (结构化分镜行)

struct VideoScriptTableRow: Codable, Identifiable {
    var id: String = UUID().uuidString
    var shotNumber: Int
    var sceneDescription: String
    var copy: String
    var duration: String
    var imagePrompt: String
    var videoPrompt: String
    var notes: String

    enum CodingKeys: String, CodingKey {
        case id, shotNumber, sceneDescription, copy, duration, imagePrompt, videoPrompt, notes
    }

    init(id: String = UUID().uuidString, shotNumber: Int, sceneDescription: String = "", copy: String = "", duration: String = "", imagePrompt: String = "", videoPrompt: String = "", notes: String = "") {
        self.id = id
        self.shotNumber = shotNumber
        self.sceneDescription = sceneDescription
        self.copy = copy
        self.duration = duration
        self.imagePrompt = imagePrompt
        self.videoPrompt = videoPrompt
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        shotNumber = try container.decodeIfPresent(Int.self, forKey: .shotNumber) ?? 0
        sceneDescription = try container.decodeIfPresent(String.self, forKey: .sceneDescription) ?? ""
        copy = try container.decodeIfPresent(String.self, forKey: .copy) ?? ""
        duration = try container.decodeIfPresent(String.self, forKey: .duration) ?? ""
        imagePrompt = try container.decodeIfPresent(String.self, forKey: .imagePrompt) ?? ""
        videoPrompt = try container.decodeIfPresent(String.self, forKey: .videoPrompt) ?? ""
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }
}

// MARK: - Generate Table

struct VideoScriptGenerateTableRequest: Codable {
    let requirement: String
}

struct VideoScriptGenerateTableResponse: Codable {
    let success: Bool
    let rows: [VideoScriptTableRow]?
    let message: String?
}

// MARK: - Refine

struct VideoScriptRefineRequest: Codable {
    let feedback: String
    let rows: [VideoScriptTableRow]
}

struct VideoScriptRefineResponse: Codable {
    let success: Bool
    let rows: [VideoScriptTableRow]?
    let message: String?
}

// MARK: - Translate Copy

struct VideoScriptTranslateCopyRequest: Codable {
    let rows: [VideoScriptTableRow]
}

struct VideoScriptTranslateCopyResponse: Codable {
    let success: Bool
    let rows: [VideoScriptTableRow]?
    let message: String?
}

// MARK: - Generate Prompt

struct VideoScriptGeneratePromptRequest: Codable {
    let rowId: String
    let sceneDescription: String
    let copy: String
}

struct VideoScriptGeneratePromptResponse: Codable {
    let success: Bool
    let prompt: String?
    let message: String?
}

// MARK: - Submit Task

struct VideoScriptSubmitImageRequest: Codable {
    let rowId: String
    let imagePrompt: String
    let aspectRatio: String?
    let resolution: String?
}

struct VideoScriptSubmitVideoRequest: Codable {
    let rowId: String
    let videoPrompt: String
    let aspectRatio: String?
    let duration: String?
}

struct VideoScriptSubmitImageToVideoRequest: Codable {
    let rowId: String
    let imagePrompt: String
    let imageUrl: String?
    let model: String // grok, seedance20, v31lite, v31pro_ref, kling26, s_pro
    let audioEnabled: Bool?
    let realMode: Bool?
}

struct VideoScriptSubmitResponse: Codable {
    let success: Bool
    let taskId: String?
    let ourTaskId: String?
    let message: String?
}

// MARK: - Query Task

struct VideoScriptQueryResponse: Codable {
    let success: Bool
    let status: String?
    let resultUrl: String?
    let imageResultUrls: [String]?
    let videoResultUrl: String?
    let errorMessage: String?
    let message: String?
}

// MARK: - Store

struct VideoScriptStoreSaveRequest: Codable {
    let requirement: String
    let title: String
    let rows: [VideoScriptTableRow]
}

struct VideoScriptStoreSaveResponse: Codable {
    let success: Bool
    let id: String?
    let message: String?
}

struct VideoScriptStoreItem: Codable, Identifiable {
    let id: String
    let title: String
    let requirement: String
    let rowCount: Int
    let createdAt: String
    let updatedAt: String
}

struct VideoScriptStoreListResponse: Codable {
    let success: Bool
    let items: [VideoScriptStoreItem]?
    let message: String?
}

struct VideoScriptStoreDetailResponse: Codable {
    let success: Bool
    let item: VideoScriptStoreDetail?
    let message: String?
}

struct VideoScriptStoreDetail: Codable, Identifiable {
    let id: String
    let title: String
    let requirement: String
    let rows: [VideoScriptTableRow]
    let createdAt: String
    let updatedAt: String
}

struct VideoScriptDeleteResponse: Codable {
    let success: Bool
    let message: String?
}

// MARK: - Share

struct VideoScriptShareResponse: Codable {
    let success: Bool
    let token: String?
    let url: String?
    let message: String?
}

struct VideoScriptImportResponse: Codable {
    let success: Bool
    let item: VideoScriptStoreDetail?
    let message: String?
}
