platform :ios, '13.0'

install! 'cocoapods', :deterministic_uuids => false

target 'Inslulu' do
  use_frameworks!

  # 网络请求
  pod 'Alamofire'
  
  # 图片加载和缓存
  pod 'Kingfisher'
  
  # 图片选择器
  pod 'TLPhotoPicker'
  
  # 图片预览
  pod 'SKPhotoBrowser'
  
  # UI 组件
  pod 'SnapKit'
  pod 'IQKeyboardManagerSwift'
  
  # 工具类
  pod 'SwiftyJSON'
  pod 'KeychainAccess'
  
  # 提示框
  pod 'Toast-Swift'
end 

post_install do |installer|
  installer.generated_projects.each do |project|
      project.targets.each do |target|
          target.build_configurations.each do |config|
              config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
          end
      end
  end
end