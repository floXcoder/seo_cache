# frozen_string_literal: true

module SeoCache
  class PageRender
    def initialize
      init_driver
    end

    def get(url, quit_after_render = true)
      @driver.get(url)

      sleep SeoCache.wait_time_for_page_loading if SeoCache.wait_time_for_page_loading

      return @driver.page_source
    rescue StandardError => error
      SeoCache.log_error(error.message)

      return false
    ensure
      @driver&.quit if quit_after_render
    end

    def close_connection
      @driver&.quit
    end

    private

    def init_driver
      # Selenium::WebDriver.logger.level = :info

      Webdrivers.cache_time            = 86_400 * 10 # Chromedriver will be cached for 10 days (except if it detects a new version of Chrome)

      Selenium::WebDriver::Chrome.path = SeoCache.chrome_path if SeoCache.chrome_path

      browser_options = %w[headless incognito disable-gpu disable-infobars disable-dev-shm-usage disable-gpu disable-web-security disable-extensions no-sandbox disable-logging disable-notifications disable-sync window-size=1920x1080]
      browser_options << "remote-debugging-port=#{SeoCache.chrome_debugging_port}" if SeoCache.chrome_debugging_port
      @driver = ::Selenium::WebDriver.for(
        :chrome,
        capabilities: [Selenium::WebDriver::Chrome::Options.new(
          args: browser_options
        )]
      )
    end
  end
end
