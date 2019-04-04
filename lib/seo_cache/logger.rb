# frozen_string_literal: true

require 'forwardable'
require 'logger'

module SeoCache
  #
  # @example Enable full logging
  #   SeoCache.logger.level = :debug
  #
  # @example Log to file
  #   SeoCache.logger.output = 'seo_cache.log'
  #
  # @example Use logger manually
  #   SeoCache.logger.info('This is info message')
  #   SeoCache.logger.warn('This is warning message')
  #
  class Logger
    extend Forwardable
    include ::Logger::Severity

    def_delegators :@logger, :debug, :debug?,
                   :info, :info?,
                   :warn, :warn?,
                   :error, :error?,
                   :fatal, :fatal?,
                   :level

    def initialize(logger_path = nil)
      @logger = create_logger(logger_path || $stdout)
    end

    def output=(io)
      # `Logger#reopen` was added in Ruby 2.3
      if @logger.respond_to?(:reopen)
        @logger.reopen(io)
      else
        @logger = create_logger(io)
      end
    end

    #
    # For Ruby < 2.3 compatibility
    # Based on https://github.com/ruby/ruby/blob/ruby_2_3/lib/logger.rb#L250
    #

    def level=(severity)
      if severity.is_a?(Integer)
        @logger.level = severity
      else
        case severity.to_s.downcase
        when 'debug'.freeze
          @logger.level = DEBUG
        when 'info'.freeze
          @logger.level = INFO
        when 'warn'.freeze
          @logger.level = WARN
        when 'error'.freeze
          @logger.level = ERROR
        when 'fatal'.freeze
          @logger.level = FATAL
        when 'unknown'.freeze
          @logger.level = UNKNOWN
        else
          raise ArgumentError, "invalid log level: #{severity}"
        end
      end
    end

    #
    # Returns IO object used by logger internally.
    #
    # Normally, we would have never needed it, but we want to
    # use it as IO object for all child processes to ensure their
    # output is redirected there.
    #
    # It is only used in debug level, in other cases output is suppressed.
    #
    # @api private
    #
    def io
      @logger.instance_variable_get(:@logdev).instance_variable_get(:@dev)
    end

    #
    # Marks code as deprecated with replacement.
    #
    # @param [String] old
    # @param [String] new
    #
    def deprecate(old, new)
      warn "[DEPRECATION] #{old} is deprecated. Use #{new} instead."
    end

    private

    def create_logger(output)
      logger           = ::Logger.new(output)
      logger.progname  = 'SeoCache'
      logger.level     = ($DEBUG ? DEBUG : INFO)
      logger.formatter = proc do |severity, time, progname, msg|
        "#{time.strftime('%F %T')} #{severity} #{progname} #{msg}\n"
      end

      logger
    end
  end
end
