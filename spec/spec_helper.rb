# frozen_string_literal: true

require 'pry'
require 'webmock/rspec'
require 'addressable'
require 'vcr'
require 'faker'
require 'delorean'
require_relative('../scraper')
require_relative('runners/shared_examples')

VCR.configure do |c|
  c.cassette_library_dir = 'spec/vcr_cassettes'
  c.hook_into :webmock
end

RSpec.shared_context 'mock runners' do
  after(:each) do
    # Reset the whitelist
    Jacaranda.parse([])
    # Reset webmock after every test
    WebMock.reset!
  end
end

RSpec.shared_context 'ScraperWiki' do
  before(:each) do
    # Create a new connection to new sqlite
    ScraperWiki.close_sqlite
    ScraperWiki.config = { db: ':memory:' }
    ScraperWiki.sqlite_magic_connection.execute('PRAGMA database_list')
  end

  after(:each) do
    # Reset sqlite connection
    ScraperWiki.close_sqlite
    ScraperWiki.instance_variable_set(:@config, nil)
    ScraperWiki.instance_variable_set(:@sqlite_magic_connection, nil)
  end
end

RSpec.configure do |config|
  # Use color not only in STDOUT but also in pagers and files
  config.tty = true
  # Time-based test helper
  config.include Delorean

  # Set up a clean database for every test
  config.include_context 'ScraperWiki'

  # Set up mock runners for testing runners in isolation
  config.include_context 'mock runners'
end

def restore_env
  ENV.replace(@original) if @original
  @original = nil
end

def unset_environment_variable(name)
  @original ||= ENV.to_hash
  ENV.delete(name)
end

def set_environment_variable(name, value)
  @original ||= ENV.to_hash
  ENV[name] = value
end

def puts(*args); end
