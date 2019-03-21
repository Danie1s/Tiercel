
Pod::Spec.new do |s|
  s.name             = 'Tiercel'
  s.version          = '2.0.3'
  s.swift_version = '4.2'
  s.summary          = 'Tiercel is a lightweight, pure-Swift download framework.'


  s.homepage         = 'https://github.com/Danie1s/Tiercel'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Daniels' => '176516837@qq.com' }
  s.source           = { :git => 'https://github.com/Danie1s/Tiercel.git', :tag => s.version.to_s }

  s.ios.deployment_target = '8.0'

  s.source_files = 'Tiercel/**/*.swift'
  s.requires_arc = true
  s.frameworks = 'CFNetwork'
  s.pod_target_xcconfig = { 'SWIFT_VERSION' => '4.2' }

end
