<!-- navenv:repo -->
## navenv — project key: WEALTH-QUEST

This repo is project **WEALTH-QUEST** (`easyaman/wealth-quest`, public). Read `.navenv.json`
for the repo, branch prefix, commit tag and PR base.

- **GitHub is the only account this project uses** — the `easyaman` personal account, *not*
  the work account `nopparatk-jpg`. `.envrc` points `GH_CONFIG_DIR` at an isolated gh config
  where only `easyaman` exists, so `gh` cannot pick the wrong account inside this folder.
- There is **no backend**: no Vercel, no Supabase, no Clerk, no Stripe, no MongoDB. If a task
  suggests deploying or provisioning any of these, it is confusing this project with another
  one under `/Users/artnopparat/IT Dept/Tech part/`.
- `commit_tag` and `branch_prefix` are deliberately empty — keep the existing Thai commit
  style (`Godot: …`, `เอกสาร: …`); no prefix is required.
- Only touch this repo's remote, branches, commits and PRs; verify any SHA / branch / PR
  exists here before using it. Run `bash ~/.claude/skills/navenv/scripts/navenv-check.sh`
  before push / PR. If a task concerns another project, say so and switch with
  `/navenv use <OTHER_KEY>` — never mix.
