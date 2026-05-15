import Foundation

struct FileRef: Codable, Equatable, Hashable {
    var data: Data
    var name: String
    var mime: String
}
