# Operation Safety

## Allowed Automatically

- read files
- search files
- `gh repo view/list`
- `gh issue/pr view/list`
- clone
- fetch
- run non-destructive checks

## Allowed When Task Clearly Implies Coding

- create branch
- edit files
- run tests
- commit locally

## Requires Explicit User Intent Or Confirmation

- push branch
- create PR
- comment on issue/PR
- update Linear/Notion/Slack
- delete remote branch
- delete workspace with dirty or unpushed changes
