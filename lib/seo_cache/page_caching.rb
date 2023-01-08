# frozen_string_literal: true

module SeoCache
  class PageCaching
    def initialize
      @redis = nil

      initialize_memory_cache if SeoCache.memory_cache?
    end

    def initialize_memory_cache
      uri    = URI.parse(SeoCache.redis_url)
      @redis = Redis::Namespace.new(SeoCache.redis_namespace, redis: Redis.new(host: uri.host, port: uri.port, password: uri.password, db: SeoCache.redis_db_index, connect_timeout: 1, timeout: 1), warnings: false)
    end

    def get(path, locale_domain = nil, extension = nil)
      @redis.get(cache_path(path, locale_domain, extension)) if SeoCache.memory_cache? && @redis
    end

    def cache(content, path, locale_domain = nil, extension = nil, gzip = Zlib::BEST_COMPRESSION)
      instrument :write_page, path do
        if SeoCache.memory_cache? && @redis
          write_to_memory(content, cache_path(path, locale_domain, extension))
        else
          write_to_disk(content, cache_path(path, locale_domain, extension), gzip)
        end
      end
    end

    def expire(path, locale_domain = nil, extension = nil)
      instrument :expire_page, path do
        delete(cache_path(path, locale_domain, extension))
      end
    end

    def cache_exists?(path, locale_domain = nil, extension = nil)
      if SeoCache.memory_cache? && @redis
        @redis.exists?(cache_path(path, locale_domain, extension))
      else
        File.exist?(cache_path(path, locale_domain, extension))
      end
    end

    private

    def cache_directory
      SeoCache.cache_path
    end

    def default_extension
      SeoCache.cache_extension
    end

    def cache_file(path, locale_domain, extension)
      name = if path.empty? || path =~ %r{\A/+\z}
               '/index'
             else
               URI::Parser.new.unescape(path.chomp('/'))
             end

      name = "#{locale_domain}/#{name}" if locale_domain

      name += extension || default_extension if File.extname(name).empty?

      name
    end

    def cache_path(path, locale_domain = nil, extension = nil)
      File.join(cache_directory, cache_file(path, locale_domain, extension))
    end

    def write_to_memory(content, path)
      @redis&.set(path, content)
    end

    def write_to_disk(content, path, gzip)
      FileUtils.makedirs(File.dirname(path)) unless File.directory?(File.dirname(path))
      File.open(path, 'wb+') { |f| f.write(content) }

      Zlib::GzipWriter.open(path + '.gz', gzip) { |f| f.write(content) } if gzip
    end

    def disk_delete(path)
      File.delete(path) if File.exist?(path)
      File.delete(path + '.gz') if File.exist?(path + '.gz')
    end

    def memory_delete(path)
      @redis.del(path) if @redis&.exists?(path)
    end

    def instrument(name, path)
      ActiveSupport::Notifications.instrument("#{name}.seo_cache", path: path) { yield }
    end
  end
end
