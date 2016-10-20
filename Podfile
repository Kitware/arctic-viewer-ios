# Uncomment this line to define a global platform for your project
platform :ios, '10.0'
use_frameworks!

target 'ArcticViewer' do
	pod 'NVHTarGzip', '1.0.1'
	pod 'SDWebImage', '3.8.2'
	pod 'SSZipArchive', '1.6.1'
	pod 'Swifter', '1.3.2'
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['SWIFT_VERSION'] = '3.0'
        end
    end
end
