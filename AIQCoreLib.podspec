Pod::Spec.new do |s|
  s.name             = "AIQCoreLib"
  s.version          = "1.5.1"
  s.summary          = "Allows access to AppearIQ cloud services."
  s.homepage         = "https://github.com/appear/AIQCoreLib"
  s.license          = 'MIT'
  s.author           = { "Appear Networks AB" => "ios@appearnetworks.com" }
  s.source           = { :git => "https://github.com/appear/AIQCoreLib.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/appear'

  s.platform     = :ios, '8.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'
  s.resource_bundles = {
    'AIQCoreLib' => ['Pod/Assets/*.png']
  }

  s.public_header_files = 'Pod/Classes/**/AIQ*.h', 'Pod/Classes/**/NS*.h', 'Pod/Classes/**/DD*.h'
  s.dependency 'FMDB', '2.5'
  s.dependency 'FMDBMigrationManager', '1.3.4'
  s.dependency 'CocoaLumberjack', '1.9.2'
  s.dependency 'ZipArchive', '1.4.0'
  s.dependency 'GZIP', '1.1.1'
  s.dependency 'Reachability', '3.2'
end
