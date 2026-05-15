import Foundation

struct FileRef: Codable, Equatable, Hashable {
    let data: Data
    let name: String
    let mime: String
}
