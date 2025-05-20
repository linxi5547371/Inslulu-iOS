import Foundation
import Alamofire
import UIKit

class NetworkManager {
    static let shared = NetworkManager()
    private let baseURL = "http://localhost:5001/api"
    private var token: String?
    
    private init() {}
    
    // MARK: - 注册
    func register(username: String, password: String, completion: @escaping (Result<String, Error>) -> Void) {
        let parameters: [String: Any] = [
            "username": username,
            "password": password
        ]
        
        AF.request("\(baseURL)/register",
                  method: .post,
                  parameters: parameters,
                  encoding: JSONEncoding.default)
            .responseDecodable(of: RegisterResponse.self) { response in
                switch response.result {
                case .success(let value):
                    completion(.success(value.message))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
    }
    
    // MARK: - 登录
    func login(username: String, password: String, completion: @escaping (Result<String, Error>) -> Void) {
        let parameters: [String: Any] = [
            "username": username,
            "password": password
        ]
        
        AF.request("\(baseURL)/login",
                  method: .post,
                  parameters: parameters,
                  encoding: JSONEncoding.default)
            .responseDecodable(of: LoginResponse.self) { [weak self] response in
                switch response.result {
                case .success(let value):
                    self?.token = value.access_token
                    completion(.success(value.message))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
    }
    
    // MARK: - 上传文件
    func uploadFile(image: UIImage, completion: @escaping (Result<UploadResponse, Error>) -> Void) {
        guard let token = token else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "未登录"])))
            return
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)"
        ]
        
        AF.upload(multipartFormData: { multipartFormData in
            if let imageData = image.jpegData(compressionQuality: 0.8) {
                multipartFormData.append(imageData, withName: "file", fileName: "image.jpg", mimeType: "image/jpeg")
            }
        }, to: "\(baseURL)/upload", headers: headers)
        .responseDecodable(of: UploadResponse.self) { response in
            switch response.result {
            case .success(let value):
                completion(.success(value))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - 获取文件列表
    func getFileList(completion: @escaping (Result<FileListResponse, Error>) -> Void) {
        guard let token = token else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "未登录"])))
            return
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)"
        ]
        
        AF.request("\(baseURL)/files",
                  method: .get,
                  headers: headers)
            .responseDecodable(of: FileListResponse.self) { response in
                switch response.result {
                case .success(let value):
                    completion(.success(value))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
    }
    
    // MARK: - 删除文件
    func deleteFile(filename: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let token = token else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "未登录"])))
            return
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)"
        ]
        
        AF.request("\(baseURL)/files/\(filename)",
                  method: .delete,
                  headers: headers)
            .responseDecodable(of: DeleteResponse.self) { response in
                switch response.result {
                case .success(let value):
                    completion(.success(value.message))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
    }
}

// MARK: - Response Models
struct RegisterResponse: Codable {
    let message: String
}

struct LoginResponse: Codable {
    let access_token: String
    let message: String
}

struct UploadResponse: Codable {
    let message: String
    let filename: String
    let preview_url: String
}

struct FileListResponse: Codable {
    let files: [FileInfo]
}

struct FileInfo: Codable {
    let filename: String
    let size: Int
    let upload_time: TimeInterval
    let preview_url: String
}

struct DeleteResponse: Codable {
    let message: String
    let filename: String
} 