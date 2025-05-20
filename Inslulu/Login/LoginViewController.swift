import UIKit
import SnapKit
import Alamofire
import Toast_Swift

class LoginViewController: UIViewController {
    
    private let loginView = LoginView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        view.addSubview(loginView)
        
        loginView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func setupActions() {
        loginView.loginButton.addTarget(self, action: #selector(loginButtonTapped), for: .touchUpInside)
    }
    
    @objc private func loginButtonTapped() {
        guard let username = loginView.usernameTextField.text,
              let password = loginView.passwordTextField.text else {
            view.makeToast("请输入用户名和密码")
            return
        }
        
        // 实现登录逻辑
        login(username: username, password: password)
    }
    
    private func login(username: String, password: String) {
        NetworkManager.shared.login(username: username, password: password) { [weak self] result in
            switch result {
            case .success(let message):
                self?.view.makeToast(message)
                // 登录成功后跳转到图片预览页面
                self?.navigateToImagePreview()
            case .failure(let error):
                self?.view.makeToast("登录失败：\(error.localizedDescription)")
            }
        }
    }
    
    private func navigateToImagePreview() {
        let imagePreviewVC = ImagePreviewViewController()
        let navigationController = UINavigationController(rootViewController: imagePreviewVC)
        navigationController.modalPresentationStyle = .fullScreen
        present(navigationController, animated: true)
    }
} 