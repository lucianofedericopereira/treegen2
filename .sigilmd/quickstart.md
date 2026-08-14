```yaml
name: Update file tree
on:
  push:
    branches: [main]
permissions:
  contents: write        # so the action can push the updated README
jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: lucianofedericopereira/treegen2@v0.1
        with:
          style: ascii    # ascii | svg | collapsible
```
