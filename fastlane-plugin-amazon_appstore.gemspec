lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/amazon_appstore/version'

Gem::Specification.new do |spec|
  spec.name          = 'fastlane-plugin-amazon_appstore'
  spec.version       = Fastlane::AmazonAppstore::VERSION
  spec.author        = 'ntsk'
  spec.email         = 'contact@ntsk.jp'

  spec.summary       = 'Upload apps to Amazon Appstore'
  spec.homepage      = "https://github.com/ntsk/fastlane-plugin-amazon_appstore"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*"] + %w(README.md LICENSE)
  spec.require_paths = ['lib']

  # Match fastlane's Ruby requirement for ecosystem compatibility
  spec.required_ruby_version = '>= 2.6'

  # Don't add a dependency to fastlane or fastlane_re
  # since this would cause a circular dependency

  # Faraday 1.x for compatibility with fastlane ecosystem
  spec.add_runtime_dependency('faraday', '~> 1.0')
  spec.add_runtime_dependency('faraday_middleware', '~> 1.0')

  spec.add_development_dependency('bundler', '>= 1.12.0', '< 3.0.0')
  spec.add_development_dependency('fastlane', '>= 2.199.0')
  spec.add_development_dependency('pry', '~> 0.14')
  spec.add_development_dependency('rake', '~> 13.0')
  spec.add_development_dependency('rspec', '~> 3.12')
  spec.add_development_dependency('rspec_junit_formatter', '~> 0.6')
  spec.add_development_dependency('rubocop', '~> 1.50', '< 1.51')
  spec.add_development_dependency('rubocop-performance', '~> 1.17')
  spec.add_development_dependency('rubocop-require_tools', '~> 0.1')
  spec.add_development_dependency('simplecov', '~> 0.22')

  spec.metadata['rubygems_mfa_required'] = 'true'
end
