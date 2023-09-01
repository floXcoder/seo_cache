lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'seo_cache/version'

Gem::Specification.new do |spec|
  spec.name    = 'seo_cache'
  spec.version = SeoCache::VERSION
  spec.authors = ['FloXcoder']
  spec.email   = ['flo@l-x.fr']

  spec.summary     = 'Cache dedicated for SEO with Javascript rendering'
  spec.description = 'Specific cache for bots to optimize time to first byte and render Javascript on server side.'
  spec.homepage    = 'https://github.com/floXcoder/seo_cache'
  spec.license     = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'rack', '~> 2'
  spec.add_dependency 'activesupport', '>= 5'
  spec.add_dependency 'railties', '>= 5'
  spec.add_dependency 'redis', '~> 4'
  spec.add_dependency 'redis-namespace', '~> 1'
  spec.add_dependency 'selenium-webdriver', '>= 3'

  spec.add_development_dependency 'bundler', '~> 2'
  spec.add_development_dependency 'rake', '~> 13'
  spec.add_development_dependency 'rspec', '~> 3'
  spec.add_development_dependency 'simplecov', '~> 0.17'
  spec.add_development_dependency 'webmock', '~> 3'
end
