---
name: md-to-html
description: Convert a Markdown file into a beautiful, production-grade standalone HTML page. Use this skill whenever the user provides a .md file and wants it turned into an HTML page or visual document — even if they say "render this", "make it look nice", "generate a webpage from this", "MD를 HTML로", "마크다운으로 웹페이지 만들어줘", "이 MD 파일로 HTML 만들어줘", Trigger even when the user pastes Markdown content directly without a file path.
---

Delegate the whole conversion to a sub-agent. The main session only resolves the input path, dispatches the sub-agent, and reports the resulting path back — the HTML body never enters the main context.

## Steps

### 1. Resolve input and output paths

- **Given a file path** — use it as-is, without opening the file. Output goes next to the source as `[input-name].html`.
- **Given pasted Markdown** — save it to the scratchpad as `pasted-<topic>.md` and use that path; a sub-agent does not inherit the conversation context, so pasted content must land in a file first. Output goes to the **current working directory** as `[topic].html`, never the scratchpad — that directory is session-scoped and the user would not find the file there.

### 2. Dispatch the sub-agent

Send the prompt below via `Agent({ subagent_type: "general-purpose", ... })`. To convert several `.md` files, dispatch one sub-agent per file in a single message so they run in parallel.

```
Convert one Markdown file into a standalone HTML page.

Input:  <INPUT_MD_PATH>
Output: <OUTPUT_HTML_PATH>

Steps:
1. Load the `frontend-design` skill with the Skill tool first, to pick up the design standards.
2. Read the input file and treat its content as the design requirement for the page.
3. Write the result to the output path.

Output file requirements:
- A single `.html` file — all CSS/JS inlined, no external CDN, font, or image references
- Every Markdown element rendered: headings, lists, blockquotes, code blocks, tables, links, images
- Never summarize or drop source content — carry all of it over
- Must work by opening the file directly in a browser

Return value: the absolute path you saved, plus one sentence on what the document is. Do not return the HTML body.
```

### 3. Report the result

Give the user the path the sub-agent returned. If they ask for design changes, continue with the same sub-agent via `SendMessage` — the HTML context lives there.

## Guardrails

- Never read the `.md` or write HTML in the main session. That is the entire point of this delegation.
- If the input file does not exist, confirm the path with the user instead of dispatching.
- If the output would overwrite an existing `.html`, tell the user first.
