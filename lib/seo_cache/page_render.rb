# frozen_string_literal: true

module SeoCache
  class PageRender
    def initialize
      init_driver
    end

    def get(url)
      @driver.get(url)

      return @driver.page_source
    rescue StandardError => error
      SeoCache.log_error(error.message)
    ensure
      @driver&.quit
    end

    def persistent_get(url)
      @driver.get(url)

      return @driver.page_source
    rescue StandardError => error
      SeoCache.log_error(error.message)
    end

    def close_connection
      @driver&.quit
    end

    private

    def init_driver
      # Selenium::WebDriver.logger.level = :info

      Webdrivers.cache_time = 86_400

      Selenium::WebDriver::Chrome.path = SeoCache.chrome_path if SeoCache.chrome_path

      client          = ::Selenium::WebDriver::Remote::Http::Persistent.new
      browser_options = ::Selenium::WebDriver::Chrome::Options.new
      browser_options.args << '--headless'
      browser_options.args << '--disable-gpu'
      browser_options.args << '--no-sandbox'
      browser_options.args << '--disable-web-security'
      browser_options.args << '--window-size=1920x1080'
      # browser_options.args << '--remote-debugging-port=3020'
      @driver = ::Selenium::WebDriver.for(:chrome, options: browser_options, http_client: client)
    end
  end
end
