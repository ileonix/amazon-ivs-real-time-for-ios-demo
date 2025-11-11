import Foundation

class UserDefaultsAuthDao {
    static let shared = UserDefaultsAuthDao()
    
    private let userDefaults = UserDefaults.standard
    private let authKey = "lastUsedAuth"
    
    private init() {}
    
    func insert(_ authItem: AuthItem) {
        if let encoded = try? JSONEncoder().encode(authItem) {
            userDefaults.set(encoded, forKey: authKey)
        }
    }
    
    func lastUsedAuth() -> AuthItem? {
        guard let data = userDefaults.data(forKey: authKey),
              let authItem = try? JSONDecoder().decode(AuthItem.self, from: data) else {
            return nil
        }
        return authItem
    }
}