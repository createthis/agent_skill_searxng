# searxng — an Agent Skill

An [Agent Skills spec](https://agentskills.io/specification) skill that gives AI agents reliable web search and price verification through a SearXNG instance — via its clean `format=json` API — instead of getting CAPTCHA'd by public search engines and retailer sites.

## Why

Agents often need to verify current prices, market context, or product data. From cloud/datacenter egress IPs, the usual targets (Google, Bing, DuckDuckGo, Amazon, B&H, Newegg, PCPartPicker, and often Mojeek/Ecosia) respond with CAPTCHAs or 403s. A SearXNG instance — especially a self-hosted one, which is trivial to run — gives structured, reliable results and a working path to retailer pages.

The skill in one sentence: **search and price-verify through the user's SearXNG instance, resolved at runtime — never hardcoded, never a silent public fallback.**

## Configuration (the portable part)

The skill is fully parameterized and ships with **no endpoint of any kind**. The instance is resolved at runtime, first match wins:

1. `--endpoint URL` flag (one-off)
2. `SEARXNG_URL` environment variable
3. `searxng.local` next to the script (gitignored; see `searxng.example`)
4. `~/.config/searxng-search/endpoint`

That is what keeps the repo public-safe: your internal DNS name lives in your env var or your gitignored local file, and the public copy works for anyone who points it at their own instance.

## Contents

```
searxng/
├── SKILL.md              # the skill (frontmatter + endpoint resolution + field notes)
├── searxng.example       # committed config template (copy to searxng.local)
└── scripts/
    └── searxng.sh        # zero-dependency bash + curl JSON API client
```

**How it activates:** the description is written so the agent invokes the skill whenever a task needs web search or price verification — especially when public search engines or retailer sites are bot-blocking the agent. This is description-based model invocation per the Agent Skills spec, so the skill stays portable to any spec-compliant client. (OpenHands `triggers:` frontmatter is intentionally not used — it isn't part of the spec.)

## Install

### Project scope (applies to one repo)

```bash
cp -r searxng /path/to/your/repo/.agents/skills/
```

### User scope (applies to all your repos)

```bash
cp -r searxng ~/.agents/skills/
```

Then start a new agent conversation so the skill catalog is rebuilt. In OpenHands you can also verify under **Customize > Skills** — `searxng` should appear and be enabled.

### Point it at an instance

```bash
export SEARXNG_URL=http://your-instance:8086
```

…or in the skill directory:

```bash
cp searxng/searxng.example searxng/searxng.local
# edit SEARXNG_URL to your instance's base URL
```

No instance yet? The easiest one:

```bash
docker run -d --name searxng -p 8086:8080 searxng/searxng
```

## The rules (short version)

- Query the instance's JSON API: `GET /search?q=<query>&format=json`.
- Parse `results[]` (`title`, `url`, `content`); check `unresponsive_engines` — CAPTCHA'd upstreams (commonly brave/duckduckgo/startpage from datacenter IPs) are expected, other engines usually still return hits.
- For exact current prices, follow through on results: Shopify `/products/<handle>.json` for per-variant prices, price trackers (camelcamelcamel, pangoly) for dated history, press for market context.
- **No public fallback.** If no endpoint is configured, say so and offer to help start a local instance — never route the user's queries to a third-party SearXNG.

## Spec compliance

Valid against the Agent Skills spec: `name` matches the parent directory, lowercase-hyphen naming, required `name` + `description` frontmatter, description ≤ 1024 chars, body well under 500 lines. Optional spec fields used: `compatibility` (network requirements) and `metadata` (author, version). No non-spec fields, so the skill is portable to any Agent Skills client.
