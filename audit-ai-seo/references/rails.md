# Rails apps (8.1+)

Rails-specific Layer 0 and Layer 1 patterns. **Do not** treat a Rails app like a static site (no `public/*.md` mirrors, no Netlify edge negotiate, no dynamic SEO controllers).

`site-pages.json` is still used — but only to list **routes to verify** (`html_paths`, `section_indexes`). Markdown is served from controllers, not from files listed in config.

---

## Layer 1: Markdown via `respond_to` (not static `.md` files)

Rails 8.1+ registers `text/markdown` as `:md` and ships a `markdown:` renderer ([Rails MIME docs](https://api.rubyonrails.org/classes/ActionController/MimeResponds.html), [acceptmarkdown Rails recipe](https://acceptmarkdown.com/recipes/rails)).

### Controller pattern

```ruby
class ArticlesController < ApplicationController
  def show
    @article = Article.find(params[:id])

    respond_to do |format|
      format.html
      format.md { render markdown: @article }
    end
  end
end
```

`render markdown: @article` calls `@article.to_markdown` and sets `Content-Type: text/markdown; charset=utf-8`.

**Or** use templates — `show.html.erb` + `show.md.erb` beside each other:

```ruby
def show
  @article = Article.find(params[:id])
  respond_to(&:html, &:md)
end
```

### `to_markdown` on models

```ruby
class Article < ApplicationRecord
  def to_markdown
    "# #{title}\n\n#{body}"
  end
end
```

Single source of truth — same object backs HTML and Markdown. **Do not** duplicate content into `public/guide/introduction.md`.

### Prioritize Markdown when agents send `Accept: text/markdown`

Many clients send `Accept: text/markdown, text/html, */*`. Rails may prefer HTML unless Markdown is first in `request.formats`. Add to `ApplicationController`:

```ruby
before_action :prioritize_markdown_format

private

def prioritize_markdown_format
  return unless request.accepts.first&.to_s == "text/markdown"

  request.formats = %i[md html]
end
```

For full q-value rules (acceptmarkdown readiness #4), see [accept-markdown-negotiation.md](accept-markdown-negotiation.md). Rails 8.1 handles 406 for unregistered formats automatically via `respond_to`.

### `Vary: Accept`

Rails sets `Vary: Accept` on negotiated `respond_to` responses. If you set `Vary` elsewhere, merge `Accept` manually.

### Routes: same URL + optional `.md` format

Enable format suffix so `/articles/1.md` works (verifier and `<link rel="alternate">`):

```ruby
resources :articles, only: [:show]
# GET /articles/:id(.:format) — :md and :html
```

`<link rel="alternate" type="text/markdown" href="<%= article_path(@article, format: :md) %>">`

Hidden LLM pointer can cite the `.md` URL or the canonical URL (negotiation on same URL is enough).

### What NOT to do on Rails

| Avoid | Use instead |
|-------|-------------|
| Static `.md` files in `public/` | `respond_to` + `to_markdown` or `.md.erb` |
| Netlify/Cloudflare edge negotiate | Rails `respond_to` |
| Custom `Mime::Type.register` (8.1+) | Built-in `:md` |
| Rack middleware duplicating negotiation | Controller `respond_to` |

---

## Layer 0: Static SEO files at deploy (not controllers)

Generate crawl artifacts **once at deploy** and write to `public/`. Crawlers should read files from disk/CDN — not hit Ruby on every request.

### Ship as static files

| File | Path | When to generate |
|------|------|------------------|
| `sitemap.xml` | `public/sitemap.xml` | Deploy / release task |
| `robots.txt` | `public/robots.txt` | Deploy (or static with `Sitemap:` line) |
| `feed.xml` | `public/feed.xml` | Deploy (if blog/updates) |

### Rake task pattern

```ruby
# lib/tasks/seo.rake
namespace :seo do
  desc "Write sitemap.xml and robots.txt to public/"
  task static: :environment do
    File.write(Rails.root.join("public/sitemap.xml"), Seo::SitemapBuilder.new.call)
    File.write(Rails.root.join("public/robots.txt"), Seo::RobotsBuilder.new.call)
  end
end
```

Run in deploy hook **after** migrations, **before** or **after** asset precompile:

```bash
bin/rails seo:generate_files
```

Use [sitemap_generator](https://github.com/kjvarga/sitemap_generator) or a small builder that queries published records once, writes XML, exits.

### What NOT to do on Rails

| Avoid | Why |
|-------|-----|
| `SitemapsController#index` rendering XML per request | Wastes app server; cache misses; unnecessary DB load |
| `RobotsController` | Same — use `public/robots.txt` |
| On-the-fly `feed.xml` controller | Generate static `public/feed.xml` at deploy unless feed must be real-time |
| Dynamic sitemap only in development | Production must have a committed or deployed static file |

Refuse these when auditing. Convert to a deploy-time generator if they already exist.

### `robots.txt` on Rails

Static `public/robots.txt` with absolute production `Sitemap:` URL. Regenerate in `seo:generate_files` if sitemap host changes per environment.

### Page metadata & JSON-LD

Stay in layouts/partials/view helpers (HTML responses). Unchanged from main skill — one `<title>`, one description, JSON-LD in template.

---

## `site-pages.json` for Rails

List real routes the verifier should probe — not static file paths:

```json
{
  "html_paths": ["/", "/articles/hello-world"],
  "section_indexes": ["/blog"],
  "check_llms_full_txt": false,
  "require_feed": true,
  "require_json_ld": true,
  "require_markdown_negotiation": true
}
```

Verifier derives `.md` URLs (`/articles/hello-world.md`) to confirm format routes work; negotiation checks hit the same HTML paths with `Accept: text/markdown`.

---

## Verification

```bash
# Same URL, Markdown via Accept
curl -sI -H "Accept: text/markdown" https://example.com/articles/1

# Optional .md format route
curl -sI https://example.com/articles/1.md

# Static sitemap (not a controller)
curl -sI https://example.com/sitemap.xml

ruby .cursor/skills/audit-ai-seo/scripts/verify_seo.rb https://example.com
```

---

## References

- [acceptmarkdown.com Rails recipe](https://acceptmarkdown.com/recipes/rails)
- [Rails 8.1 Markdown rendering](https://blog.saeloun.com/2026/05/22/rails-8-1-markdown-rendering/)
- [ActionController::MimeResponds](https://api.rubyonrails.org/classes/ActionController/MimeResponds.html)
- [accept-markdown-negotiation.md](accept-markdown-negotiation.md) — q-values, 406, test matrix
