# Interview — Kickoff Mode Question Flow

Target: **6–8 questions**. Hard cap: 10.

All structured choices use `AskUserQuestion`. Only project name + description are free-text (ask directly in output).

Record every answer to `project-config.json.intent` as you go. Skippable blocks record `skipped: true`.

---

## Tier 1 — Always ask (4 questions)

### Q1 — Project name + one-line description (free text)

Ask directly:
> *"What's the project called, and what does it do in one line?"*

Parse the response. Expect `"<name>: <description>"` or two lines. If ambiguous, one follow-up question max. Record both into `intent.name` and `intent.description`.

### Q2 — Kind (AskUserQuestion)

- `app` — user-facing application (web, mobile, desktop)
- `library` — reusable package/module
- `cli` — command-line tool
- `agent` — LLM-driven autonomous or semi-autonomous system
- `service` — backend API or daemon, no direct UI
- `research` — notebooks, scripts, exploratory code

### Q3 — Visibility (AskUserQuestion)

- `public` — open source, on public GitHub
- `private` — private repo, team access
- `solo-local` — just me, may not even leave this machine

Affects: git identity check, secret-scanning aggressiveness, CLAUDE.md boilerplate.

### Q4 — Stage (AskUserQuestion)

- `greenfield` — empty or near-empty, starting fresh
- `existing` — established codebase, adding Claude Code tooling now
- `forking` — just cloned or forked from upstream, modifying

Affects: whether to offer `/security-review` and `/feature-crew` as immediate next steps; how aggressive to be about CLAUDE.md rewrite.

---

## Tier 2 — Conditional (up to 4 questions)

### Branch A: Safety block — ask if `kind ∈ {agent, service, app, research}`

Skippable as a block with *"Skip safety questions (all defaults: tier=minimal)"*.

#### Q5 — External content sources (AskUserQuestion, multiSelect=true)

*"What external content will this project ingest? Select all that apply."*

- `user-urls` — URLs or files supplied by end-users
- `web-scrape` — scraped from public internet
- `email` — inbound email/SMS/chat
- `rag-docs` — pre-curated RAG / knowledge base
- `tool-outputs` — LLM tool-use results (WebFetch, Bash, third-party APIs)
- `none` — this project doesn't consume external untrusted content

If `none`, skip Q6 and Q7 — record threat_model as `{ sources: ["none"], trust: null, actions: null, cost: null }`.

#### Q6 — Source trust (AskUserQuestion)

*"Who controls the sources you just selected?"*

- `me-only` — I'm the sole source of inputs
- `trusted-partners` — known collaborators, vetted APIs
- `end-users` — my product's users (assume some adversarial)
- `internet` — fully adversarial, anyone can submit

#### Q7 — Agent actions after reading external (AskUserQuestion, multiSelect=true)

*"After the agent reads external content, what can it do?"*

- `read-only` — reports findings, doesn't act
- `write-files` — modifies local files
- `shell-exec` — runs shell commands
- `send-messages` — sends email, Slack, Telegram, SMS
- `spend-money` — makes paid API calls, provisions infra, purchases

Severity weight for tier mapping: `read-only` = low, `write-files` = med, `shell-exec`/`send-messages` = high, `spend-money` = critical.

### Branch B: Public-repo block — ask if `visibility = public`

#### Q-pub1 — Git identity confirmation (AskUserQuestion)

*"For commits in this repo, use:"*

- `noreply` — GitHub noreply email (`ID+username@users.noreply.github.com`) — private, recommended
- `work-email` — a specific work email (free-text follow-up)
- `current-global` — whatever `git config --global user.email` already is

If `current-global`, run `git config --global user.email` and echo it back. Warn if it looks like a personal gmail.

---

## Tier 3 — Preferences (1 question, optional)

Offer as *"Skip the preferences block (sane defaults)"* button alongside the question.

### Q8 — Testing posture (AskUserQuestion)

- `strict-tdd` — tests before code, always
- `pragmatic` — tests before code for new logic, after for glue
- `tests-later` — ship first, test when it matters
- `none` — exploratory, no test discipline

Affects: tester subagent behavior in feature-crew, testing reminders in CLAUDE.md posture.

---

## Interview end state

After Q4 (always), Q5–Q7 (if kind warrants), Q-pub1 (if public), Q8 (if not skipped), you have enough to:

1. Compute tier via `references/tiers.md`.
2. Write `project-config.json.intent`.
3. Print the plan.
4. Ask for confirmation.
5. Install.

## Fallbacks

- If user refuses to answer any Tier 1 question → abort kickoff with a clear message. You can't right-size without them.
- If user answers Q5 with everything selected but says "but don't worry about security" — respect but log a warning in config: `"user_overrode_safety_at_kickoff": true`. Audit mode will flag this later.
- If stack auto-detection conflicts with a user answer (e.g., they say "CLI" but there's a `Dockerfile` + `package.json` + API routes), ask one clarifying question before proceeding.
