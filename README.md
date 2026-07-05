# claude-code-skills

Skills, subagents, and slash commands for [Claude Code](https://claude.com/claude-code).

| Bundle | What it does |
|---|---|
| [`skills/project-kickoff`](skills/project-kickoff) | **Setup + audit orchestrator.** Interviews you once when starting a project, installs right-sized CLAUDE.md + hooks + permissions. On rerun, audits the project against its own recorded intent and flags drift. |
| [`skills/feature-crew`](skills/feature-crew) | **Multi-agent SDLC orchestrator.** Triage → spec → design → build → test → review → ship, with human-in-the-loop gates and fresh-context reviewers. |
| [`skills/siege-research`](skills/siege-research) | **Adversarial multi-wave decision research.** Parallel research agents generate theses, adversarial agents stress-test each to a KILL or SURVIVE verdict, killed ideas pivot and re-enter the gauntlet. Only findings that survive ≥2 adversarial rounds reach the final report. |
| [`agents/feature-crew-*`](agents) | 12 subagent definitions paired with feature-crew — PM, architect, backend/frontend/mobile engineers, tester, reviewer, security, devops, docs, UX, triage. |
| [`commands/`](commands) | `/security-review` (SAST, stack-agnostic static analysis) and `/pentest` (DAST, stack-agnostic runtime pentest). Methodology-first, tool-second. |

Everything is stack-agnostic — Python, TypeScript, Go, Rust, Ruby, Java, Swift. Stack detection probes pick the right commands per repo.

## Install

This repo is a **Claude Code plugin** — skills, the 12 subagents, and the slash commands install together as one versioned unit.

```
/plugin marketplace add thesoze/claude-code-skills
/plugin install claude-code-skills@thesoze-claude-code-skills
```

That's it. Skills become namespaced — `/claude-code-skills:feature-crew`, `/claude-code-skills:project-kickoff`, `/claude-code-skills:siege-research` — and the `/security-review` + `/pentest` commands and all `feature-crew-*` subagents come with them. Update later with `/plugin update claude-code-skills`.

Bundled files reference themselves via `${CLAUDE_PLUGIN_ROOT}`, which Claude Code substitutes at runtime — so the orchestrator and its subagents always resolve to the same installed copy and can't drift apart.

### Manual / development install (optional)

To hack on the skills locally without the marketplace, point Claude Code at the checkout:

```bash
git clone https://github.com/thesoze/claude-code-skills.git
claude --plugin-dir ./claude-code-skills
```

Restart Claude Code (or run `/reload`) after installing.

## Usage

### `/project-kickoff` — setup + audit

```
/project-kickoff
```

Two modes, one skill. First run is **kickoff**: a 6–8 question interview (structured choices, not free-form) covering project kind, visibility, threat model, and conventions. Based on answers it picks a tier (`minimal / standard / paranoid`) and installs:

- CLAUDE.md managed sections (posture, absolute rules, external-content handling, commit style, git identity)
- `.claude/hooks/posttool-injection-scan.py` — PostToolUse hook that scans WebFetch/Bash output for prompt-injection markers (instruction override, role assumption, ChatML smuggling, invisible chars, exfil patterns) and, on a hit, feeds a `[SECURITY NOTE]` back to the model via `hookSpecificOutput.additionalContext`
- `.claude/hooks/pretool-secret-scan.py` — PreToolUse hook that blocks Write/Edit of files containing AWS/GitHub/Anthropic/OpenAI tokens, private keys, credential URLs — with allowlist for test fixtures
- `.claude/settings.json` permissions, scoped to project kind
- `.claude/project-config.json` — records every interview answer as the project's **contract**
- `specs/` dir for feature-crew

Subsequent runs are **audit mode**: reads the contract, probes current state, diffs across dimensions (hook integrity, threat-model coverage, secret exposure, stack/kind intent-change), writes a dated report to `.claude/audit-reports/`, and alerts on BREACH only. Offers a `/schedule` integration at the end of kickoff so audits run monthly in the background.

### `/feature-crew` skill

Invoked automatically when you ask Claude Code to build, implement, design, spec, refactor, or fix a non-trivial bug. You can also nudge it explicitly:

```
/feature-crew add CSV export to the admin dashboard
```

Triages size/risk, picks a right-sized crew, and walks the phases. Artifacts land in `specs/<YYYY-MM-DD-slug>/` — spec, design, plan, test-plan, review, ADRs, changelog. Resume support if a session is interrupted.

### `/siege-research` — adversarial decision research

```
/siege-research should we enter the EU market next quarter?
```

Not a single research pass — an iterative **generate → attack → pivot → re-attack → converge** loop for high-stakes decisions. 5–10+ parallel agents explore angles while adversarial agents actively try to kill each thesis. Every finding needs a KILL or SURVIVE verdict; pivoted ideas get their own fresh stress-test; nothing reaches the final report without surviving at least two adversarial rounds. Output: surviving plays with survival records, a kill list with receipts, and methodology stats. Set a time limit and it runs to the full limit — no premature convergence.

### `/security-review` — static analysis

Detects your stack, runs the appropriate SAST tools (ruff+bandit, semgrep, npm audit, gosec, cargo-audit, brakeman, gitleaks), then reviews the code against OWASP 2025 Top 10 plus domain-specific checks (webhook HMAC, multi-tenant isolation, file uploads, secrets management, background jobs, caching).

Severities: CRITICAL / HIGH / MEDIUM / LOW with `file:line` refs and fix suggestions.

### `/pentest` — dynamic analysis

Runs against a live app (localhost or staging). Phases cover auth, SQLi, IDOR, SSRF, JWT attacks, races, framework-specific vectors (Next.js, Supabase, Django, Rails, Express, FastAPI, Flutter/RN), business logic, LLM-specific attacks, and header/CSP audits.

False-positive prevention is built in — e.g. PostgREST 200s are verified with follow-up SELECT, not just status codes.

## How the skills compose

A recommended flow for a fresh project:

1. `git init` + `gh repo create` (or clone).
2. **`/project-kickoff`** — interview, install defenses, configure CLAUDE.md.
3. **`/feature-crew <first feature>`** — scaffold and ship feature 1 through the full SDLC.
4. Optionally accept the `/schedule` offer at the end of kickoff for monthly audits.
5. Between features, run **`/security-review`** when you touch auth, payments, PII, or external IO.
6. Before major releases, run **`/pentest`** against staging.

For an existing project being brought under Claude Code tooling for the first time:

1. **`/project-kickoff`** with `stage: existing` — it'll preserve your CLAUDE.md content and append managed sections below.
2. Accept its offer to run **`/security-review`** as the first audit.
3. Use **`/feature-crew`** for new features; let existing code keep its existing workflow.

## Design notes

Opinions baked in across all bundles:

- **Files over chat for cross-agent state.** Every subagent reads its inputs from `specs/<slug>/*.md` and writes outputs back. Nothing important lives only in chat history.
- **Fresh-context reviewers.** Reviewer and security subagents are spawned without memory of the build — they read spec, design, and diff. Catches things the builder rationalized.
- **Deterministic guards outside the model.** Hooks (permissions, PostToolUse scanners, PreToolUse secret blockers) survive an adversarial model. Prompting discipline is the flexible layer on top, not the foundation.
- **Right-sized ceremony.** feature-crew's triage scales crew to work size. project-kickoff scales installs to threat tier. XS bugs and solo scripts don't pay big-project taxes.
- **Anti-sycophancy.** Reviewers are prompted with "find problems, not praise" and "a finding-free review with no checklist is itself a red flag." Audit reports always list what was explicitly checked, not just what was flagged.
- **Intent-first, drift-aware.** project-kickoff records *why* you set things up the way you did. Audit mode catches reality drifting from intent — including subtle signals like stack shifts or kind changes — before they're incident-grade.
- **Stack-agnostic.** `scripts/detect_stack.sh` and `scripts/audit_probe.sh` emit JSON profiles; role playbooks reference `{{stack.lint_cmd}}`, `{{stack.test_cmd}}`, etc. Same crew, same kickoff, works in Django, Rust, Flutter, Next.js.

## Prompt-injection defense

Every skill that ingests external content is layered:

1. **Permissions** (`.claude/settings.json`) — sharpest. Deny dangerous tool categories by default.
2. **Hooks** (`.claude/hooks/*.py`) — deterministic. PostToolUse injection scanner runs on every WebFetch/Bash/curl.
3. **CLAUDE.md posture** — frames external content as data, not instructions. Boundary-marker pattern: `[UNTRUSTED <source> BEGIN]…[END]`.
4. **Skill procedures** (weakest, still useful) — design-time playbooks that reference the above.

See `skills/project-kickoff/references/tiers.md` for which layers install at which tier and `skills/project-kickoff/references/templates/hook-posttool-injection.py` for the pattern set (based on OWASP LLM Top 10).

## License

[MIT](LICENSE). Use them, fork them, adapt them.
