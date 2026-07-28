# ARCC MedicineBow — How-To Book

A [Quarto](https://quarto.org) book that onboards new researchers (ASCEND / ARID
performers) to the University of Wyoming's **ARCC MedicineBow** HPC cluster.

📖 **Published site:** https://nsf-ascend-engine.github.io/ARCC-how-to/

## How this book was written

This book was written in tandem with **Claude** — Anthropic's **Claude Opus 4.8** model
(`claude-opus-4-8`, 1M-token context), driven through **Claude Code** — working alongside a
human author. Claude harvested the live cluster, cross-checked every load-bearing claim
against the running machine, drafted and revised the prose, generated the diagrams and the
queue-time analysis, and a panel of Claude review agents audited the content for correctness
and clarity. A human directed the work and made the final calls. Fittingly, the book includes
a chapter on using agentic coding tools like Claude for cluster work.

## What's inside

Getting an account, first login and SSH keys, the three (unbacked-up) filesystems,
the Lmod module system, and a deep **Slurm** section — with a data-driven chapter on
**partition queue times** and **which partition/QOS to pick for short proof-of-concept
work versus long simulations**.

## Building locally

You need Quarto ≥ 1.7 (already installed at `~/.local/bin/quarto` on the ARCC login
nodes; otherwise get it from <https://quarto.org/docs/get-started/>).

```bash
quarto preview     # live-reloading local preview
quarto render      # build static site into _book/
```

## Deployment

Every push to `main` triggers `.github/workflows/publish.yml`, which renders the book
and pushes the HTML to the `gh-pages` branch.

**One-time setup** (after the first successful Action run):
GitHub → repo **Settings → Pages → Build and deployment → Source: Deploy from a branch**,
then select the **`gh-pages`** branch and `/ (root)` folder.

## Source of truth

Content is derived from `FINDINGS.md` and cross-checked against the live cluster
(`mblog1`, July 2026). Where the official ARCC wiki and the running machine disagree,
this book follows the machine and flags the conflict. Corrections welcome via issues or
`arcc-help@uwyo.edu`.
