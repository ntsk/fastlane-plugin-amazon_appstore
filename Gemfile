source('https://rubygems.org')

gem 'bundler', '>= 1.12.0', '< 5.0.0'
gem 'fastlane', '>= 2.199.0'
gem 'pry', '~> 0.14'
gem 'rake', '~> 13.0'
gem 'rspec', '~> 3.12'
gem 'rspec_junit_formatter', '~> 0.6'
gem 'rubocop', '1.91.0'
gem 'rubocop-performance', '~> 1.17'
gem 'rubocop-require_tools', '~> 0.1'
gem 'simplecov', '~> 0.22'

gemspec

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
