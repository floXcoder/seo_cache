# frozen_string_literal: true

require 'simplecov'
SimpleCov.start

require 'bundler/setup'
require 'rspec'
require 'webmock/rspec'
require 'seo_cache'

WebMock.disable_net_connect!(allow_localhost: true, allow: ['chromedriver.storage.googleapis.com'])

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  # config.disable_monkey_patching!

  config.expect_with :rspec do |conf|
    conf.syntax = :expect
  end
end
