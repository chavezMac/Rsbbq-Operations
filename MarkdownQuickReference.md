# Markdown & DocC Quick Reference

Use this file as a quick reference while editing `Overview.md` or other DocC articles.

---

## Headings

```markdown
# H1 (page title)
## H2 (major section)
### H3 (subsection)
#### H4
```

---

## Text

| Syntax | Result |
|--------|--------|
| `**bold**` | **bold** |
| `*italic*` | *italic* |
| `` `code` `` | `code` |
| `~~strikethrough~~` | ~~strikethrough~~ |

---

## Lists

**Unordered:**
```markdown
- Item one
- Item two
  - Nested item
```

**Ordered:**
```markdown
1. First
2. Second
3. Third
```

**Task list (GitHub-style):**
```markdown
- [ ] Unchecked
- [x] Checked
```

---

## Links

| Type | Syntax | Use |
|------|--------|-----|
| URL | `[text](https://example.com)` | External link |
| DocC article | `<doc:ArticleName>` | Link to another article in the catalog (use filename without .md) |
| Symbol | `` `TypeName` `` or `` `methodName()` `` | Link to documented Swift type or symbol (double backticks) |

---

## Code blocks

**Fenced (with optional language):**
````markdown
```swift
let x = 42
```
````

**Inline:** Use single backticks: `let value = 0`

---

## Blockquote / Callouts (DocC)

```markdown
> Note: A short note.

> Important: Something important.

> Warning: Be careful.

> Tip: A helpful tip.
```

(Some DocC renderers support custom callout titles.)

---

## Tables

```markdown
| Column A | Column B |
|----------|----------|
| Cell 1   | Cell 2   |
| Cell 3   | Cell 4   |
```

---

## Horizontal rule

```markdown
---
```

---

## DocC-specific (for Overview.md)

- **Link to another article:** `<doc:GettingStarted>` (filename without `.md`)
- **Link to a symbol:** `` `AuthManager` ``, `` `APIService.shared` ``, `` `storeCode` ``
- **Topics section** (shows in DocC sidebar):
  ```markdown
  ## Topics
  ### Category name
  - <doc:OtherArticle>
  - ``SymbolName``
  ```
- **Images:** Place images in the `.docc` bundle and reference with `![Alt text](image.png)`

---

## Escaping

Use backslash before a character to treat it literally: `\*` → *, `\#` → #, `` \` `` → `

---

## Minimal Overview.md structure

```markdown
# Your Module Name

One-line description.

## Overview

Bullet or paragraph describing what the app/module does.

## Topics

### Getting started
- <doc:AnotherArticle>

### API reference
Use the sidebar or link symbols: ``MyType``.
```
