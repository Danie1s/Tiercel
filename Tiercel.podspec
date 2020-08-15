
Pod::Spec.new do |s|
  s.name             = 'Tiercel'
  s.version          = '3.2.0'
  s.swift_version   = '5.0'
  s.summary          = 'Tiercel is a lightweight, pure-Swift download framework.'


  s.homepage         = 'https://github.com/Danie1s/Tiercel'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Daniels' => '176516837@qq.com' }
  s.source           = { :git => 'https://github.com/Danie1s/Tiercel.git', :tag => s.version.to_s }

  s.ios.deployment_target = '10.0'
  s.osx.deployment_target = '10.14'

  s.source_files = 'Sources/**/*.swift'
  s.requires_arc = true

  s.ios.frameworks = 'Foundation', 'UIKit'
  s.osx.frameworks = 'Foundation', 'AppKit'
end
