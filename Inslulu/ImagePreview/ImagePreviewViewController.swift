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
    
    private lazy var deleteButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("删除", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemRed
        button.layer.cornerRadius = 8
        button.isHidden = true
        button.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("取消", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemGray
        button.layer.cornerRadius = 8
        button.isHidden = true
        button.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
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
    private var uploadQueue: [UIImage] = []
    private var currentUploadIndex = 0
    private var selectedIndexes: Set<Int> = []
    private var isSelectionMode = false
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestures()
        fetchImages()
    }
    
    // MARK: - Setup
    private func setupUI() {
        title = "图片预览"
        view.backgroundColor = .white
        
        view.addSubview(collectionView)
        view.addSubview(addButton)
        view.addSubview(deleteButton)
        view.addSubview(cancelButton)
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
        
        deleteButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(20)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-20)
            make.height.equalTo(44)
            make.width.equalTo(100)
        }
        
        cancelButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-20)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-20)
            make.height.equalTo(44)
            make.width.equalTo(100)
        }
        
        loadingIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
    
    private func setupGestures() {
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        collectionView.addGestureRecognizer(longPressGesture)
    }
    
    // MARK: - Actions
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            let point = gesture.location(in: collectionView)
            if let indexPath = collectionView.indexPathForItem(at: point) {
                enterSelectionMode()
                toggleSelection(at: indexPath.item)
            }
        }
    }
    
    private func enterSelectionMode() {
        isSelectionMode = true
        selectedIndexes.removeAll()
        addButton.isHidden = true
        deleteButton.isHidden = false
        cancelButton.isHidden = false
        collectionView.reloadData()
    }
    
    private func exitSelectionMode() {
        isSelectionMode = false
        selectedIndexes.removeAll()
        addButton.isHidden = false
        deleteButton.isHidden = true
        cancelButton.isHidden = true
        collectionView.reloadData()
    }
    
    private func toggleSelection(at index: Int) {
        if selectedIndexes.contains(index) {
            selectedIndexes.remove(index)
        } else {
            selectedIndexes.insert(index)
        }
        collectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
    }
    
    @objc private func deleteButtonTapped() {
        guard !selectedIndexes.isEmpty else { return }
        
        let alert = UIAlertController(title: "提示", message: "确定要删除选中的图片吗？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .destructive) { [weak self] _ in
            self?.deleteSelectedImages()
        })
        present(alert, animated: true)
    }
    
    @objc private func cancelButtonTapped() {
        exitSelectionMode()
    }
    
    private func deleteSelectedImages() {
        loadingIndicator.startAnimating()
        
        let group = DispatchGroup()
        var successCount = 0
        var failureCount = 0
        
        for index in selectedIndexes {
            guard index < images.count else { continue }
            let imageInfo = images[index]
            
            // 从 preview_url 中提取文件名
            let filename = imageInfo.preview_url.components(separatedBy: "/").last ?? imageInfo.filename
            
            group.enter()
            NetworkManager.shared.deleteFile(filename: filename) { result in
                switch result {
                case .success:
                    successCount += 1
                case .failure(let error):
                    failureCount += 1
                    print("删除文件失败: \(error.localizedDescription), 文件名: \(filename)")
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.loadingIndicator.stopAnimating()
            self?.exitSelectionMode()
            self?.fetchImages()
            
            if successCount > 0 {
                self?.view.makeToast("成功删除\(successCount)张图片")
            }
            if failureCount > 0 {
                self?.view.makeToast("\(failureCount)张图片删除失败")
            }
        }
    }
    
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
    
    private func uploadImages(_ images: [UIImage]) {
        guard !isUploading else { return }
        isUploading = true
        loadingIndicator.startAnimating()
        
        // 准备上传队列
        uploadQueue = images
        currentUploadIndex = 0
        
        // 开始上传第一张图片
        uploadNextImage()
    }
    
    private func uploadNextImage() {
        guard currentUploadIndex < uploadQueue.count else {
            // 所有图片上传完成
            isUploading = false
            loadingIndicator.stopAnimating()
            view.makeToast("所有图片上传完成")
            fetchImages()
            return
        }
        
        let image = uploadQueue[currentUploadIndex]
        let timestamp = Int(Date().timeIntervalSince1970)
        let imageName = "image_\(timestamp)_\(currentUploadIndex + 1).jpg"
        
        NetworkManager.shared.uploadFile(image: image, filename: imageName) { [weak self] result in
            switch result {
            case .success(let response):
                self?.view.makeToast("第\(self?.currentUploadIndex ?? 0 + 1)张图片上传成功")
                self?.currentUploadIndex += 1
                self?.uploadNextImage()
            case .failure(let error):
                self?.view.makeToast("第\(self?.currentUploadIndex ?? 0 + 1)张图片上传失败：\(error.localizedDescription)")
                self?.currentUploadIndex += 1
                self?.uploadNextImage()
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
        cell.configure(with: imageInfo, isSelected: selectedIndexes.contains(indexPath.item))
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension ImagePreviewViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if isSelectionMode {
            toggleSelection(at: indexPath.item)
        } else {
            // 预览图片
            var images: [SKPhoto] = []
            for imageInfo in self.images {
                if let url = URL(string: NetworkManager.shared.imageBaseURL + imageInfo.preview_url + "?token=" + (UserManager.shared.token ?? "")) {
                    let photo = SKPhoto.photoWithImageURL(url.absoluteString)
                    images.append(photo)
                }
            }
            
            let browser = SKPhotoBrowser(photos: images)
            browser.initializePageIndex(indexPath.item)
            present(browser, animated: true)
        }
    }
}

// MARK: - TLPhotosPickerViewControllerDelegate
extension ImagePreviewViewController: TLPhotosPickerViewControllerDelegate {
    func dismissPhotoPicker(withTLPHAssets: [TLPHAsset]) {
        let images = withTLPHAssets.compactMap { $0.fullResolutionImage }
        if !images.isEmpty {
            uploadImages(images)
        }
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
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private let selectionView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        view.isHidden = true
        return view
    }()
    
    private let checkmarkImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "checkmark.circle.fill")
        imageView.tintColor = .white
        imageView.isHidden = true
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
        contentView.addSubview(selectionView)
        contentView.addSubview(checkmarkImageView)
        
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        selectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        checkmarkImageView.snp.makeConstraints { make in
            make.top.right.equalToSuperview().inset(8)
            make.width.height.equalTo(24)
        }
    }
    
    func configure(with imageInfo: FileInfo, isSelected: Bool = false) {
        let baseURL = NetworkManager.shared.imageBaseURL
        if let token = UserManager.shared.token,
           let url = URL(string: baseURL + imageInfo.preview_url + "?token=" + token) {
            imageView.kf.setImage(with: url)
        }
        
        selectionView.isHidden = !isSelected
        checkmarkImageView.isHidden = !isSelected
    }
} 
