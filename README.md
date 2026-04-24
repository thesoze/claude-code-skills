# claude-code-skills

Skills, subagents, and slash commands for [Claude Code](https://claude.com/claude-code).

Three bundles:

| Bundle | What it does |
|---|---|
| [`skills/feature-crew`](skills/feature-crew) | Multi-agent SDLC orchestrator. Triage → spec → design → build → test → review → ship, with human-in-the-loop gates and fresh-context reviewers. |
| [`agents/feature-crew-*`](agents) | 12 subagent definitions paired with the skill — PM, architect, backend/frontend/mobile engineers, tester, reviewer, security, devops, docs, UX, triage. |
| [`commands/`](commands) | `/security-review` (SAST, stack-agnostic static analysis) and `/pentest` (DAST, stack-agnostic runtime pentest). Both methodology-first, tool-second. |

Everything here is stack-agnostic — Python, TypeScript, Go, Rust, Ruby, Java, Swift. A `scripts/detect_stack.sh` probe picks the right commands per repo.

## Install

Clone once, then symlink (or copy) each bundle to Claude Code's well-known locations.

```bash
git clone https://github.com/thesoze/claude-code-skills.git
cd claude-code-skills

# Skill (installs to ~/.claude/skills/feature-crew/)
mkdir -p ~/.claude/skills
ln -sf "$PWD/skills/feature-crew" ~/.claude/skills/feature-crew

# Subagents (installs to ~/.claude/agents/)
mkdir -p ~/.claude/agents
for f in agents/*.md; do ln -sf "$PWD/$f" ~/.claude/agents/; done

# Slash commands (installs to ~/.claude/commands/)
mkdir -p ~/.claude/commands
for f in commands/*.md; do ln -sf "$PWD/$f" ~/.claude/commands/; done
```

Project-scoped install: drop the same folders under `.claude/` at the repo root instead of `~/.claude/`. Project-level skills/commands take precedence over global.

Restart Claude Code (or run `/reload`) after installing.

## Usage

### `feature-crew` skill

Invoked automatically when you ask Claude Code to build, implement, design, spec, refactor, or fix a non-trivial bug. You can also nudge it explicitly:

```
/feature-crew add CSV export to the admin dashboard
```

It will triage size/risk, pick a right-sized crew, and walk the phases. Artifacts land in `specs/<YYYY-MM-DD-slug>/` — spec, design, plan, test-plan, review, ADRs, changelog. Resume support if a session is interrupted: re-entry reads `state.json` and asks where to pick up.

### `/security-review` — static analysis

```
/security-review
```

Detects your stack, runs the appropriate SAST tools (ruff+bandit, semgrep, npm audit, gosec, cargo-audit, brakeman, gitleaks, etc.), then reviews the code against OWASP 2025 Top 10 plus domain-specific checks (webhook HMAC, multi-tenant isolation, file uploads, secrets management, background jobs, caching).

Severities: CRITICAL / HIGH / MEDIUM / LOW with `file:line` refs and fix suggestions.

### `/pentest` — dynamic analysis

```
/pentest
```

Runs against a live app (localhost or staging). Phases cover auth, SQLi, IDOR, SSRF, JWT attacks, races, framework-specific vectors (Next.js, Supabase, Django, Rails, Express, FastAPI, Flutter/RN), business logic, LLM-specific attacks, and header/CSP audits.

False-positive prevention is built in — e.g. PostgREST 200s are verified with follow-up SELECT, not just status codes.

## Design notes

A few opinions baked in across all three bundles:

- **Files over chat for cross-agent state.** Every subagent reads its inputs from `specs/<slug>/*.md` and writes outputs back. Nothing important lives only in chat history.
- **Fresh-context reviewers.** The reviewer and security subagents are spawned without any memory of the build — they read the spec, design, and diff, and nothing else. Cheap way to catch things the builder rationalized.
- **Gates are real.** No "skip this one." Skips are logged in `state.json` with operator justification.
- **Right-sized crew.** Triage picks the crew by size/risk/surface. XS bugs get engineer+reviewer. XL features get the full cast. No cargo-cult ceremony on small work.
- **Anti-sycophancy on reviewers.** Explicit prompts like "your job is to find problems, not to praise" and "a finding-free review with no checklist is itself a red flag."
- **Stack-agnostic.** `scripts/detect_stack.sh` emits a JSON profile; role playbooks reference `{{stack.lint_cmd}}`, `{{stack.test_cmd}}`, etc. The same crew works in a Django monorepo, a Rust CLI, or a Flutter app.

See [`skills/feature-crew/SKILL.md`](skills/feature-crew/SKILL.md) for the full orchestrator spec and [`skills/feature-crew/references/gotchas.md`](skills/feature-crew/references/gotchas.md) for the failure-mode encyclopedia.

## License

[MIT](LICENSE). Use them, fork them, adapt them.
