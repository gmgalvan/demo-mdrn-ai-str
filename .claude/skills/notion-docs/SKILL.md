---
name: notion-docs
description: Use whenever the user asks to check, consult, or look something up in Notion / the project's Notion docs. Restricts every Notion lookup to a single fixed page — never search the wider Notion workspace.
---

# Notion docs (single page only)

This project's Notion reference lives entirely on one page. Every Notion
lookup for this repo must be scoped to that page — never the wider
workspace.

- Page URL: https://app.notion.com/p/About-398c0842b98a80178d66dff4c0abff3f

## Steps

1. Call `mcp__claude_ai_Notion__notion-fetch` with the URL above (or the
   page ID `398c0842b98a80178d66dff4c0abff3f`) to read the page content.
2. If the answer requires a sub-page or block linked from that page, fetch
   it by its own URL/ID, but only if it is reached by following a link
   from the page above — do not branch out further than one hop.
3. If the information isn't on this page, tell the user it isn't there
   instead of falling back to `notion-search` or fetching other pages.

## Do not

- Do not call `notion-search`, `notion-query-database-view`, or
  `notion-query-meeting-notes` for this project — they search beyond the
  fixed page.
- Do not fetch any other Notion page/database unless the user explicitly
  gives you its URL in the same request.
