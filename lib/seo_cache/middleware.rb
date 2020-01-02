# frozen_string_literal: true

require 'seo_cache/page_caching'
require 'seo_cache/page_render'

module SeoCache
  class Middleware
    def initialize(app, options = {})
      @options              = options
      @extensions_to_ignore = SeoCache.extensions_to_ignore
      @crawler_user_agents  = SeoCache.crawler_user_agents

      @app = app

      @page_caching = PageCaching.new
    end

    def call(env)
      if prerender_page?(env)
        cached_response = before_render(env)

        return cached_response.finish if cached_response.present?

        SeoCache.log('missed cache : ' + Rack::Request.new(env).path) if SeoCache.log_missed_cache

        if SeoCache.prerender_service_url.present?
          prerender_response = prerender_service(env)
          if prerender_response
            response = build_response_from_prerender(prerender_response.body)
            after_render(env, prerender_response)
            return response.finish
          end
        else
          Thread.new do
            prerender_data = page_render(env)
            # Extract status from render page (return 500 if status cannot be found, some problems happen somewhere)
            status = prerender_data&.scan(/<!--status:(\d+)-->/)&.last&.first || 500
            after_render(env, prerender_data, status || 200)
          end
        end
      elsif prerender_params?(env)
        env['seo_mode'] = true
        # Add status to render page because Selenium doesn't return http headers or status...
        status, headers, response = @app.call(env)
        status_code               = "<!--status:#{status}-->"
        # Cannot add at the top of file, Chrome removes leading comments...
        begin
          body_code = response.body.sub('<head>', "<head>#{status_code}")
          return [status, headers, [body_code]]
        rescue
          return [status, headers, [nil]]
        end
      end

      return @app.call(env)
    end

    def prerender_params?(env)
      return false if env['REQUEST_METHOD'] != 'GET'

      request      = Rack::Request.new(env)
      query_params = Rack::Utils.parse_query(request.query_string)

      return false if @extensions_to_ignore.any? { |extension| request.fullpath.include? extension }

      return true if query_params.has_key?(SeoCache.prerender_url_param) || query_params.has_key?(SeoCache.force_cache_url_param)
    end

    def prerender_page?(env)
      user_agent                   = env['HTTP_USER_AGENT']
      buffer_agent                 = env['HTTP_X_BUFFERBOT']
      is_requesting_prerender_page = false

      return false unless user_agent

      return false if env['REQUEST_METHOD'] != 'GET'

      request      = Rack::Request.new(env)
      query_params = Rack::Utils.parse_query(request.query_string)

      # If it is the generated page...don't prerender
      return false if query_params.has_key?(SeoCache.prerender_url_param)

      # if it is a bot and host doesn't contain these domains...don't prerender
      return false if SeoCache.whitelist_hosts.present? && SeoCache.whitelist_hosts.none? { |host| request.host.include?(host) }

      # if it is a bot and urls contain these params...don't prerender
      return false if SeoCache.blacklist_params.present? && SeoCache.blacklist_params.any? { |param| query_params.has_key?(param) }

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

      is_requesting_prerender_page = true if Rack::Utils.parse_query(request.query_string).has_key?('_escaped_fragment_') || Rack::Utils.parse_query(request.query_string).has_key?(SeoCache.force_cache_url_param)

      # if it is a bot...show prerendered page
      is_requesting_prerender_page = true if @crawler_user_agents.any? { |crawler_user_agent| user_agent.downcase.include?(crawler_user_agent.downcase) }

      # if it is BufferBot...show prerendered page
      is_requesting_prerender_page = true if buffer_agent

      SeoCache.log('force cache : ' + request.path) if Rack::Utils.parse_query(request.query_string).has_key?(SeoCache.force_cache_url_param) && SeoCache.log_missed_cache

      return is_requesting_prerender_page
    end

    def prerender_service(env)
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

      return response
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

    def build_response_from_prerender(prerender_response)
      response = Rack::Response.new(prerender_response.body, prerender_response.code, prerender_response.header)

      # @options[:build_rack_response_from_prerender]&.call(response, prerendered_response)

      return response
    end

    def before_render(env)
      # return nil unless @options[:before_render]
      # cached_render = @options[:before_render].call(env)

      cached_render = @page_caching.get(Rack::Request.new(env).path)

      return nil unless cached_render

      if cached_render.is_a?(String)
        Rack::Response.new(cached_render, 200, 'Content-Type' => 'text/html; charset=utf-8')
      elsif cached_render.is_a?(Rack::Response)
        cached_render
      end
    end

    def page_render(env)
      # Add key parameter to url
      request = Rack::Request.new(env)
      url     = if request.query_string.present? || request.url.end_with?('?')
                  request.url + '&'
                else
                  request.url + '?'
                end
      url     += "#{SeoCache.prerender_url_param}=true"

      return PageRender.new.get(url)
    end

    def after_render(env, response, status = 200)
      return unless response && SeoCache.cache_only_status.include?(status.to_i)

      @page_caching.cache(response, Rack::Request.new(env).path)
    end
  end
end
