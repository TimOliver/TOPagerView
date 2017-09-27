Pod::Spec.new do |s|
  s.name     = 'TOPagerView'
  s.version  = '0.0.2'
  s.license  =  { :type => 'MIT', :file => 'LICENSE' }
  s.summary  = 'A UIScrollView subclass that allows paged horizontal swiping with a re-use mechansim similar to UITableView.'
  s.homepage = 'https://github.com/TimOliver/TOPagerView'
  s.author   = 'Tim Oliver'
  s.source   = { :git => 'https://github.com/TimOliver/TOPagerView.git', :tag => s.version }
  s.platform = :ios, '5.0'
  s.source_files = 'TOPagerView/**/*.{h,m}'
  s.requires_arc = true
end
