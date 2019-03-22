# SeoCache

Cache dedicated for SEO with Javascript rendering :fire:


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'seo_cache'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install seo_cache

Install chrome driver on your device

## How it works

Specific cache for bots to optimize time to first byte and render Javascript on server side.

Options:

Choose a cache mode (`disk` or `memory`):

    SeoCache.cache_mode = 'memory'

If cache on disk, specify the cache path (e.g. `Rails.root.join('public', 'seo_cache')`):
    
    SeoCache.disk_cache_path = nil
    
URLs to blacklist:

    SeoCache.blacklist_urls = []
    
URLs to whitelist:

    SeoCache.whitelist_urls = []
    
Query params un URl to blacklist:

    SeoCache.blacklist_params = []

## Automatic caching

To automate cache, create a cron rake task which called:

```ruby
SeoCache::PopulateCache.new('https://<your-domain-name>', paths_to_cache).new.perform
```

## Server

If you use disk caching, add to your Nginx configuration:

```
location / {
    # cached pages
    set $cache_extension '';
    if ($request_method = GET) {
      set $cache_extension '.html';
    }
    
    # Index HTML Files
    if (-f $document_root/seo_cache/$uri/index$cache_extension) {
      rewrite (.*) /seo_cache/$1/index.html break;
    }
    
    # Other HTML Files
    if (-f $document_root/seo_cache/$uri$cache_extension) {
      rewrite (.*) /seo_cache/$1.html break;
    }
    
    # All
    if (-f $document_root/seo_cache/$uri) {
      rewrite (.*) /seo_cache/$1 break;
    }
}
```

## Inspiration

Inspired by [prerender gem](https://github.com/prerender/prerender_rails).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/floXcoder/seo_cache. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the SeoCache project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/seo_cache/blob/master/CODE_OF_CONDUCT.md).
