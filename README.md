# Zero Config Rails Skills

[Agent Skills](https://agentskills.io/home) from the [Zero-Config-Rails](https://github.com/Zero-Config-Rails) ecosystem — one folder per skill, each with a `SKILL.md` that teaches an agent a specialized workflow.

Works with **Cursor**, **Claude** (Claude Code and Claude.ai), and any other agent that implements the [Agent Skills open standard](https://agentskills.io/home).

## What are skills?

Agent Skills are lightweight instruction packs. At startup an agent loads each skill's `name` and `description`; when a task matches, it reads the full `SKILL.md` and follows the workflow. Bundled scripts and references load only when needed.

## Install a skill

Pick the skill you need from the table below and follow **that skill's README** — install steps, config, and invoke commands live there.

You install **one skill folder** into your project (e.g. `.cursor/skills/audit-ai-seo/`), not this whole repository. Each README has copy-paste commands to fetch just that skill and rsync it into your project without a nested `.git`.

| Skill | Use when |
|-------|----------|
| **[audit-ai-seo](audit-ai-seo/README.md)** | Google SEO + LLM/AI discoverability (robots, sitemaps, `llms.txt`, `.md` mirrors, Accept negotiation) |

## Repository layout

```
skills/
├── README.md                 # this file — catalog only
└── audit-ai-seo/             # one self-contained skill
    ├── README.md             # install, setup, invoke (start here)
    ├── SKILL.md              # agent workflow (source of truth)
    ├── site-pages.json       # verifier config template
    ├── references/           # on-demand docs (e.g. Accept negotiation)
    └── scripts/
        └── verify_seo.rb
```

## Adding a skill

1. Create a directory with a `SKILL.md` (YAML frontmatter with `name` and `description`, plus markdown body).
2. Add optional `scripts/`, `references/`, or `assets/` as needed.
3. Add a skill-specific `README.md` with install, setup, and invoke instructions.
4. List the skill in the table above.

Follow the [Agent Skills specification](https://agentskills.io/specification) and [quickstart](https://agentskills.io/skill-creation/quickstart).
