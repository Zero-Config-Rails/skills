# audit-ai-seo

Audit and implement **Google SEO** and **LLM discoverability** for websites, docs, blogs, and landing pages.

An [Agent Skill](https://agentskills.io/home); works in **Cursor**, **Claude** (Claude Code / Claude.ai), and any agent that supports the open standard. Includes a stdlib Ruby verifier and a required `site-pages.json` config.

Full agent workflow: [SKILL.md](SKILL.md)

## What it covers

Two layers, equal priority:

| Layer | Goal |
|-------|------|
| **Layer 0 — Google/crawl** | robots.txt, sitemap, meta tags, Open Graph, JSON-LD, feeds, canonical URLs |
| **Layer 1 — LLM retrieval** | `/llms.txt`, `.md` mirrors, `Link` headers, `Accept: text/markdown` negotiation, Content-Signal |

The skill **refuses debunked patterns** (`ai.txt`, AI-specific meta tags, User-Agent sniffing) and ends every audit or implementation with a live verifier run.

## When to use

- New site or docs: baseline audit before launch
- Existing site: "why aren't we in AI answers / Google?"
- After shipping discoverability changes: confirm production with the verifier

Ask your agent (Cursor, Claude Code, etc.) to audit SEO, implement LLM visibility, or run the verify script against your live URL.

## Install

### Project install (recommended)

Add the skill to the repo you're auditing so the whole team shares the same workflow. Commit `.cursor/skills/` or `.claude/skills/` with your project.

**Cursor** — from your project root:

```bash
git clone git@github.com:Zero-Config-Rails/skills.git /tmp/zcr-skills
cp -r /tmp/zcr-skills/audit-ai-seo .cursor/skills/
git add .cursor/skills/audit-ai-seo
```

**Claude Code** — from your project root:

```bash
git clone git@github.com:Zero-Config-Rails/skills.git /tmp/zcr-skills
cp -r /tmp/zcr-skills/audit-ai-seo .claude/skills/
git add .claude/skills/audit-ai-seo
```

After the agent runs an audit, copy the verifier into the same project (not the skills folder):

```bash
mkdir -p script
cp .cursor/skills/audit-ai-seo/scripts/verify_seo.rb script/
cp .cursor/skills/audit-ai-seo/site-pages.json script/
# edit script/site-pages.json for your URLs, then:
ruby script/verify_seo.rb https://example.com
```

### Global install (optional)

Use on any project without committing the skill to each repo.

| Agent | Path |
|-------|------|
| Cursor | `~/.cursor/skills/audit-ai-seo` |
| Claude Code | `~/.claude/skills/audit-ai-seo` |

```bash
git clone git@github.com:Zero-Config-Rails/skills.git
cp -r skills/audit-ai-seo ~/.cursor/skills/audit-ai-seo   # or ~/.claude/skills/
```

Other clients: same folder layout; see [agentskills.io](https://agentskills.io/home) for paths.

## Agent workflow

1. Audit the live site (or local build output)
2. Report gaps as Layer 0 vs Layer 1 vs content
3. Implement fixes (each step is independently shippable)
4. Verify with `scripts/verify_seo.rb` against the **production** URL
5. Copy `verify_seo.rb` and `site-pages.json` into the target project for ongoing checks

## Live verifier

Stdlib-only Ruby script. No gems. **Requires `site-pages.json`** — lists which pages on your site to check.

Copy both files into your project:

```bash
cp scripts/verify_seo.rb /path/to/project/script/
cp site-pages.json /path/to/project/script/
```

Edit `site-pages.json` with your real HTML paths, `.md` mirrors, and section indexes, then run:

```bash
ruby script/verify_seo.rb https://example.com
# or
SITE=https://example.com ruby script/verify_seo.rb
```

The script finds `site-pages.json` next to itself or in the working directory. Override with an explicit path:

```bash
ruby script/verify_seo.rb https://example.com ./script/site-pages.json
```

### site-pages.json

| Key | Required | Purpose |
|-----|----------|---------|
| `sample_html_paths` | yes | HTML pages to check (title, OG, canonical, JSON-LD, Link headers) |
| `sample_md_paths` | yes | `.md` mirror URLs to fetch |
| `section_indexes` | yes | Section landing pages (`html` + `md` pairs); use `[]` if none |
| `check_llms_full_txt` | no | Check `/llms-full.txt` exists (default `true`; set `false` for blogs) |
| `require_feed` | no | Check `/feed.xml` (default `false`) |
| `require_json_ld` | no | Require JSON-LD on sample HTML pages (default `true`) |
| `require_markdown_negotiation` | no | Test `Accept: text/markdown` (default `true`) |

Example (included in this skill as [site-pages.json](site-pages.json)):

```json
{
  "sample_html_paths": ["/", "/guide/introduction/"],
  "sample_md_paths": ["/index.md", "/guide/introduction.md"],
  "section_indexes": [
    { "html": "/guide/", "md": "/guide.md" },
    { "html": "/blog/", "md": "/blog.md" }
  ],
  "check_llms_full_txt": true,
  "require_feed": false,
  "require_json_ld": true,
  "require_markdown_negotiation": true
}
```

Exit code `1` if any check **FAIL**s; **WARN** lines are backlog unless you want zero warnings.

### What it checks

**Layer 0:** robots.txt, sitemap, Sitemap directive, AI bots not blocked, Content-Signal, single title/description, canonical, Open Graph, JSON-LD, optional feed

**Layer 1:** `llms.txt`, `llms-full.txt`, `.md` mirrors, HTML `link alternate`, HTTP `Link` headers, hidden LLM pointer, `Accept: text/markdown` + `Vary: Accept`

Optional external scanners after a green run:

- [acceptmarkdown.com](https://acceptmarkdown.com)
- [isitagentready.com](https://isitagentready.com)
- [ruby.evilmartians.com](https://ruby.evilmartians.com/)

## Stack notes

Documented for Bridgetown / static-site patterns in [SKILL.md](SKILL.md#stack-notes-bridgetown--static). The same outputs apply to Jekyll, Next.js, Rails, or Nginx/Caddy — different build hooks, same deliverables.

## References

- [Agent Skills](https://agentskills.io/home)
- [Ruby & Rails LLM discoverability scorecard](https://ruby.evilmartians.com/)
- [Making your site visible to LLMs](https://evilmartians.com/chronicles/how-to-make-your-website-visible-to-llms)
- [llms-visibility skill](https://evilmartians.com/skills/llms-visibility.md)
- [llmstxt.org](https://llmstxt.org/)
