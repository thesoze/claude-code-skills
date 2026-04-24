# Audit — Rerun Mode Procedure

**Mode trigger:** `.claude/project-config.json` exists on skill invocation.

**Core principle:** the config is the **contract**; the codebase is **reality**. Audit diffs them. Audit never re-interviews Tier 1 questions — the contract is fixed until explicitly reset.

## Step 1 — Load intent

Read `.claude/project-config.json`. Validate against `references/templates/project-config.schema.json`. If invalid:
- Log: `"config schema invalid"`
- Report to user: *"project-config.json failed schema validation at `<path>`. Either fix manually or run `/project-kickoff --reset`."*
- Halt.

## Step 2 — Probe reality

```bash
bash scripts/audit_probe.sh --mode=audit
```

Emits JSON with:
- `stack`: current primary language, package manager, framework
- `hooks_present`: list of files under `.claude/hooks/` with sha256
- `claude_md_sections_present`: list of section names found between markers
- `settings_permissions`: current allow/deny lists
- `recent_tool_usage`: tools called in the last N sessions (grepped from transcripts if accessible; else empty array with a warning)
- `dep_count`: total deps
- `dep_advisories`: count of vulns from `{npm,pnpm,yarn} audit` / `pip-audit` / `cargo audit` if available
- `secret_scan_findings`: list from gitleaks or regex fallback

Cache the JSON. Pass to diff step.

## Step 3 — Diff intent vs reality

See `references/drift-dimensions.md` for the full list of dimensions v1 covers. Each dimension emits zero or more findings with:

```json
{
  "dimension": "hook-integrity",
  "severity": "BREACH | DRIFT | INTENT-CHANGE | OK",
  "title": "short human-readable",
  "detail": "multi-line explanation",
  "suggested_fix": "one-line action"
}
```

## Step 4 — Write report

Path: `.claude/audit-reports/YYYY-MM-DD-HHMM.md`.

Template: `references/templates/audit-report.md`.

Report has these sections:

- **Verdict** (top line): `PASS` / `DRIFT` / `BREACH` / `INTENT-CHANGE`. Most-severe finding wins.
- **Summary**: dimensions checked, count per severity, run metadata (timestamp, mode: interactive vs scheduled).
- **BREACH** findings (if any): prominent, top of body.
- **DRIFT** findings (if any): below BREACH.
- **INTENT-CHANGE** findings (if any): below DRIFT.
- **OK** — explicit list of dimensions that passed. **Never omit this.** A clean audit that doesn't list what was checked is useless.
- **Suggested actions**: ordered list of fixes, grouped by severity.

## Step 5 — Update config

Append to `config.drift_history[]`:

```json
{
  "at": "2026-04-24T16:30:00Z",
  "verdict": "DRIFT",
  "breach_count": 0,
  "drift_count": 2,
  "intent_change_count": 0,
  "report_path": ".claude/audit-reports/2026-04-24-1630.md"
}
```

Set `config.last_audit_at`.

## Step 6 — Alert (BREACH only)

```
if verdict == "BREACH":
    PushNotification(
        title=f"BREACH in {config.intent.name}",
        body=f"{breach_count} finding(s). See {report_path}.",
    )
```

Do **not** alert on DRIFT or INTENT-CHANGE or PASS. Noise kills the loop.

## Step 7 — Interactive fix offers (only if invoked interactively)

For each finding with a `suggested_fix`, ask user:
> *"[FINDING TITLE]  → `suggested_fix`. Apply? (y/n/skip-all)"*

Apply with the same idempotent writers used in kickoff mode. After each applied fix, re-probe that dimension and verify the finding clears.

If audit was invoked non-interactively (from `/schedule`), skip Step 7 entirely — the report records recommendations; user reviews on next manual invocation.

## Non-interactive detection

Detect non-interactive mode by one of:
- Env var `CLAUDE_SCHEDULED=1` set
- No TTY attached
- Invocation flag `--non-interactive`

When non-interactive: run Steps 1–6 only, write the report, alert on BREACH, exit.

## Re-interview trigger (INTENT-CHANGE)

If the probe finds:
- Primary language changed (e.g., config says `python`, probe says `typescript`)
- Kind shifted (e.g., added web UI to a CLI project)
- Major dep framework change (e.g., Django → FastAPI)

Flag as `INTENT-CHANGE` severity and offer:
> *"The project's shape has shifted. Re-interview for the 2–3 questions whose answers likely changed? Existing installs stay untouched until you confirm new ones."*

If user accepts, run a partial interview (only the questions whose context changed), recompute tier, diff new plan against existing installs, show what would change, install on confirm.

## Dry-run mode

Flag: `--dry-run` or user says *"audit without writing"*.

- Runs Steps 1–3
- Prints report to stdout
- Does **not** write to `audit-reports/` or `drift_history[]`
- Does **not** alert

Useful for "what's my health right now" checks without polluting history.

## What audit mode does NOT do

- Does not re-run the Tier 1 interview unless INTENT-CHANGE detected.
- Does not modify CLAUDE.md outside of markered sections, and only with user approval (unless `--auto-fix` flag).
- Does not delete user-edited content. If a CLAUDE.md markered section was manually edited, flag as DRIFT with choices: *"Absorb my edits into config"* or *"Revert to managed version"*.
- Does not retroactively upgrade tiers. A drift-triggered tier upgrade is always offered, never automatic.
