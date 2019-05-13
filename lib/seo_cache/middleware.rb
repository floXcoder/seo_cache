# frozen_string_literal: true

require 'seo_cache/page_caching'
require 'seo_cache/page_render'

module SeoCache
  class Middleware
    def initialize(app, options = {})
      @options                  = options
      @extensions_to_ignore     = SeoCache.extensions_to_ignore
      @crawler_user_agents      = SeoCache.crawler_user_agents

      @app = app

      @page_caching = PageCaching.new
    end

    def call(env)
      if should_show_prerendered_page(env)
        cached_response = before_render(env)

        return cached_response.finish if cached_response.present?

        SeoCache.log('missed cache : ' + Rack::Request.new(env).path) if SeoCache.log_missed_cache

        if SeoCache.prerender_service_url.present?
          prerendered_response = get_prerendered_page_response(env)
          if prerendered_response
            response = build_rack_response_from_prerender(prerendered_response.body)
            after_render(env, prerendered_response)
            return response.finish
          end
        else
          Thread.new do
            prerendered_data = page_render(env)
            after_render(env, prerendered_data) if prerendered_data
          end
        end
      end

      @app.call(env)
    end

    def should_show_prerendered_page(env)
      user_agent                     = env['HTTP_USER_AGENT']
      buffer_agent                   = env['HTTP_X_BUFFERBOT']
      is_requesting_prerendered_page = false

      return false unless user_agent

      return false if env['REQUEST_METHOD'] != 'GET'

      request = Rack::Request.new(env)
      query_params = Rack::Utils.parse_query(request.query_string)

      # If it is the generated page...don't prerender
      return false if query_params.has_key?(SeoCache.prerender_url_param)

      return false if SeoCache.blacklist_params.present? && SeoCache.blacklist_params.any? { |param| query_params.has_key?(param) }

      is_requesting_prerendered_page = true if Rack::Utils.parse_query(request.query_string).has_key?('_escaped_fragment_') || Rack::Utils.parse_query(request.query_string).has_key?(SeoCache.force_cache_url_param)

      # if it is a bot...show prerendered page
      is_requesting_prerendered_page = true if @crawler_user_agents.any? { |crawler_user_agent| user_agent.downcase.include?(crawler_user_agent.downcase) }

      # if it is BufferBot...show prerendered page
      is_requesting_prerendered_page = true if buffer_agent

      # if it is a bot and is requesting a resource...don't prerender
      return false if @extensions_to_ignore.any? { |extension| request.fullpath.include? extension }

      # if it is a bot and not requesting a resource and is not whitelisted...don't prerender
      return false if SeoCache.whitelist_urls.present? && SeoCache.whitelist_urls.all? { |whitelisted| !Regexp.new(whitelisted).match(request.fullpath) }

      # if it is a bot and not requesting a resource and is blacklisted(url or referer)...don't prerender
      blacklisted_url = SeoCache.blacklist_urls.present? && SeoCache.blacklist_urls.any? do |blacklisted|
        regex = Regexp.new(blacklisted)

        blacklisted_url     = regex.match(request.fullpath)
        blacklisted_referer = request.referer ? regex.match(request.referer) : false

        blacklisted_url || blacklisted_referer
      end
      return false if blacklisted_url

      SeoCache.log('force cache : ' + request.path) if Rack::Utils.parse_query(request.query_string).has_key?(SeoCache.force_cache_url_param) && SeoCache.log_missed_cache

      return is_requesting_prerendered_page
    end

    def get_prerendered_page_response(env)
      url          = URI.parse(build_api_url(env))
      headers      = {
        'User-Agent'      => env['HTTP_USER_AGENT'],
        'Accept-Encoding' => 'gzip'
      }
      req          = Net::HTTP::Get.new(url.request_uri, headers)
      http         = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true if url.scheme == 'https'
      response     = http.request(req)
      if response['Content-Encoding'] == 'gzip'
        response.body              = ActiveSupport::Gzip.decompress(response.body)
        response['Content-Length'] = response.body.length
        response.delete('Content-Encoding')
      end
      response
    rescue StandardError => error
      SeoCache.log_error(error.message)
    end

    def build_api_url(env)
      new_env = env
      if env['CF-VISITOR']
        match = /"scheme":"(http|https)"/.match(env['CF-VISITOR'])
        (new_env['HTTPS'] = true) && (new_env['rack.url_scheme'] = 'https') && (new_env['SERVER_PORT'] = 443) if match && match[1] == 'https'
        (new_env['HTTPS'] = false) && (new_env['rack.url_scheme'] = 'http') && (new_env['SERVER_PORT'] = 80) if match && match[1] == 'http'
      end

      if env['X-FORWARDED-PROTO']
        (new_env['HTTPS'] = true) && (new_env['rack.url_scheme'] = 'https') && (new_env['SERVER_PORT'] = 443) if env['X-FORWARDED-PROTO'].split(',')[0] == 'https'
        (new_env['HTTPS'] = false) && (new_env['rack.url_scheme'] = 'http') && (new_env['SERVER_PORT'] = 80) if env['X-FORWARDED-PROTO'].split(',')[0] == 'http'
      end

      if SeoCache.protocol.present?
        (new_env['HTTPS'] = true) && (new_env['rack.url_scheme'] = 'https') && (new_env['SERVER_PORT'] = 443) if @options[:protocol] == 'https'
        (new_env['HTTPS'] = false) && (new_env['rack.url_scheme'] = 'http') && (new_env['SERVER_PORT'] = 80) if @options[:protocol] == 'http'
      end

      url           = Rack::Request.new(new_env).url
      prerender_url = SeoCache.prerender_service_url
      forward_slash = prerender_url[-1, 1] == '/' ? '' : '/'
      "#{prerender_url}#{forward_slash}#{url}"
    end

    def build_rack_response_from_prerender(prerendered_response)
      response = Rack::Response.new(prerendered_response.body, prerendered_response.code, prerendered_response.header)

      # @options[:build_rack_response_from_prerender]&.call(response, prerendered_response)

      return response
    end

    def before_render(env)
      # return nil unless @options[:before_render]
      # cached_render = @options[:before_render].call(env)

      cached_render = @page_caching.get(Rack::Request.new(env).path)

      return nil unless cached_render

      if cached_render&.is_a?(String)
        Rack::Response.new(cached_render, 200, 'Content-Type' => 'text/html; charset=utf-8')
      elsif cached_render&.is_a?(Rack::Response)
        cached_render
      end
    end

    def page_render(env)
      # return nil unless @options[:page_render]
      # @options[:page_render].call(url)

      # Add key parameter to url
      request = Rack::Request.new(env)
      url     = if request.query_string.present? || request.url.end_with?('?')
                  request.url + '&'
                else
                  request.url + '?'
                end
      url     += "#{SeoCache.prerender_url_param}=true"

      PageRender.new.get(url)
    end

    def after_render(env, response)
      # return true unless @options[:after_render]
      # @options[:after_render].call(env, response)

      @page_caching.cache(response, Rack::Request.new(env).path)
    end
  end
end
