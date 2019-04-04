# frozen_string_literal: true

require 'spec_helper'

require 'seo_cache/populate_cache'

describe SeoCache::PopulateCache do
  before(:all) do
    SeoCache.cache_mode      = 'memory'
    SeoCache.redis_namespace = 'seo_cache_test'
    SeoCache.chrome_path     = '/usr/bin/chromium-browser'
  end

  let(:populate_cache) { described_class }

  let(:redis) {
    uri = URI.parse(SeoCache.redis_url)
    Redis::Namespace.new(SeoCache.redis_namespace, redis: Redis.new(host: uri.host, port: uri.port, password: uri.password, connect_timeout: 1, timeout: 1), warnings: false)
  }

  it 'populates cache with the given paths' do
    redis.del('/index.html')

    populate_cache.new('https://example.com', ['/']).perform
  end

  it 'reuses the populated cache with the given paths' do
    previous_content = redis.get('/index.html')

    populate_cache.new('https://example.fr', ['/']).perform

    expect(previous_content).to eq(redis.get('/index.html'))
  end

  it 'forces cache to repopulate with the given paths' do
    previous_content = redis.get('/index.html')

    populate_cache.new('https://example.fr', ['/'], force_cache: true).perform

    expect(previous_content).not_to eq(redis.get('/index.html'))
  end
end
