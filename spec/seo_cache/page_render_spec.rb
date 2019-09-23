# frozen_string_literal: true

require 'spec_helper'

require 'seo_cache/page_render'

describe SeoCache::PageRender do
  before(:all) do
    SeoCache.cache_mode      = 'memory'
    SeoCache.redis_namespace = 'seo_cache_test'
    SeoCache.chrome_path     = '/usr/bin/chromium-browser'
  end

  let(:page_render) { described_class }

  let(:redis) do
    uri = URI.parse(SeoCache.redis_url)
    Redis::Namespace.new(SeoCache.redis_namespace, redis: Redis.new(host: uri.host, port: uri.port, password: uri.password, connect_timeout: 1, timeout: 1), warnings: false)
  end

  it 'renders a page' do
    rendered_page = page_render.new.get('https://example.com')
    expect(rendered_page).to match('Example Domain')
  end
end
