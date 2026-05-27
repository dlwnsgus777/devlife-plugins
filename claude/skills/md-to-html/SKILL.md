---
name: md-to-html
description: Convert a Markdown file into a beautiful, production-grade standalone HTML page. Use this skill whenever the user provides a .md file and wants it turned into an HTML page or visual document — even if they say "render this", "make it look nice", "generate a webpage from this", "MD를 HTML로", "마크다운으로 웹페이지 만들어줘", "이 MD 파일로 HTML 만들어줘", Trigger even when the user pastes Markdown content directly without a file path.
---

Read the provided `.md` file (or treat pasted text as raw Markdown), then use the `frontend-design` skill to produce a single self-contained `.html` file.

## Steps

1. **Read** the `.md` file the user specified (or use pasted content).
2. **Hand off to `frontend-design`** — pass the Markdown content as the design requirement. The output must be:
   - A single `.html` file with all CSS and JS embedded (no external dependencies)
   - All Markdown elements rendered: headings, lists, blockquotes, code blocks, tables, links, images
3. **Save** the file as `[input-name].html` next to the source file (or in the current directory if content was pasted).
4. **Report** the output path to the user.
