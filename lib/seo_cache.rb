# frozen_string_literal: true

require 'active_support'
require 'net/http'
require 'redis'
require 'redis-namespace'
require 'selenium/webdriver'

require 'seo_cache/logger'
require 'seo_cache/version'
require 'seo_cache/middleware'

module SeoCache

  mattr_accessor :chrome_path
  self.chrome_path = nil

  mattr_accessor :cache_mode # disk or memory
  self.cache_mode = 'memory'

  mattr_accessor :cache_path
  self.cache_path = ''

  mattr_accessor :locale_as_first_directory
  self.locale_as_first_directory = false

  mattr_accessor :locale_method
  self.locale_method = nil

  mattr_accessor :cache_extension
  self.cache_extension = '.html'

  mattr_accessor :redis_url
  self.redis_url = 'redis://localhost:6379/'

  mattr_accessor :redis_db_index
  self.redis_db_index = 0

  mattr_accessor :redis_namespace
  self.redis_namespace = '_seo_cache:'

  mattr_accessor :whitelist_hosts
  self.whitelist_hosts = []

  mattr_accessor :blacklist_urls
  self.blacklist_urls = []

  mattr_accessor :whitelist_urls
  self.whitelist_urls = []

  mattr_accessor :blacklist_params
  self.blacklist_params = []

  mattr_accessor :cache_with_user_connected
  self.cache_with_user_connected = false

  mattr_accessor :log_missed_cache
  self.log_missed_cache = false

  mattr_accessor :protocol
  self.protocol = nil

  mattr_accessor :prerender_service_url
  self.prerender_service_url = nil

  # Selenium doesn't support HTTP header, so URL parameter is mandatory
  mattr_accessor :prerender_url_param
  self.prerender_url_param = '_prerender_'

  mattr_accessor :force_cache_url_param
  self.force_cache_url_param = '_seo_cache_'

  # Time to wait to wait before page rendering (for asynchronous called), in seconds
  mattr_accessor :wait_time_for_page_loading
  self.wait_time_for_page_loading = nil

  mattr_accessor :cache_only_status
  self.cache_only_status = [200]

  # Default port used by Chrome: 9222
  mattr_accessor :chrome_debugging_port
  self.chrome_debugging_port = false

  mattr_accessor :extensions_to_ignore
  self.extensions_to_ignore = %w[.js .css .xml .less .png .jpg .jpeg .gif .pdf .doc .txt .ico .rss .zip .mp3 .rar .exe .wmv .doc .avi .ppt .mpg .mpeg .tif .wav .mov .psd .ai .xls .mp4 .m4a .swf .dat .dmg .iso .flv .m4v .torrent .woff2 .woff .gz .ttf .svg]

  mattr_accessor :crawler_user_agents
  self.crawler_user_agents = [
    'googlebot',
    'yahoo',
    'bingbot',
    'baiduspider',
    'facebookexternalhit',
    'twitterbot',
    'rogerbot',
    'linkedinbot',
    'embedly',
    'bufferbot',
    'quora link preview',
    'showyoubot',
    'outbrain',
    'pinterest/0.',
    'developers.google.com/+/web/snippet',
    'www.google.com/webmasters/tools/richsnippets',
    'slackbot',
    'vkShare',
    'W3C_Validator',
    'redditbot',
    'Applebot',
    'WhatsApp',
    'flipboard',
    'tumblr',
    'bitlybot',
    'SkypeUriPreview',
    'nuzzel',
    'Discordbot',
    'Google Page Speed',
    'Qwantify'
  ]

  mattr_accessor :logger_path
  self.logger_path = nil

  mattr_accessor :logger_level
  self.logger_level = :warn

  mattr_accessor :logger
  # self.logger = SeoCache::Logger.new(SeoCache.logger_path)

  def self.memory_cache?
    SeoCache.cache_mode == 'memory'
  end

  def self.disk_cache?
    SeoCache.cache_mode == 'disk'
  end

  def self.logger
    @logger ||= SeoCache::Logger.new(SeoCache.logger_path)
  end

  def self.log(message)
    SeoCache.logger.info(message)
    # Rails.logger.info { "[seo_cache] #{message}" }
  end

  def self.log_error(message)
    SeoCache.logger.error(message)
    # Rails.logger.error { "[seo_cache] #{message}" }
  end
end
