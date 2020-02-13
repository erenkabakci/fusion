Pod::Spec.new do |spec|
  spec.name         = "fusion"
  spec.version      = "0.1.0"
  spec.summary      = "reactive network framework for Swift"
  spec.homepage     = "https://github.com/erenkabakci/fusion"
  spec.license      = "MIT"
  spec.author       = "Eren Kabakçı"
  spec.platform     = :ios, "13.0"
  spec.ios.frameworks = 'Combine', 'Foundation'
  spec.source       = { :git => "https://github.com/erenkabakci/fusion.git", tag: spec.version.to_s }
  spec.source_files  = "Sources/**/*.{swift}"
  spec.swift_version = "5"
  spec.requires_arc = true
end
