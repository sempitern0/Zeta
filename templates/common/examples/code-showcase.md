---
title: "Zeta Code Showcase"
author: __ZETA_AUTHOR_YAML__
date: __ZETA_DATE_YAML__
description: "Multiple fenced code blocks to validate Pandoc syntax highlighting."
slug: "zeta-code-showcase"
tags:
  - "code"
  - "pandoc"
  - "demo"
---

Use this post to confirm syntax highlighting, horizontal scrolling and code readability.

## Bash

```bash
#!/usr/bin/env bash
set -euo pipefail

for file in posts/*.md; do
    printf 'Building %s\n' "$file"
done
```

## Python

```python
from pathlib import Path

posts = sorted(Path("posts").glob("*.md"))
print(f"{len(posts)} post(s)")
```

## JavaScript

```javascript
const posts = ["first.md", "second.md"];
posts.forEach((post) => console.log(post));
```

## YAML

```yaml
site:
  title: "Zeta"
build:
  content_dir: "posts"
  output_dir: "public"
```

## JSON

```json
{
  "generator": "Zeta",
  "static": true,
  "dependencies": ["bash", "pandoc"]
}
```

## CSS

```css
:focus-visible {
  outline: 2px solid currentColor;
  outline-offset: 3px;
}
```

## HTML

```html
<main id="content">
  <article>
    <h1>Accessible static HTML</h1>
  </article>
</main>
```
