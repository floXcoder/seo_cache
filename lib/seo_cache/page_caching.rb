# frozen_string_literal: true

module SeoCache
  class PageCaching
    def initialize
      @redis = nil

      initialize_memory_cache if SeoCache.memory_cache?
    end

    def initialize_memory_cache
      uri    = URI.parse(SeoCache.redis_url)
      @redis = Redis::Namespace.new(SeoCache.redis_namespace, redis: Redis.new(host: uri.host, port: uri.port, password: uri.password, connect_timeout: 1, timeout: 1), warnings: false)
    end

    def get(path, extension = nil)
      @redis.get(cache_path(path, extension)) if SeoCache.memory_cache? && @redis
    end

    def cache(content, path, extension = nil, gzip = Zlib::BEST_COMPRESSION)
      instrument :write_page, path do
        if SeoCache.memory_cache? && @redis
          write_to_memory(content, cache_path(path, extension))
        else
          write_to_disk(content, cache_path(path, extension), gzip)
        end
      end
    end

    def expire(path)
      instrument :expire_page, path do
        delete(cache_path(path))
      end
    end

    def cache_exists?(path)
      if SeoCache.memory_cache? && @redis
        @redis.exists(cache_path(path))
      else
        File.exist?(cache_path(path))
      end
    end

    private

    def cache_directory
      SeoCache.cache_path
    end

    def default_extension
      SeoCache.cache_extension
    end

    def cache_file(path, extension)
      name = if path.empty? || path =~ %r{\A/+\z}
               '/index'
             else
               URI::Parser.new.unescape(path.chomp('/'))
             end

      if File.extname(name).empty?
        name + (extension || default_extension)
      else
        name
      end
    end

    def cache_path(path, extension = nil)
      File.join(cache_directory, cache_file(path, extension))
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
