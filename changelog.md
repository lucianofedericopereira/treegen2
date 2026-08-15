# treegen2

Every release, as it ships. This page is generated automatically from changelog.md — edit the markdown and reload to update it.

## v0.2.0 — August 15, 2026

- Fixed four `uses: lucianofedericopereira/treegen2@v1` pins in the README that never matched any real tag — the actual published tag is `v0.1`; rewrote the "Publishing to Marketplace" section to describe the direct-tag-pin flow this project actually uses pre-1.0, instead of a `v1.0.0` release plus a floating `v1` alias that was never cut
- The README's "Read the Docs" link is now a proper badge (GitHub logo, `for-the-badge`, matching sigilbadges/sigilmd) instead of a one-off `<h2>` link with its own icon asset; the top logo image is now centered and size-capped to match its siblings
- The four places the README shows the action's version pin now derive from small snippet files declared in `sigilmd.toml`, kept in sync by `sigilmd` itself, instead of four separately hand-maintained copies of the same string

## v0.1.0 — August 10, 2026

- Added the initial from-scratch Perl port of [treegen](https://github.com/lucianofedericopereira/treegen): a full CLI (`bin/treegen2`), directory scanner, `.gitignore`-style matcher, and all three renderers (`ascii`, `svg`, `collapsible`)
- Added fence-aware Markdown/HTML splicing for both `[[files]]` placeholders and `<!-- filetree:start/end -->` marker blocks, matching the original tool's syntax exactly
- Added a hand-rolled, core-only JSON reader for `.filetree.json` descriptions, avoiding a dependency on `JSON::PP`
- Added `action.yml`, a composite GitHub Action with no interpreter setup step — GitHub-hosted runners ship Perl natively
- Added a CI workflow that runs the full test suite unmodified across Perl 5.8 through the latest release, proving two decades of language stability rather than just claiming it
- Added a 195-test suite (`prove -Ilib -r t`) covering config parsing, the ignore matcher, the scanner, all three renderers, marker/placeholder splicing, and the CLI end to end
- Added the project website (`index.html`, `docs.html`, `changelog.html`) with live-rendered demos, and this changelog
