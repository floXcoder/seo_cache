# frozen_string_literal: true

require 'seo_cache/page_caching'
require 'seo_cache/page_render'

module SeoCache
  class PopulateCache
    def initialize(host, paths, options = {})
      @host         = host
      @paths        = paths
      @page_render  = PageRender.new
      @page_caching = PageCaching.new

      @force_cache      = options.fetch(:force_cache, false)
      @with_locale_keys = options.fetch(:with_locale_keys, false)
    end

    def perform
      if @with_locale_keys
        @paths.each do |locale, paths|
          paths.each do |path|
            generate_cache(path, locale)
          end
        end
      else
        @paths.each do |path|
          generate_cache(path)
        end
      end

    ensure
      @page_render.close_connection
    end

    private

    def generate_cache(path, locale = nil)
      return if @page_caching.cache_exists?(path) && !@force_cache

      url = @host + path
      url += path.include?('?') ? '&' : '?'
      url += "#{SeoCache.prerender_url_param}=true"

      page_source = @page_render.get(url, false)
      return unless page_source

      path_cache_key = locale ? "/#{locale}#{path}" : path
      @page_caching.cache(page_source, path_cache_key)
    end
  end
end
