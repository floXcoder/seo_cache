# frozen_string_literal: true

require 'spec_helper'

require 'seo_cache/populate_cache'

describe SeoCache::PopulateCache do
  let(:populate_cache) { described_class }

  context 'Memory caching' do
    before(:all) do
      SeoCache.cache_mode            = 'memory'
      SeoCache.cache_path            = ''
      SeoCache.redis_namespace       = 'seo_cache_test'
      SeoCache.chrome_path           = '/usr/bin/chromium-browser'
      SeoCache.chrome_debugging_port = 9222
    end

    let(:redis) {
      uri = URI.parse(SeoCache.redis_url)
      Redis::Namespace.new(SeoCache.redis_namespace, redis: Redis.new(host: uri.host, port: uri.port, password: uri.password, connect_timeout: 1, timeout: 1), warnings: false)
    }

    let(:cache_path) { '/' }

    it 'populates cache with the given paths' do
      redis.del('/index.html')

      populate_cache.new('https://example.com', [cache_path]).perform
    end

    it 'reuses the populated cache with the given paths' do
      previous_content = redis.get('/index.html')

      populate_cache.new('https://google.com', [cache_path]).perform

      expect(previous_content).to eq(redis.get('/index.html'))
    end

    it 'forces cache to repopulate with the given paths' do
      previous_content = redis.get('/index.html')

      populate_cache.new('https://google.com', [cache_path], force_cache: true).perform

      expect(previous_content).not_to eq(redis.get('/index.html'))
    end
  end

  context 'Disk caching' do
    before(:all) do
      SeoCache.cache_mode            = 'disk'
      SeoCache.cache_path            = './spec/data/populate_cache'
      SeoCache.chrome_path           = '/usr/bin/chromium-browser'
      SeoCache.chrome_debugging_port = 9222
    end

    let(:cache_path) { '/disk_test' }

    it 'populates cache with the given paths' do
      file_path = SeoCache.cache_path + cache_path + SeoCache.cache_extension
      File.delete(file_path) if File.exist?(file_path)

      populate_cache.new('https://example.com', [cache_path]).perform

      expect(File.exist?(file_path)).to be true
      expect(File.readlines(file_path)[1]).to include('Example Domain')
    end

    it 'reuses the populated cache with the given paths' do
      file_path = SeoCache.cache_path + cache_path + SeoCache.cache_extension
      expect(File.exist?(file_path)).to be true

      expect(File.readlines(file_path)[1]).to include('Example Domain')

      populate_cache.new('https://google.com', [cache_path]).perform

      expect(File.readlines(file_path)[1]).to include('Example Domain')
    end

    it 'forces cache to repopulate with the given paths' do
      file_path = SeoCache.cache_path + cache_path + SeoCache.cache_extension
      expect(File.exist?(file_path)).to be true

      expect(File.readlines(file_path)[1]).to include('Example Domain')

      populate_cache.new('https://google.com', [cache_path], force_cache: true).perform

      expect(File.readlines(file_path)[4]).to include('www.google.com')
    end
  end
end
