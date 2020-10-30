# SeoCache

**SeoCache is a dedicated cache for SEO with JavaScript rendering** :fire:

You can find in this article, a more detail explanation of the purpose and usage of this gem:

- In english: https://www.ginkonote.com/users/flo/articles/seo-generate-and-cache-your-pages@seo
- In french: https://www.ginkonote.com/fr/utilisateurs/flo/articles/seo-generation-et-mise-en-cache-des-pages@seo

## Table of contents
- [Purpose](#purpose)
- [Installation](#installation)
- [Configuration](#configuration)
- [Helpers for controllers](#helpers-for-controllers)
- [Check cached pages](#check-cached-pages)
- [Automatic caching](#automatic-caching)
- [Server configuration](#server-configuration)
- [Inspiration](#inspiration)
- [Contributing](#contributing)

## Purpose

Google credo is: Don't waste my bot time!

In order to reduce Googlebot crawling time, let's provide the complete HTML files in a specific cache.

This cache is suitable for static (generated or not) pages but not for user private pages.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'seo_cache'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install seo_cache

Install chromium or chrome driver on your device (the chromedriver will be automatically downloaded).

Declare the middleware. For instance in `config/initializers/seo_cache.rb`:

```ruby
require 'seo_cache'

# See options below

Rails.application.config.middleware.use SeoCache::Middleware
```

## Configuration

Chrome path (**required**) (`disk` or `memory`):

```ruby
SeoCache.chrome_path = Rails.env.development? ? '/usr/bin/chromium-browser' : '/usr/bin/chromium'
```

Choose a cache mode (`memory` (default) or `disk`):

```ruby
SeoCache.cache_mode = 'memory'
```

Cache path (**required**):
    
```ruby
SeoCache.cache_path = Rails.root.join('public', 'seo_cache')
```

Redis URL (**required** if memory cache):

```ruby
SeoCache.redis_url = "redis://localhost:6379/"
```

Redis prefix:

```ruby
SeoCache.redis_namespace = '_my_project:seo_cache'
```

Waiting time before the page is fully loaded (optional in sec, useful for async elements):
    
```ruby
SeoCache.wait_time_for_page_loading = 3
```

Specific log file (if you want to log missed cache urls):
    
```ruby
SeoCache.logger_path = Rails.root.join('log', 'seo_cache.log')
```

Activate missed cache urls:
    
```ruby
SeoCache.log_missed_cache = true
```
 
Domains to whitelist (authorize only domains which contains these hosts):

```ruby
SeoCache.whitelist_hosts = []
```

URLs to blacklist:

```ruby
SeoCache.blacklist_urls = %w[^/assets/.* ^/admin.*]
```

Params to blacklist:

```ruby
SeoCache.blacklist_params = %w[page]
```

URLs to whitelist:

```ruby
SeoCache.whitelist_urls = []
```

Cache page even if user is connected (be careful when caching sensitive data):

```ruby
SeoCache.cache_with_user_connected = true
```

Parameter to add manually to the URl to force page caching, if you want to cache a specific URL (e.g. `https://<my_website>/?_seo_cache_=true`):

```ruby
SeoCache.force_cache_url_param = '_seo_cache_'
```

Cache only the pages with these HTTP status code (don't cache by default not found or error pages):

```ruby
SeoCache.cache_only_status = [<your_list>]
```

URL extension to ignore when caching (already defined):

```ruby
SeoCache.extensions_to_ignore = [<your_list>]
```

List of bot agents (already defined):

```ruby
SeoCache.crawler_user_agents = [<your_list>]
```
    
Parameter added to URL when generating the page, avoid infinite rendering (override only if already used):

```ruby
SeoCache.prerender_url_param = '_prerender_'
```

If you encounter the following error `DevToolsActivePort file doesn't exist`, you can add the following option:

```ruby
SeoCache.chrome_debugging_port = '9222'
```

Be aware, JS will be rendered twice: once by this gem and once by client. For React, this not a problem but with jQuery plugins, it can duplicate elements in the page (you have to check the redundancy).

Disk cache is recommended by default. Nginx will directly fetch HTML files on disk. The TTFB (time to first byte) will be under 200ms :). You can use memory cache if you have lot of RAM, but if you shut down your server, you will lost all the generated pages! So prefer cache disk storage.

## Helpers for controllers

You can check if seo mode is active in your controllers, with the following variable:

```ruby
def check_seo_mode
  @seo_mode = (params.key?(SeoCache.prerender_url_param) || params.key?(SeoCache.force_cache_url_param))
end
```

And if you want to access to this variable in JS files:

```javascript
window.seoMode = "{@seo_mode}"
```


## Check cached pages

Too see in browser the cached page, open a browser and set the user agent to:

`Googlebot (Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html))`

For instance, with Chrome or Chromium, you can change the user agent in "Network" / "Network conditions" panel.

To (re)cache a page, add this parameter to the url (and the browser must use the Googlebot user agent):

`/?_seo_cache_=true`

## Automatic caching

To automate caching, create a cron rake task (e.g. in `lib/tasks/populate_seo_cache.rake`):

```ruby
namespace :my_project do

  desc 'Populate cache for SEO'
  task populate_seo_cache: :environment do |_task, _args|
    require 'seo_cache/populate_cache'
    
    paths_to_cache = public_paths_like_sitemap
    
    SeoCache::PopulateCache.new('https://<your-domain-name>', paths_to_cache).new.perform
  end
end
```

You can add the `force_cache: true` option to `SeoCache::PopulateCache` for overwrite cached data.

If you want to execute only through a rake task, you can comment the line which include the middleware. keep all options configured and remove only the middleware. Thus all pages will be cached and SeoCache isn't called for pages not in cache.
It's useful if you have a script which generates all website pages (based on sitemap for instance) and you run script every day.

## Server configuration

If you use disk caching, add this to your Nginx configuration:

```nginx
# Before any block:
map $http_user_agent $limit_bots {
    default 0;
    ~*(google|bing|yandex|msnbot) 1;
}

map $request_method $is_get {
    default 0;
    GET 1;
}

# Before location block:
set $bot_request '';
if ($is_get) {
      set $bot_request 'GET_';
}

if ($limit_bots) { 
  set $bot_request "${bot_request}BOT"; 
}

set $cache_extension '';
if ($bot_request = GET_BOT) {
  set $cache_extension '.html';
}

# Inside location block:
location / {
    # Ignore url with blacklisted params (e.g. page)
    if ($arg_page) {
      break;
    }
    if ($arg__seo_cache_) {
      break;
    }

    # Local rewrite to remove trailing slash
    rewrite ^/(.*)/$ /$1 last;
    
    try_files /seo_cache/$uri/index$cache_extension /seo_cache/$uri$cache_extension /seo_cache/$uri $uri @rubyproxy;
}

location @rubyproxy {
    proxy_connect_timeout 600;
    proxy_send_timeout 600;
    proxy_read_timeout 600;
    send_timeout 600;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_pass_header Server;
    proxy_pass http://0.0.0.0:3020;
}
```

This configuration allow you to use SEO cache only for bots (you can add other bots at the beginning of the file) and HTML GET requests. For connected users, you don't want to use the cached page (user connection, basket, ...). The performance are less important for users than bots.

## Heroku case

If you use Heroku server, you can't store files on dynos. But you have two alternatives:

- Use the memory mode

- Use a second server (a dedicated one) to store HTML files and combine with Nginx.

To intercept the request, use the following middleware in Rails:

In `config/initializers`, create a new file:

```ruby
require 'bot_detector'

if Rails.env.production?
  Rails.application.config.middleware.insert_before ActionDispatch::Static, BotDetector
end
``` 

Then in `lib` directory, for instance, manage the request:

```ruby
class BotRedirector
  CRAWLER_USER_AGENTS = ['googlebot', 'yahoo', 'bingbot', 'baiduspider', 'facebookexternalhit', 'twitterbot', 'rogerbot', 'linkedinbot', 'embedly', 'bufferbot', 'quora link preview', 'showyoubot', 'outbrain', 'pinterest/0.', 'developers.google.com/+/web/snippet', 'www.google.com/webmasters/tools/richsnippets', 'slackbot', 'vkShare', 'W3C_Validator', 'redditbot', 'Applebot', 'WhatsApp', 'flipboard', 'tumblr', 'bitlybot', 'SkypeUriPreview', 'nuzzel', 'Discordbot', 'Google Page Speed', 'Qwantify'].freeze

  IGNORE_URLS = [
    '/robots.txt'
  ].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    if env['HTTP_USER_AGENT'].present? && CRAWLER_USER_AGENTS.any? { |crawler_user_agent| env['HTTP_USER_AGENT'].downcase.include?(crawler_user_agent.downcase) }
      begin
        request = Rack::Request.new(env)

        return @app.call(env) if IGNORE_URLS.any? { |ignore_url| request.fullpath.downcase =~ /^#{ignore_url.downcase}/ }

        url     = URI.parse(ENV['SEO_SERVER'] + request.fullpath)
        headers = {
          'User-Agent'      => env['HTTP_USER_AGENT'],
          'Accept-Encoding' => 'gzip'
        }
        req     = Net::HTTP::Get.new(url.request_uri, headers)
        # req.basic_auth(ENV['SEO_USER_ID'], ENV['SEO_PASSWD']) # if authentication mechanism
        http         = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true if url.scheme == 'https'
        response     = http.request(req)
        if response['Content-Encoding'] == 'gzip'
          response.body              = ActiveSupport::Gzip.decompress(response.body)
          response['Content-Length'] = response.body.length
          response.delete('Content-Encoding')
        end

        return [response.code.to_i, { 'Content-Type' => response.header['Content-Type'] }, [response.body]]
      rescue => error
        Rails.logger.error("[bot_redirection] #{error.message}")

        @app.call(env)
      end
    else
      @app.call(env)
    end
  end
end
```

If you use a second server, all links must be relatives in your HTML files, to avoid multi-domains links.

## Inspiration

Inspired by [prerender gem](https://github.com/prerender/prerender_rails).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/floXcoder/seo_cache. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the SeoCache project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/seo_cache/blob/master/CODE_OF_CONDUCT.md).
