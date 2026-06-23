---
name: audit-ai-seo
description: Audit and implement Google SEO plus LLM/AI discoverability for websites, docs, blogs, and landing pages. Infrastructure only — never create dummy posts, sample content, or new site sections to pass the verifier. Covers robots.txt, sitemaps, meta tags, JSON-LD, feeds, llms.txt, .md mirrors, Link headers, Accept negotiation, and Content-Signal. Use for SEO audits, Bridgetown/static sites, or Rails 8.1+ apps. Refuses debunked AI patterns, placeholder content, and dynamic SEO controllers. Ends with Ruby verifier against production.
---

# Audit AI SEO (Google + LLM discoverability)

Two layers, one workflow, **equal priority**: Google search and LLM agents both need a complete ship. Framework from [Evil Martians Ruby scorecard](https://ruby.evilmartians.com/) (Layer 0 crawl + Layer 1 retrieval) and [How to make your website visible to LLMs](https://evilmartians.com/chronicles/how-to-make-your-website-visible-to-llms). LLM mechanics follow the official [llms-visibility skill](https://evilmartians.com/skills/llms-visibility.md).

**JSON-LD is for Google/Bing rich results, not LLM citations.** Ship it anyway as part of Layer 0. Do not add schema.org *for* LLM visibility; do not remove existing structured data.

**Infrastructure only.** This skill wires SEO and LLM discoverability (robots, sitemap, meta, JSON-LD, `llms.txt`, negotiation, etc.). It does **not** author editorial content. Never create dummy posts, sample articles, scaffold blogs, or filler pages to make the verifier pass. If a path in `site-pages.json` does not exist on the site, **remove it from config** — do not invent content.

## Agent rules (mandatory)

1. **Infrastructure only** — wire robots, sitemap, meta, JSON-LD, `llms.txt`, `.md` routes, negotiation. Do not write posts, guides, or marketing copy unless the user explicitly asks for content work.
2. **`site-pages.json` from live URLs** — confirm each listed path returns 200 before adding it. If the verifier fails because a path is missing, **remove it from config**, never invent the page.
3. **Verifier failures ≠ content gaps** — 404 on `/blog/` means delete `/blog/` from `section_indexes`, not "create a blog".
4. **`.md` = wiring** — add plugins/routes/build output so **existing** HTML becomes `.md`; do not author new markdown pages to populate mirrors.

## When to use

- New site or docs: baseline audit before launch
- Existing site: "why aren't we in AI answers / Google?"
- After implementing discoverability: verify production with the Ruby script

## Workflow (always in this order)

1. **Audit** live site (or local build output if not deployed)
2. **Build `site-pages.json` from the audit** — only URLs that already exist and return 200. Remove template paths (`/blog/`, etc.) the site does not have. Set `require_feed: false` unless a real feed exists.
3. **Report** gaps as Layer 0 (Google/crawl) vs Layer 1 (LLM retrieval) vs content (optional recommendations only — do not implement unless asked)
4. **Implement** infrastructure fixes only (each step is independently shippable).
   - **Rails 8.1+:** [references/rails.md](references/rails.md) — `respond_to` `format.md`, static `public/sitemap.xml` at deploy; refuse dynamic SEO controllers.
   - **Static sites:** [references/accept-markdown-negotiation.md](references/accept-markdown-negotiation.md) — edge/middleware negotiation, build-time `.md` mirrors.
5. **Verify** with `scripts/verify_seo.rb` against production URL
6. **Hand off** project `site-pages.json` (customized paths). Re-run verifier from the skill — no need to copy `verify_seo.rb`.

---

## Layer 0: Google SEO and crawl (ship first)

Goal: crawlers can find pages, index the right ones, show useful snippets, and qualify for rich results in Google.

### robots.txt

- [ ] `Sitemap: https://example.com/sitemap.xml` (absolute production URL)
- [ ] Do **not** `Disallow: /` for GPTBot, ClaudeBot, PerplexityBot, CCBot, Google-Extended
- [ ] Add Cloudflare `Content-Signal:` under `User-agent: *` (policy choice):

```
User-agent: *
Content-Signal: search=yes, ai-input=yes, ai-train=yes
```

Confirm `ai-train=yes` with the owner. Validators may warn about unknown directives; that is expected (RFC 9309: ignore unknown lines).

### sitemap.xml

- [ ] Valid XML `urlset`, only **published** URLs
- [ ] Include home, section indexes, live content pages
- [ ] Exclude drafts, coming-soon, future-dated posts, admin, thank-you pages
- [ ] Reasonable `changefreq` / `lastmod` (avoid `yearly` for normal pages)
- [ ] Submit in Google Search Console after deploy
- [ ] **Rails:** static `public/sitemap.xml` generated at **deploy** (`rails seo:generate_files` or similar) — **not** a `SitemapsController` that renders XML on every crawl ([references/rails.md](references/rails.md))

### Page metadata (every indexable template)

- [ ] Exactly **one** `<title>` and **one** `<meta name="description">` (no duplicate tags from layout + plugin)
- [ ] `rel="canonical"` with absolute URL
- [ ] Open Graph: `og:title`, `og:description`, `og:image`, `og:url`
- [ ] `noindex, follow` for placeholders (coming-soon chapters, staging)
- [ ] Optional: Twitter card tags

### Structured data (Google, required)

Ship schema.org JSON-LD on every indexable page type. Validate with [Google Rich Results Test](https://search.google.com/test/rich-results) after deploy.

**Output raw JSON inside the script tag** — crawlers must see `{"@context":...}` not HTML entities (`&quot;`). Common bug: ERB `<%= %>` escapes JSON.

Bridgetown / ERB — use unescaped output:

```erb
<script type="application/ld+json"><%== json_ld.to_json %></script>
```

Rails — use `safe_join` / `.html_safe` on JSON only inside `type: application/ld+json` script tags, or a helper that does not escape quotes.

Wrong (unparseable):

```html
<script type="application/ld+json">{&quot;@context&quot;:&quot;https://schema.org&quot;...}</script>
```

Right:

```html
<script type="application/ld+json">{"@context":"https://schema.org","@type":"LearningResource",...}</script>
```

- [ ] Home: `WebSite` + `SearchAction` (or equivalent site-level type)
- [ ] Guide index: `Course` or `LearningResource` with `hasPart` / chapter list where practical
- [ ] Guide chapters: `LearningResource` (or `Article` for narrative chapters) + `BreadcrumbList`
- [ ] Blog posts: `Article` (or `BlogPosting`) + `BreadcrumbList`
- [ ] `@context` `https://schema.org`, absolute URLs, match visible title/description
- [ ] Do **not** claim this improves LLM citations (Layer 1 handles agents)

### Feeds and internal linking

- [ ] Atom/RSS at `/feed.xml` (blog or site updates)
- [ ] `<link rel="alternate" type="application/atom+xml">` in HTML head
- [ ] Internal links between related chapters/posts; prev/next on linear content
- [ ] Unique, descriptive titles (not "Chapter 3" alone)

### Content and GSC (human steps — recommend only, do not implement unless asked)

- [ ] Thin or duplicate pages: expand or noindex (suggest to owner; do not write filler)
- [ ] Comparison posts for high-intent queries — **skip unless user explicitly requests content work**
- [ ] GSC: verify property, submit sitemap, request indexing for home + one deep page once

### Optional (usually skip unless asked)

- DNS-AID / SVCB records for agent discovery (needs DNSSEC + MCP server; low value for static marketing sites)
- Bing Webmaster Tools sitemap submit

---

## Layer 1: LLM retrieval (ship with Layer 0)

Goal: when a human pastes a URL or a coding agent fetches docs, the model gets **clean Markdown**, not HTML soup.

Priority (impact vs effort):

| # | Mechanism | Priority |
|---|-----------|----------|
| 0 | robots.txt + Content-Signal | Critical |
| 1 | `/llms.txt` | Critical |
| 2 | `.md` routes for content pages | Critical |
| 3 | `<link rel="alternate">` + HTTP `Link` header | High |
| 4 | Visually hidden Markdown pointer | Medium |
| 5 | `/llms-full.txt` | Medium (docs); optional for blogs |
| 6 | `Accept: text/markdown` negotiation | High |

### 1. `/llms.txt`

Curated Markdown at site root ([llmstxt.org](https://llmstxt.org/) format). README for AI conversations, not a sitemap dump.

```markdown
# Site Name

> One-sentence description.

## Guide

- [Introduction](/guide/introduction/): Start here
```

### 2. `.md` mirrors

**Static sites (Bridgetown, Jekyll, etc.):** For `/path/` serve `/path.md` (root → `/index.md`). **Single source of truth** (generate from same content as HTML). No YAML front matter in the served body.

When auditing or implementing: for every URL in `site-pages.json` `html_paths` and `section_indexes`, derive the `.md` path and **wire the route/build output** if missing (plugin, edge, generator). **Do not** create new markdown *content* or new pages — only expose existing content as `.md` mirrors.

| HTML | `.md` mirror |
|------|----------------|
| `/` | `/index.md` |
| `/guide/` | `/guide.md` |
| `/guide/introduction/` | `/guide/introduction.md` |
| `/about/` | `/about.md` |

Rule: strip trailing slash, `/` → `/index.md`, else append `.md`.

**Rails 8.1+:** Do **not** create static `public/*.md` files. Use `respond_to` `format.md` with `to_markdown` or `.md.erb` templates on the same routes ([references/rails.md](references/rails.md)). `site-pages.json` lists routes to verify only.

### 3. Advertise Markdown (both HTML tag and HTTP header)

```html
<link rel="alternate" type="text/markdown" href="/guide/introduction.md" />
```

```
Link: </guide/introduction.md>; rel="alternate"; type="text/markdown"
```

Set `Link` on **both** HTML and `.md` responses. Pair with `Vary: Accept` on CDN/static host.

### 4. Visually hidden pointer (LLMs only)

```html
<div class="visually-hidden" aria-hidden="true">
  A Markdown version of this page is available at https://example.com/guide/introduction.md.
</div>
```

### 5. `/llms-full.txt` (optional)

Full corpus in one file. High value for docs/APIs; for blogs, concatenating posts or redirecting to `/index.md` is fine.

### 6. `Accept: text/markdown` content negotiation

Same URL, representation chosen by `Accept`. Full language-agnostic checklist (algorithm, test matrix, Rack/edge hooks): **[references/accept-markdown-negotiation.md](references/accept-markdown-negotiation.md)**.

Must pass [acceptmarkdown.com readiness](https://acceptmarkdown.com/#readiness):

1. Serves Markdown for `Accept: text/markdown`
2. Sets `Vary: Accept` on HTML and Markdown responses
3. Returns **406** when neither `text/html` nor `text/markdown` is acceptable
4. Honors **`q`-values** — `*/*` alone must not return Markdown; higher `q` on `text/html` wins over lower `text/markdown`

**Not cloaking.** User-Agent sniffing for bots is forbidden; use `Accept` only.

Static hosts (Netlify, Cloudflare): edge function or middleware; `_headers` for `Link`/`Vary` on static fallbacks. Stack recipes: [acceptmarkdown.com](https://acceptmarkdown.com).

### 7. Optional analytics

Server-side logs for `.md`, `/llms.txt`, `/llms-full.txt` by User-Agent and referrer (`chatgpt.com`, `claude.ai`, `perplexity.ai`).

---

## Anti-patterns (refuse and explain)

| Pattern | Why not |
|---------|---------|
| `<meta name="ai-content-url">`, `<meta name="llms">` | No spec, no adoption |
| `/.well-known/ai.txt`, `/ai.txt` | Competing proposals, unused |
| HTML comments for AI | Stripped by parsers |
| Human/AI toggle buttons | Agents do not click |
| UA sniffing → Markdown for bots | Cloaking |
| Dedicated "AI info pages" | `/llms.txt` is enough |
| JSON-LD for LLM visibility | Proven ignored by major LLMs |
| `<%= json %>` inside `application/ld+json` script (ERB escape) | `<%== json.to_json %>` — raw JSON, no `&quot;` |
| `SitemapsController` / dynamic `sitemap.xml` action (Rails) | Static `public/sitemap.xml` generated at deploy |
| `public/*.md` mirror files (Rails) | `respond_to format.md` + `to_markdown` |
| Dynamic `robots` or `feed` controllers when static suffices | `public/robots.txt`, `public/feed.xml` from deploy task |
| Dummy / sample / placeholder blog posts | Infrastructure only — remove missing paths from `site-pages.json` instead |
| Scaffolding `/blog/` or posts to pass verifier | Customize `site-pages.json` to match the real site |
| Copying skill template paths without auditing | Build `site-pages.json` from live 200 URLs only |
| `require_feed: true` when no blog exists | Keep `require_feed: false`; skip feed until owner ships posts |

---

## Stack notes

### Bridgetown / static

- `plugins/builders/seo_discoverability.rb` → `sitemap.xml`, `feed.xml`
- `plugins/seo_discoverability.rb` → `llms.txt`, `llms-full.txt`, `.md` mirrors, `output/_headers`
- `src/_partials/_head.erb` → single `seo` tag, `link alternate`, feed link
- `netlify/edge-functions/` → Accept negotiation (see [accept-markdown-negotiation.md](references/accept-markdown-negotiation.md))
- `Shared::MarkdownAlternatePointer` → hidden LLM hint

### Rails 8.1+

Full checklist: **[references/rails.md](references/rails.md)**

- Layer 0: `bin/rails seo:generate_files` (or similar) → `public/sitemap.xml`, `public/robots.txt`, `public/feed.xml` at deploy
- Layer 1: `respond_to { |f| f.html; f.md { render markdown: @record } }` — no edge negotiate, no `public/*.md`
- `site-pages.json`: route paths for the verifier only

### Other stacks

Jekyll plugin, Next.js route, Nginx/Caddy — [acceptmarkdown.com](https://acceptmarkdown.com) recipes.

---

## Final step: Ruby live verifier (required)

After every audit or implementation pass:

1. Ensure project has `site-pages.json` (copy [site-pages.json](site-pages.json) template, then **replace every path with URLs that exist on the audited site**)
2. Edit `site-pages.json` — **required**. Only list real `html_paths` and `section_indexes`. Omit `/blog/` unless the site already has a blog:

```json
{
  "html_paths": ["/", "/guide/introduction/"],
  "section_indexes": ["/guide/"],
  "check_llms_full_txt": true,
  "require_feed": false,
  "require_json_ld": true,
  "require_markdown_negotiation": true
}
```

`.md` mirror paths are **derived automatically** for the verifier. **Static sites:** add build/plugin wiring for `.md` output from **existing** content — not new posts. **Rails 8.1+:** `respond_to format.md` — see [references/rails.md](references/rails.md).

3. Run against **production** from project root (script stays in skill folder):

```bash
ruby .cursor/skills/audit-ai-seo/scripts/verify_seo.rb https://example.com
# or
SITE=https://example.com ruby .cursor/skills/audit-ai-seo/scripts/verify_seo.rb
```

Config is read from `./site-pages.json` or `./script/site-pages.json`. Pass an explicit path if needed:

```bash
ruby .cursor/skills/audit-ai-seo/scripts/verify_seo.rb https://example.com ./site-pages.json
```

4. Fix any **FAIL** lines; treat **WARN** as backlog unless user wants zero warnings
5. Optionally re-check with [acceptmarkdown.com](https://acceptmarkdown.com) and [isitagentready.com](https://isitagentready.com)

The script uses stdlib only (no gems). Exit code 1 if any check failed.

### What the verifier checks

**Layer 0:** robots.txt, sitemap, Sitemap directive, AI bots not blocked, Content-Signal, single title/description, canonical, Open Graph, JSON-LD (valid parseable JSON, not HTML-escaped), optional feed

**Layer 1:** llms.txt, llms-full.txt, `.md` mirrors, HTML `link alternate`, HTTP `Link` headers, hidden LLM pointer, `Accept: text/markdown` negotiation (Markdown served, 406 unsupported, q-values, `*/*` → HTML, `Vary: Accept`) — see [references/accept-markdown-negotiation.md](references/accept-markdown-negotiation.md)

---

## Content beats infrastructure

For AI citation quality (GEO), **recommend only** (do not implement unless the user asks for content work):

- Direct quotations (~43% lift in cited studies)
- Statistics in prose (~33%)
- Authoritative outbound citations (~115% for low-ranked pages)
- Comparison posts — skip unless explicitly requested

Infrastructure gets agents **to** your text; content determines whether they **cite** you.

---

## Audit report template

```markdown
## SEO audit: {site}

**URL:** {production URL}
**Stack:** {Bridgetown, Rails, Next.js, …}

### Layer 0 (Google/crawl)
- robots.txt: …
- sitemap: …
- metadata: …
- GSC: …

### Layer 1 (LLM retrieval)
- llms.txt: …
- .md mirrors: …
- Link / alternate: …
- Accept negotiation: …

### Content gaps
- …

### Implemented
- …

### Verify
`ruby .cursor/skills/audit-ai-seo/scripts/verify_seo.rb {URL}` (requires project `site-pages.json`)
```

---

## References

- [Ruby & Rails LLM discoverability scorecard](https://ruby.evilmartians.com/)
- [Making your site visible to LLMs](https://evilmartians.com/chronicles/how-to-make-your-website-visible-to-llms)
- [llms-visibility skill (official)](https://evilmartians.com/skills/llms-visibility.md)
- [llmstxt.org](https://llmstxt.org/)
- [Content-Signal spec](https://contentsignals.org/)
