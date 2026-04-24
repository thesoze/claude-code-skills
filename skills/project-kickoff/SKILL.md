---
name: project-kickoff
description: Use this skill whenever the user starts a new project, inherits an untracked project, or wants to audit an existing project's "contract" with Claude Code. It has two modes — Kickoff (first run, no `.claude/project-config.json` present) interviews the user on project shape and threat model, then installs right-sized CLAUDE.md + hooks + permissions + feature-crew scaffolding. Audit (rerun, config present) probes current state, diffs against recorded intent, and reports drift by severity. Invoke proactively when entering a fresh directory, when the user says "set up", "kickoff", "harden", "audit", "health check", or when a scheduled audit fires. The whole point: lock in a project's intended shape once, then catch drift before it becomes an incident.
---

# Project Kickoff — Setup + Audit Orchestrator

Two modes, one skill. **Kickoff** sets up a project's Claude Code contract once. **Audit** checks reality against that contract on every subsequent run.

You are an **orchestrator**. Interview, detect, install, diff, report. Delegate heavy work to sub-playbooks in `references/`.

## Mode detection (first thing, every run)

```
if exists(".claude/project-config.json"):
    → Audit mode (see references/audit.md)
else:
    → Kickoff mode (see references/interview.md)
```

Announce the mode to the user in one line before any other action:
> *"Kickoff mode — no prior config found. I'll interview, then install."*
> *"Audit mode — config from 2026-03-15 found. Probing drift."*

## Kickoff mode

### Step 1 — Probe

Run `bash scripts/audit_probe.sh --mode=kickoff` from the repo root. Reads: language, package manager, git remote, existing `.claude/`, existing CLAUDE.md. Emits JSON to stdout — cache it, you'll merge it into `project-config.json`.

If the probe finds an existing `CLAUDE.md` without kickoff markers, ask: *"I see an existing CLAUDE.md without kickoff markers. Append a managed section below, or replace? (append recommended)"* Default: append.

### Step 2 — Interview

Load `references/interview.md`. It has the full question flow. Use **`AskUserQuestion`** for every structured choice — do not free-form these. Project name + one-line description are the only text answers (ask with regular output).

**Question count:** 4 required (Tier 1) + up to 4 conditional (Tier 2) + 1 optional (Tier 3). Target 6–8 total. Do not exceed 10.

Record every answer in `project-config.json.intent` as you go. If user says "skip" or "defaults" to any conditional block, record `skipped: true` and move on — don't loop.

### Step 3 — Map answers to tier + installs

Load `references/tiers.md`. It maps `{threat_model, visibility, kind}` → tier `{minimal, standard, paranoid}` and lists what each tier installs. Print the plan:

> *"Based on your answers: tier = **standard**. I will install:
> - CLAUDE.md managed section (posture, absolute rules, commit style)
> - `.claude/hooks/posttool-injection-scan.py`
> - `.claude/hooks/pretool-secret-scan.py`
> - `.claude/settings.json` (permissions + hook registration)
> - `.claude/project-config.json` (records your answers)
> - `specs/` dir (feature-crew scaffolding)
> Proceed? (y/edit/abort)"*

User confirms or edits. Never install silently.

### Step 4 — Install (idempotent, markered)

All file writes follow **idempotency rules**:

- **CLAUDE.md sections** — bracketed with `<!-- project-kickoff:begin SECTION_NAME -->` and `<!-- project-kickoff:end SECTION_NAME -->`. On any future write, replace the content **between** the markers — never append duplicates.
- **Hook files** — predictable filenames under `.claude/hooks/`. Overwrite if content hash changed; record hash in config for audit-mode drift detection.
- **`.claude/settings.json`** — merge permissions/hooks entries by key. Don't clobber user-added entries; if conflict, ask.
- **`project-config.json`** — single source of truth. All other files are derivable from this.

Templates live in `references/templates/`:

| File | Purpose |
|---|---|
| `claude-md-sections.md` | Snippets with markered bounds — pick by tier |
| `project-config.schema.json` | JSON schema; validate before writing |
| `hook-posttool-injection.py` | PostToolUse hook — scans WebFetch/Bash/curl results for injection markers |
| `hook-pretool-secret-scan.py` | PreToolUse hook — blocks Write/Edit of files containing common secret patterns |
| `audit-report.md` | Format for audit-mode output |

### Step 5 — Finalize

1. Validate `project-config.json` against the schema.
2. Print the summary: what was installed, file paths, tier.
3. Offer the scheduling payoff:
   > *"Kickoff done. Want me to `/schedule` a monthly audit? It scans drift, writes a report to `.claude/audit-reports/`, and only alerts on BREACH-severity findings. Low noise, high catch."*
4. If user accepts, invoke `/schedule` with a cron expression like `0 9 1 * *` (9am first of month) and action `"invoke /project-kickoff in <project-path>"`.
5. Offer the first-feature kickstart:
   > *"Want to scaffold your first feature via `/feature-crew`? Or drop in later."*

## Audit mode

### Step 1 — Load intent

Read `.claude/project-config.json`. This is the **contract**. Everything else is reality.

### Step 2 — Probe reality

Run `bash scripts/audit_probe.sh --mode=audit`. Emits current state as JSON.

### Step 3 — Diff across dimensions

Load `references/drift-dimensions.md`. v1 covers **three dimensions** deterministically:

1. **Hook integrity** — each hook recorded in `config.installed.hooks` must exist and hash-match. If missing → `BREACH`. If hash changed → `DRIFT` (someone edited it; may be intentional).
2. **Threat model coverage** — if intent says "no external content" but the probe finds `WebFetch` or `curl` in recent transcripts or the hooks log, → `DRIFT` (suggest upgrading tier).
3. **Secret exposure** — run `gitleaks detect --no-git --redact -v` if installed; fall back to a simple regex probe. Any finding → `BREACH`.

Also catch **intent-change** signals (not full drift, but trigger re-interview):
- Stack changed (new primary language in probe vs config)
- Kind changed (e.g., `library` → `service`)

### Step 4 — Report

Write a dated report to `.claude/audit-reports/YYYY-MM-DD-HHMM.md` using `references/templates/audit-report.md`.

Report structure:
- **Verdict** (PASS / DRIFT / BREACH / INTENT-CHANGE) — top of file, one line
- **Summary** — what was checked, counts per severity
- **BREACH** findings (if any) — details + suggested fix
- **DRIFT** findings (if any) — details + offer to ratify (update config) or fix
- **OK** — explicit list of dimensions that passed (so a clean audit shows what was actually checked — no "finding-free with no checklist")

Append to `config.drift_history[]`: `{at, verdict, breach_count, drift_count, intent_change_count, report_path}`.

### Step 5 — Alert and offer fixes

- **BREACH only:** alert via `PushNotification` (desktop) with the verdict + report path. No spam on clean audits.
- **DRIFT / INTENT-CHANGE:** print the report inline and offer fixes interactively:
  - *"Upgrade injection tier from minimal → standard? (WebFetch detected)"*
  - *"Re-run interview for Q5–Q7 (threat model)? Stack changed from Python → Python+Node"*
  - *"Absorb your CLAUDE.md edits into config, or revert to managed version?"*

If running non-interactively (from `/schedule`), skip the inline offers — the report records the recommendation; user reviews on next manual invocation.

## File layout

Everything the skill owns:

```
CLAUDE.md                                # markered sections under <!-- project-kickoff:* -->
.claude/
├── settings.json                        # merged: permissions + hook registration
├── hooks/
│   ├── posttool-injection-scan.py       # tier ≥ standard
│   └── pretool-secret-scan.py           # all tiers
├── project-config.json                  # contract + drift_history[]
└── audit-reports/
    └── YYYY-MM-DD-HHMM.md               # one per audit
specs/                                   # feature-crew scaffolding (if user opts in)
.gitignore                               # baseline + .claude/settings.local.json entry
```

## project-config.json schema (summary)

Full schema in `references/templates/project-config.schema.json`. Top-level:

```json
{
  "schema_version": 1,
  "kickoff_at": "2026-04-24T15:00:00Z",
  "last_audit_at": "2026-04-24T15:00:00Z",
  "tier": "standard",
  "intent": {
    "name": "...",
    "description": "...",
    "kind": "agent",
    "visibility": "public",
    "stage": "greenfield",
    "threat_model": { "sources": [...], "trust": "...", "actions": [...], "cost": "..." },
    "conventions": { "testing": "pragmatic", "commit_style": "conventional" }
  },
  "installed": {
    "claude_md_sections": ["posture", "absolute-rules", "commit-style"],
    "hooks": [ { "path": "...", "sha256": "..." } ],
    "settings_keys": ["permissions.allow", "hooks.PostToolUse"]
  },
  "drift_history": [
    { "at": "...", "verdict": "PASS", "breach_count": 0, "drift_count": 0, "intent_change_count": 0, "report_path": "..." }
  ]
}
```

## Anti-patterns (never do this)

- **Free-form interview questions** when `AskUserQuestion` fits. Structured > text.
- **Silent installs.** Always print the plan, ask, then install.
- **Duplicating CLAUDE.md content.** Markers are the law; overwrite between, never append.
- **Chatty audits.** A clean audit is a one-line PASS verdict + explicit checklist. Not a celebration.
- **Alerting on DRIFT.** Only BREACH pages the user. DRIFT waits for next manual invocation.
- **Re-interviewing on audit.** Audit mode never asks Tier 1 questions unless stack/kind changed — the contract is fixed.

## Operator overrides

- *"Skip the interview, I'll write the config manually"* — accept a pre-written `project-config.json`, validate, then proceed to Step 4 (install).
- *"Audit without writing"* — run Steps 1–3, print report to stdout, do not touch `audit-reports/` or `drift_history[]`. Useful for dry-runs.
- *"Reset the project"* — delete all managed files, preserve user edits to CLAUDE.md by moving them to `CLAUDE.md.before-reset.md`, then re-run Kickoff from scratch.

## Integration with other skills

- **`feature-crew`** — kickoff creates `specs/` dir; points user at `/feature-crew` for features.
- **`/security-review`** — offered as a post-kickoff action for existing projects (`stage: existing`).
- **`/pentest`** — offered for `kind: service` or `kind: agent`.
- **`/schedule`** — optional monthly audit scheduling at end of kickoff.
- **`fewer-permission-prompts`** — called by kickoff when tier=standard or above to scope `.claude/settings.json` permissions intelligently.

## References (load on demand)

- `references/interview.md` — full question flow + branching logic
- `references/tiers.md` — answer → tier → install mapping
- `references/audit.md` — audit procedure detail
- `references/drift-dimensions.md` — what each dimension checks, how
- `references/templates/*` — artifact scaffolds

## Start-of-run checklist

1. Detect mode (config file present?).
2. Run `scripts/audit_probe.sh` (mode-specific).
3. Announce mode to user.
4. Load the right reference playbook.
5. Execute. Write idempotently. Report clearly.
