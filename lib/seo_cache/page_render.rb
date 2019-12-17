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

      browser_options = ::Selenium::WebDriver::Chrome::Options.new
      browser_options.args << 'disable-infobars'
      browser_options.args << '--headless'
      browser_options.args << '--no-sandbox'
      browser_options.args << '--disable-dev-shm-usage'
      browser_options.args << '--disable-gpu'
      browser_options.args << '--disable-web-security'
      browser_options.args << '--disable-extensions'
      browser_options.args << '--window-size=1920x1080'
      browser_options.args << '--remote-debugging-port=3020'
      @driver = ::Selenium::WebDriver.for(:chrome, options: browser_options)
    end
  end
end
