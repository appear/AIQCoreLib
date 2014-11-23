Pod::Spec.new do |s|
  s.name             = "AIQCoreLib"
  s.version          = "0.0.1"
  s.summary          = "Allows access to AppearIQ cloud services."
  s.homepage         = "https://github.com/appear/AIQCoreLib"
  s.license          = 'MIT'
  s.author           = { "Appear Networks AB" => "ios@appearnetworks.com" }
  s.source           = { :git => "https://github.com/appear/AIQCoreLib.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/appear'

  s.platform     = :ios, '7.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes'

  s.public_header_files = 'Pod/Classes/AIQ*.h'
  s.dependency 'AFNetworking'
  s.dependency 'CocoaLumberjack'
  s.dependency 'FMDB'
  s.dependency 'FMDBMigrationManager'
end
