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
        checkLoginStatus()
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
        loginView.registerButton.addTarget(self, action: #selector(registerButtonTapped), for: .touchUpInside)
    }
    
    private func checkLoginStatus() {
        if UserManager.shared.isLoggedIn {
            navigateToImagePreview()
        }
    }
    
    @objc private func loginButtonTapped() {
        guard let username = loginView.usernameTextField.text,
              let password = loginView.passwordTextField.text else {
            view.makeToast("请输入用户名和密码")
            return
        }
        
        login(username: username, password: password)
    }
    
    @objc private func registerButtonTapped() {
        guard let username = loginView.usernameTextField.text,
              let password = loginView.passwordTextField.text else {
            view.makeToast("请输入用户名和密码")
            return
        }
        
        register(username: username, password: password)
    }
    
    private func login(username: String, password: String) {
        NetworkManager.shared.login(username: username, password: password) { [weak self] result in
            switch result {
            case .success(let message):
                // 保存 token 到 UserManager
                if let token = NetworkManager.shared.token {
                    UserManager.shared.token = token
                }
                self?.view.makeToast(message)
                // 登录成功后跳转到图片预览页面
                self?.navigateToImagePreview()
            case .failure(let error):
                self?.view.makeToast("登录失败：\(error.localizedDescription)")
            }
        }
    }
    
    private func register(username: String, password: String) {
        NetworkManager.shared.register(username: username, password: password) { [weak self] result in
            switch result {
            case .success(let message):
                self?.view.makeToast(message)
                // 注册成功后自动登录
                self?.login(username: username, password: password)
            case .failure(let error):
                self?.view.makeToast("注册失败：\(error.localizedDescription)")
            }
        }
    }
    
    private func navigateToImagePreview() {
        let imagePreviewVC = ImagePreviewViewController()
        let navigationController = UINavigationController(rootViewController: imagePreviewVC)
        
        // 添加设置按钮
        let settingsButton = UIBarButtonItem(image: UIImage(systemName: "gear"),
                                           style: .plain,
                                           target: self,
                                           action: #selector(settingsButtonTapped))
        imagePreviewVC.navigationItem.rightBarButtonItem = settingsButton
        
        navigationController.modalPresentationStyle = .fullScreen
        present(navigationController, animated: true)
    }
    
    @objc func settingsButtonTapped() {
        let settingsVC = SettingsViewController()
        navigationController?.pushViewController(settingsVC, animated: true)
    }
} 
