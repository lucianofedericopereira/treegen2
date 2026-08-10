# treegen2

Every release, as it ships. This page is generated automatically from changelog.md — edit the markdown and reload to update it.

## 0.1.0 — August 10, 2026

- Added the initial from-scratch Perl port of [treegen](https://github.com/lucianofedericopereira/treegen): a full CLI (`bin/treegen2`), directory scanner, `.gitignore`-style matcher, and all three renderers (`ascii`, `svg`, `collapsible`)
- Added fence-aware Markdown/HTML splicing for both `[[files]]` placeholders and `<!-- filetree:start/end -->` marker blocks, matching the original tool's syntax exactly
- Added a hand-rolled, core-only JSON reader for `.filetree.json` descriptions, avoiding a dependency on `JSON::PP`
- Added `action.yml`, a composite GitHub Action with no interpreter setup step — GitHub-hosted runners ship Perl natively
- Added a CI workflow that runs the full test suite unmodified across Perl 5.8 through the latest release, proving two decades of language stability rather than just claiming it
- Added a 195-test suite (`prove -Ilib -r t`) covering config parsing, the ignore matcher, the scanner, all three renderers, marker/placeholder splicing, and the CLI end to end
- Added the project website (`index.html`, `docs.html`, `changelog.html`) with live-rendered demos, and this changelog
