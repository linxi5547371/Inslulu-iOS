import UIKit
import SnapKit
import TLPhotoPicker
import SKPhotoBrowser
import Kingfisher
import Toast_Swift
import Photos

class ImagePreviewViewController: UIViewController {
    
    // MARK: - UI Components
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 10
        let width = (UIScreen.main.bounds.width - 30) / 2
        layout.itemSize = CGSize(width: width, height: width)
        layout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .white
        collectionView.register(ImageCell.self, forCellWithReuseIdentifier: "ImageCell")
        collectionView.delegate = self
        collectionView.dataSource = self
        return collectionView
    }()
    
    private lazy var addButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        button.tintColor = .systemBlue
        button.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    // MARK: - Properties
    private var images: [FileInfo] = []
    private var isUploading = false
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        fetchImages()
    }
    
    // MARK: - Setup
    private func setupUI() {
        title = "图片预览"
        view.backgroundColor = .white
        
        view.addSubview(collectionView)
        view.addSubview(addButton)
        view.addSubview(loadingIndicator)
        
        // 添加设置按钮
        let settingsButton = UIBarButtonItem(image: UIImage(systemName: "gear"),
                                           style: .plain,
                                           target: self,
                                             action: #selector(settingsButtonTapped))
        navigationItem.rightBarButtonItem = settingsButton
        
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        addButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-20)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-20)
            make.width.height.equalTo(50)
        }
        
        loadingIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
    
    // MARK: - Actions
    @objc private func addButtonTapped() {
        let viewController = TLPhotosPickerViewController()
        viewController.delegate = self
        viewController.modalPresentationStyle = .fullScreen
        
        // 配置图片选择器
        viewController.configure.maxSelectedAssets = 9
        viewController.configure.allowedVideo = false
        viewController.configure.allowedPhotograph = false
        viewController.configure.allowedLivePhotos = false
        viewController.configure.usedCameraButton = false
        
        present(viewController, animated: true)
    }
    
    @objc func settingsButtonTapped() {
        let settingsVC = SettingsViewController()
        navigationController?.pushViewController(settingsVC, animated: true)
    }
    
    // MARK: - Network
    private func fetchImages() {
        loadingIndicator.startAnimating()
        NetworkManager.shared.getFileList { [weak self] result in
            self?.loadingIndicator.stopAnimating()
            switch result {
            case .success(let response):
                self?.images = response.files
                self?.collectionView.reloadData()
            case .failure(let error):
                self?.view.makeToast("获取图片列表失败：\(error.localizedDescription)")
            }
        }
    }
    
    private func uploadImage(_ image: UIImage) {
        guard !isUploading else { return }
        isUploading = true
        loadingIndicator.startAnimating()
        
        NetworkManager.shared.uploadFile(image: image) { [weak self] result in
            self?.isUploading = false
            self?.loadingIndicator.stopAnimating()
            
            switch result {
            case .success(let response):
                self?.view.makeToast("上传成功")
                self?.fetchImages()
            case .failure(let error):
                self?.view.makeToast("上传失败：\(error.localizedDescription)")
            }
        }
    }
}

// MARK: - UICollectionViewDataSource
extension ImagePreviewViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCell", for: indexPath) as! ImageCell
        let imageInfo = images[indexPath.item]
        cell.configure(with: imageInfo)
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension ImagePreviewViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let imageInfo = images[indexPath.item]
        // TODO: 实现图片预览功能
    }
}

// MARK: - TLPhotosPickerViewControllerDelegate
extension ImagePreviewViewController: TLPhotosPickerViewControllerDelegate {
    func dismissPhotoPicker(withTLPHAssets: [TLPHAsset]) {
        guard let asset = withTLPHAssets.first,
              let image = asset.fullResolutionImage else { return }
        uploadImage(image)
    }
    
    func dismissPhotoPicker(withPHAssets: [PHAsset]) {
        // 处理 PHAsset 类型的图片
    }
    
    func photoPickerDidCancel() {
        // 用户取消选择
    }
    
    func canSelect(asset: PHAsset) -> Bool {
        return true
    }
    
    func didExceedMaximumNumberOfSelection(picker: TLPhotosPickerViewController) {
        view.makeToast("最多只能选择9张图片")
    }
}

// MARK: - ImageCell
class ImageCell: UICollectionViewCell {
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func configure(with imageInfo: FileInfo) {
        let baseURL = "http://localhost:5001"
        if let token = UserManager.shared.token,
           let url = URL(string: baseURL + imageInfo.preview_url + "?token=" + token) {
            imageView.kf.setImage(with: url)
        }
    }
} 
