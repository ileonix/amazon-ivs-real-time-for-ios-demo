import Foundation

struct AuthItem: Codable {
    let endpoint: String
    let streamKey: String
    
    init(endpoint: String, streamKey: String) {
        self.endpoint = endpoint
        self.streamKey = streamKey
    }
}