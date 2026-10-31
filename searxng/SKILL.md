---
name: searxng
description: "Search the web and verify current prices and market data through a SearXNG instance (a self-hosted, privacy-respecting metasearch engine). Use when a task needs web search — product prices, price history, market news, component specs — especially when public search engines or retailer sites (Google, Bing, DuckDuckGo, Mojeek, Amazon, B&H, Newegg, PCPartPicker) bot-block the agent's egress IP with CAPTCHAs or 403s, or when the user has a local SearXNG instance and wants it used. Resolves the instance at runtime from an --endpoint flag, the SEARXNG_URL environment variable, or a local config file; never falls back to a public instance."
compatibility: "Requires bash, curl, and network access to a SearXNG instance. No other dependencies."
metadata:
  author: createthis
  version: "1.0"
---

# SearXNG search

Web search and price verification through a SearXNG instance, via its JSON API. This skill exists because public search engines and many retailer pages bot-block datacenter egress IPs, while a SearXNG instance — especially a self-hosted one — gives the agent structured, reliable search results.

## Endpoint resolution

The instance endpoint is resolved at runtime; nothing is hardcoded in this skill. First match wins:

1. `--endpoint URL` flag (one-off override)
2. `SEARXNG_URL` environment variable
3. `searxng.local` in the skill directory (see `searxng.example`)
4. `~/.config/searxng-search/endpoint`

Format: base URL only — no trailing slash, no `/search` path. The `searxng.local` file is gitignored and never ships.

If the script reports "no SearXNG endpoint configured": check this machine's AGENTS.md or memory for a documented local instance and pass it via `--endpoint`. If the user has no instance, offer to start one: `docker run -d --name searxng -p 8086:8080 searxng/searxng`, then point the script at `http://localhost:8086`.

There is deliberately **no public fallback**: queries may contain private hostnames or sensitive product research, so this skill never routes them to a third-party instance unless the user explicitly says to.

## Usage

```bash
scripts/searxng.sh "RTX PRO 6000 Blackwell 96GB price"
scripts/searxng.sh --endpoint http://your-instance:8086 "NEMIX 384GB DDR5 RDIMM kit"
```

Output is the SearXNG JSON API response on stdout:

- `results[]` — `title`, `url`, `content` (snippet)
- `unresponsive_engines` — upstream engines that CAPTCHA'd or rate-limited on *this* query
- `answers`, `infoboxes`, `suggestions`

`unresponsive_engines` commonly lists brave/duckduckgo/startpage (they CAPTCHA datacenter IPs through the metasearch); other engines usually still return hits, so a partial set is normal. If `results` is empty, reword the keywords and retry once before concluding nothing was found.

## Field notes (hard-won)

- From cloud/datacenter egress, direct fetches to Google, Bing, DuckDuckGo, Mojeek, Ecosia, Amazon, B&H, Newegg, and PCPartPicker typically 403 or CAPTCHA. Search *through* SearXNG instead. (Residential IPs may reach some of these directly.)
- To get exact current prices rather than snippets, follow through on promising results:
  - **Shopify stores** expose a clean catalog: `https://store.example.com/products/<handle>.json` — per-variant prices, no scraping.
  - **Price trackers** (camelcamelcamel, pangoly) show up in SearXNG results with dated price history — good for distinguishing "the price then" from "the price now".
  - **Press** (wccftech, tomshardware, networkworld) via SearXNG gives dated market context: launch prices, price hikes, shortage reports.
- SearXNG rate-limits its upstreams under heavy use: prefer a few precise keyword queries over many broad ones.
- SearXNG's own product pages (nemixram.com, microcenter, etc.) are usually fetchable directly once you have the URL from a result.

## Privacy

The endpoint is the user's instance. This skill makes network calls only to the resolved endpoint, never defaults to a public SearXNG, and never logs queries.
