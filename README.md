# Ohyun Kwon — Portfolio Website

My art portfolio, built with [Hugo](https://gohugo.io/) and hosted free on GitHub Pages.
Every time changes are pushed to GitHub, the site rebuilds itself in about a minute.

## The 4 commands you need

Run these from the project folder in Terminal:

| Command | What it does |
| --- | --- |
| `./scripts/dev.sh` | Preview the site on your computer at http://localhost:1313 (updates live as you edit; `Ctrl+C` to stop) |
| `./scripts/check.sh` | Checks everything (missing images, empty info, file sizes, build). Must say PASS before publishing |
| `./scripts/publish.sh "what I changed"` | Shrinks new images/videos, checks, saves, and uploads. The live site updates ~1 minute later |
| `./scripts/status.sh` | Shows whether everything is saved and whether the live site is up |

## Where things live

```text
content/
├── about/index.md            ← About Me text + which artwork is the profile picture
└── works/
    ├── paintings-drawings/   ← one folder per artwork
    ├── multimedia/
    └── digital-graphics/
data/ec.yaml                  ← activities list on the About page
static/ohyun-kwon-resume.pdf  ← the resume people download
```

Each artwork is one folder, for example `content/works/paintings-drawings/growing-online/`:

- `image.jpg` — the artwork (videos: `video.mp4`, plus `poster.jpg` which is made automatically)
- `index.md` — the info:

```markdown
---
title: "Growing Online"
year: "2026"
medium: "Acrylic markers, acrylic paint, pen on canvas"
dimensions: "66.95 x 46.81 x 1.50 cm"
weight: 6
---
The description goes here. Leave an empty line between paragraphs.
```

- Leave a field as `""` if you don't know it yet — it simply won't show on the site.
- `weight` = the order inside the category (1 shows first).

## Common edits

**Add a new artwork**
1. Make a new folder inside the right category. Name it with lowercase words joined by `-` (e.g. `my-new-painting`). No spaces.
2. Put the picture in it named `image.jpg` (or the video named `video.mp4`).
3. Copy an `index.md` from another artwork, then change the info.
4. `./scripts/dev.sh` to preview → `./scripts/publish.sh "Add My New Painting"`.

**Replace an artwork's picture** — drop the new file in with the same name (`image.jpg`), then publish. Big photos are shrunk automatically.

**Fix text** — edit that artwork's `index.md`, then publish.

**Remove an artwork** — move its folder out of `content/` (for example into `.archive/`), then publish.

**Change the profile picture** — in `content/about/index.md`, change `profile_work:` to another artwork's folder path, e.g. `"digital-graphics/daisy-of-media"`.

**Change which picture is behind each category on the Works page** — in that category's `_index.md`, change `cover:` to an artwork folder name.

**Update the resume** — replace `static/ohyun-kwon-resume.pdf` with the new PDF (keep the same file name).

**Update activities** — edit `data/ec.yaml`. Keep the same layout (spaces at the start of lines matter).

## If something goes wrong

- `check.sh` says ❌ — read the line; it names the file and what's wrong.
- The live site didn't change — run `./scripts/status.sh`. If the build failed on GitHub, the old site stays online; fix the problem and publish again.
- Not sure? Ask for help before forcing anything.
