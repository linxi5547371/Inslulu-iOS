import Foundation
import KeychainAccess

class UserManager {
    static let shared = UserManager()
    private let keychain = Keychain(service: "com.albert.ins.com.Inslulu")
    private let tokenKey = "userToken"
    private let loginTimeKey = "loginTime"
    
    private init() {}
    
    var isLoggedIn: Bool {
        guard let token = token else { return false }
        guard let loginTime = loginTime else { return false }
        
        // 检查是否在30天有效期内
        let expirationTime = loginTime.addingTimeInterval(30 * 24 * 60 * 60) // 30天
        return Date() < expirationTime
    }
    
    var token: String? {
        get {
            try? keychain.get(tokenKey)
        }
        set {
            if let newValue = newValue {
                try? keychain.set(newValue, key: tokenKey)
                // 记录登录时间
                loginTime = Date()
            } else {
                try? keychain.remove(tokenKey)
                loginTime = nil
            }
        }
    }
    
    private var loginTime: Date? {
        get {
            if let timeString = try? keychain.get(loginTimeKey),
               let timeInterval = TimeInterval(timeString) {
                return Date(timeIntervalSince1970: timeInterval)
            }
            return nil
        }
        set {
            if let newValue = newValue {
                try? keychain.set(String(newValue.timeIntervalSince1970), key: loginTimeKey)
            } else {
                try? keychain.remove(loginTimeKey)
            }
        }
    }
    
    func logout() {
        token = nil
    }
    
    // 获取剩余有效期（天数）
    var remainingDays: Int {
        guard let loginTime = loginTime else { return 0 }
        let expirationTime = loginTime.addingTimeInterval(30 * 24 * 60 * 60)
        let remainingSeconds = expirationTime.timeIntervalSince(Date())
        return max(0, Int(remainingSeconds / (24 * 60 * 60)))
    }
} 