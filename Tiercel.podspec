
Pod::Spec.new do |s|
  s.name             = 'Tiercel'
  s.version          = '3.2.8'
  s.swift_version   = '5.0'
  s.summary          = 'Tiercel is a lightweight, pure-Swift download framework.'


  s.homepage         = 'https://github.com/Danie1s/Tiercel'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Daniels' => '176516837@qq.com' }
  s.source           = { :git => 'https://github.com/Danie1s/Tiercel.git', :tag => s.version.to_s }

  s.ios.deployment_target = '12.0'

  s.source_files = 'Sources/**/*.swift'
  s.requires_arc = true

end
