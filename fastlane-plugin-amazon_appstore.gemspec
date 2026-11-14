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

  # Matches the minimum Ruby version supported by fastlane
  spec.required_ruby_version = '>= 3.2'

  # Don't add a dependency to fastlane or fastlane_re
  # since this would cause a circular dependency

  spec.add_runtime_dependency('faraday', '>= 1.0')
  spec.add_runtime_dependency('faraday-multipart', '>= 1.0')

  spec.metadata['rubygems_mfa_required'] = 'true'
end
