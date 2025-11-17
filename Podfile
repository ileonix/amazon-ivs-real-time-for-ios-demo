# Uncomment the next line to define a global platform for your project
platform :ios, '15.0'

target 'IVS Real-time' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for IVS Real-time
  
  # Pods for Ecommerce API
  pod 'Socket.IO-Client-Swift', '~> 16.1.1'
  
  # LiveCommerceSDK - Local development (includes Amazon IVS dependencies)
  pod 'LiveCommerceSDK', :path => '../LiveCommerceSDK'
  
  # Alternative: Use from git repository
  # pod 'LiveCommerceSDK', :git => 'https://github.com/ileonix/LiveCommerceSDK.git', :tag => '1.0.0'
  
  # Alternative: Use specific subspecs only
  # pod 'LiveCommerceSDK/Core', :path => '../LiveCommerceSDK'
  # pod 'LiveCommerceSDK/UI', :path => '../LiveCommerceSDK'
  # pod 'LiveCommerceSDK/Network', :path => '../LiveCommerceSDK'
  
  # Debug tool
  pod 'Wormholy', :configurations => ['Debug']

#  target 'IVS Real-timeTests' do
#    inherit! :search_paths
#    # Pods for testing
#  end
#
#  target 'IVS Real-timeUITests' do
#    # Pods for testing
#  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      config.build_settings['SWIFT_VERSION'] = '5.9'
    end
  end
end
