# Zero Config Rails Skills

[Agent Skills](https://agentskills.io/home) from the [Zero-Config-Rails](https://github.com/Zero-Config-Rails) ecosystem — portable folders with a `SKILL.md` that teach an agent a specialized workflow.

Works with **Cursor**, **Claude** (Claude Code and Claude.ai), and any other agent that implements the [Agent Skills open standard](https://agentskills.io/home).

## What are skills?

Agent Skills are lightweight instruction packs. At startup an agent loads each skill's `name` and `description`; when a task matches, it reads the full `SKILL.md` and follows the workflow. Bundled scripts and references load only when needed.

That gives agents domain-specific checklists, conventions, and tooling so audits and implementations stay consistent across projects — regardless of which skills-compatible client you use.

## Installation

**Project install (recommended)** — install the skill inside the project so the whole team shares the same workflow.

From your project root:

**Cursor**

```bash
mkdir -p /tmp .cursor/skills
git clone git@github.com:Zero-Config-Rails/skills.git /tmp/zcr-skills
cp -r /tmp/zcr-skills/audit-ai-seo .cursor/skills/
```

**Claude Code**

```bash
mkdir -p /tmp .claude/skills
git clone git@github.com:Zero-Config-Rails/skills.git /tmp/zcr-skills
cp -r /tmp/zcr-skills/audit-ai-seo .claude/skills/
```

Or add as a git submodule:

```bash
mkdir -p .cursor/skills
git submodule add git@github.com:Zero-Config-Rails/skills.git .cursor/skills/zcr-skills
# then symlink or copy the skill you need, e.g.:
ln -s zcr-skills/audit-ai-seo .cursor/skills/audit-ai-seo
```

**Other agents** (Codex, Copilot, Gemini CLI, OpenCode, etc.)

Use the same skill folder under your client's project skills path; see [agentskills.io](https://agentskills.io/home).

### Global install (optional)

Install once on your machine if you want the skill in every project without adding it to each repo.

**Cursor**

```bash
mkdir -p /tmp ~/.cursor/skills
git clone git@github.com:Zero-Config-Rails/skills.git /tmp/zcr-skills
cp -r /tmp/zcr-skills/audit-ai-seo ~/.cursor/skills/audit-ai-seo
# or symlink while developing:
ln -s "$(pwd)/audit-ai-seo" ~/.cursor/skills/audit-ai-seo
```

**Claude Code**

```bash
mkdir -p /tmp ~/.claude/skills
git clone git@github.com:Zero-Config-Rails/skills.git /tmp/zcr-skills
cp -r /tmp/zcr-skills/audit-ai-seo ~/.claude/skills/audit-ai-seo
```

Global paths: `~/.cursor/skills/audit-ai-seo` (Cursor), `~/.claude/skills/audit-ai-seo` (Claude Code).

## Available skills

| Skill | Directory | Use when |
|-------|-----------|----------|
| [audit-ai-seo](audit-ai-seo/README.md) | `audit-ai-seo/` | Auditing or implementing Google SEO plus LLM/AI discoverability (robots, sitemaps, `llms.txt`, `.md` mirrors, Accept negotiation) |

## Repository layout

```
skills/
├── README.md                 # this file
└── audit-ai-seo/
    ├── README.md             # skill overview and verifier usage
    ├── SKILL.md              # full agent workflow (source of truth)
    ├── site-pages.json       # required: which pages to verify (copy with script)
    └── scripts/
        └── verify_seo.rb     # live production verifier (stdlib Ruby)
```

## Adding a skill

1. Create a directory with a `SKILL.md` (YAML frontmatter with `name` and `description`, plus markdown body).
2. Add optional `scripts/`, `references/`, or `assets/` as needed.
3. Add a skill-specific `README.md` for humans.
4. List the skill in the table above.

Follow the [Agent Skills specification](https://agentskills.io/specification) and [quickstart](https://agentskills.io/skill-creation/quickstart).
