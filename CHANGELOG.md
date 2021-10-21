## 1.1.0

- Update dependencies

## 1.0.7

- Use new syntax to check if Redis key exists

## 1.0.6

- Logs only missed cache for success response

## 1.0.5

- Use correct path for index page with multiple domain names

## 1.0.4

- Add option to populate seo cache for multi-domains

## 1.0.3

- Ensure page rendered status is present after head element 

## 1.0.2

- Do not log missed cache for ignored statuses

## 1.0.1

- Add user agent to missed caches

## 1.0.0

- Update Readme (badges, syntax, links, ...)
- Add Travis CI
- Update dependencies
- Do not cache pages in error

## 0.19.0

- Add option to cache page if user connected

## 0.18.0

- Correct use of prerender param in URL

## 0.17.0

- Correct bug when populating cache

## 0.16.0

- Add prerender params when populating cache

## 0.15.0

- Add global option for Chrome debugging port problem

## 0.14.0

- Change options from Chrome
- Correct bug when rendering a 404 page

## 0.13.0

- Correct option for populate cache
- Add new option in Readme

## 0.12.0

- Force driver to quit after page rendering (except for populate cache, quit only after rendered all pages)
- Add option to wait for page loading (in case of asynchronous components, like React Router)

## 0.11.0

- Update for Rails 6

## 0.10.0

- Update Readme for nginx configuration

## 0.9.0

- Update gems
- Don't cache response if status is not 200
- Add 'seo_mode' variable to env to detect si seo mode is currently active
- Add status to source code to cache only pages with 200 HTTP status code
- Check existence of destination directory before creating it
- Remove persistent connection (already built-in in Selenium) 

## 0.8.0

- Change bundler version

## 0.7.0

- Add whitelist hosts domain option (authorize only these domains)

## 0.6.0

- Update gems (webdrivers and selenium-webdriver)

## 0.5.0

- Add more information in README
- Update gems and define cache time for browser driver

## 0.4.0

- Complete README
- Add new tests to cover disk and memory
- Remove "disk_" prefix from disk_cache_path and disk_cache_extension

## 0.3.0

- Add more examples in README
- Switch chromedriver to webdrivers
- Add tests
- Set correct URL for Github

## 0.2.0

- Improve README
- Add missing dependency

## 0.1.0

- First major release
