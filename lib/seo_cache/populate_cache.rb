# frozen_string_literal: true

require 'seo_cache/page_caching'
require 'seo_cache/page_render'

module SeoCache
  class PopulateCache
    def initialize(host, paths, options = {})
      @host = host
      @paths = paths
      @page_render = PageRender.new
      @page_caching = PageCaching.new

      @force_cache = options.fetch(:force_cache, false)
    end

    def perform
      @paths.each do |path|
        next if @page_caching.cache_exists?(path) && !@force_cache

        url = @host + path
        url += if path.url.end_with?('?')
                 '&'
               else
                 '?'
               end
        url += "#{SeoCache.prerender_url_param}=true"

        page_source = @page_render.get(url, false)
        @page_caching.cache(page_source, path)
      end

      @page_render.close_connection
    end
  end
end
