# frozen_string_literal: true

require 'spec_helper'

require 'seo_cache/page_render'

describe SeoCache::PageCaching do
  let(:page_caching) { described_class }

  context 'Memory caching' do
    before(:all) do
      SeoCache.cache_mode      = 'memory'
      SeoCache.cache_path      = ''
      SeoCache.redis_namespace = 'seo_cache_test'
    end

    let(:redis) {
      uri = URI.parse(SeoCache.redis_url)
      Redis::Namespace.new(SeoCache.redis_namespace, redis: Redis.new(host: uri.host, port: uri.port, password: uri.password, connect_timeout: 1, timeout: 1), warnings: false)
    }

    let(:cache_path) { '/memory_test' }

    it 'caches page in memory' do
      memory_path = SeoCache.cache_path + cache_path + SeoCache.cache_extension

      page_caching.new.cache('<html>Data to cache</html>', cache_path)

      expect(redis.exists?(memory_path)).to be true
      expect(redis.get(memory_path)).to include('Data to cache')
    end

    it 'caches new page content' do
      memory_path = SeoCache.cache_path + cache_path + SeoCache.cache_extension
      expect(redis.exists?(memory_path)).to be true

      page_caching.new.cache('<html>Data updated to cache</html>', cache_path)

      expect(redis.exists?(memory_path)).to be true
      expect(redis.get(memory_path)).to include('Data updated to cache')
    end

    it 'checks if path is cached' do
      memory_path = SeoCache.cache_path + cache_path + SeoCache.cache_extension
      expect(redis.exists?(memory_path)).to be true

      expect(page_caching.new.cache_exists?(cache_path)).to be true
      expect(page_caching.new.cache_exists?('/unknown_path')).to be false
    end
  end

  context 'Disk caching' do
    before(:all) do
      SeoCache.cache_mode = 'disk'
      SeoCache.cache_path = './spec/data/page_caching'
    end

    let(:cache_path) { '/disk_test' }

    it 'caches page on disk' do
      file_path = SeoCache.cache_path + cache_path + SeoCache.cache_extension

      page_caching.new.cache('<html>Data to cache</html>', cache_path)

      expect(File.exist?(file_path)).to be true
      expect(File.readlines(file_path).first).to include('Data to cache')
    end

    it 'caches gzip page on disk by default' do
      page_caching.new.cache('<html>Index data to cache</html>', cache_path)

      expect(File.exist?(SeoCache.cache_path + cache_path + SeoCache.cache_extension + '.gz')).to be true
    end

    it 'caches new page content' do
      file_path = SeoCache.cache_path + cache_path + SeoCache.cache_extension
      expect(File.exist?(file_path)).to be true

      page_caching.new.cache('<html>Data updated to cache</html>', cache_path)

      expect(File.exist?(file_path)).to be true
      expect(File.readlines(file_path).first).to include('Data updated to cache')
    end

    it 'checks if path is cached' do
      file_path = SeoCache.cache_path + cache_path + SeoCache.cache_extension
      expect(File.exist?(file_path)).to be true

      expect(page_caching.new.cache_exists?(cache_path)).to be true
      expect(page_caching.new.cache_exists?('/unknown_path')).to be false
    end
  end
end
