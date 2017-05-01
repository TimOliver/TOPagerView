Pod::Spec.new do |s|
  s.name     = 'TOPagerView'
  s.version  = '0.0.1'
  s.license  =  { :type => 'MIT', :file => 'LICENSE' }
  s.summary  = 'An Objective-C framework that wraps libdsm, an SMB client library.'
  s.homepage = 'https://github.com/TimOliver/TOPagerView'
  s.author   = 'Tim Oliver'
  s.source   = { :git => 'https://github.com/TimOliver/TOPagerView.git', :tag => s.version }
  s.platform = :ios, '5.0'
  s.source_files = 'TOPagerView/**/*.{h,m}'
  s.requires_arc = true
end