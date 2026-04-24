# Feature Crew — Gotchas

Failure-mode encyclopedia. Read at session start of every non-trivial feature. Update **ruthlessly** after every real feature run.

## Orchestration

### Subagents cannot spawn subagents
All delegation happens from the top-level orchestrator. If a role playbook says "then have the tester verify", the role finishes its artifact and returns to orchestrator, which then spawns the tester. Flatten any nested delegation in your plan.

### Context is per-agent, files are the bridge
Chat history does NOT cross between a subagent and the orchestrator (except the final message). If architect produced an insight, it must be in `design.md` or it effectively never happened. Before every subagent spawn: confirm inputs exist on disk, confirm output path is specified.

### Parallel subagents need worktree isolation
If you spawn two engineer subagents simultaneously for L/XL features, each MUST use `isolation: worktree` or they'll clobber each other's edits. For `specs/<slug>/*.md` artifacts, parallel writers ALSO need worktree isolation or fence their file paths (one writes to `spec.md`, other to `design.md`).

### Fresh-context reviewer is non-negotiable
A reviewer that watched the build rubber-stamps the build. Spawn reviewer in a fresh Agent call with zero conversation history. Same for security. If you find yourself "just asking the architect to also review its own design", stop — that's sycophancy-by-design.

### Artifacts are append-only except state.json and plan.md
Once written, `spec.md`, `design.md`, `review.md`, etc. are historical. If Gate 4 produces a new build, append `## Iteration 2` headers rather than overwriting. This preserves the audit trail. `state.json` and `plan.md` are the only live-mutable artifacts.

## Triage

### Over-triage > under-triage
If you're between two sizes, pick the larger. The cost of running "too much crew" on an M feature is maybe 20% more tokens. The cost of treating an L feature as M is re-doing the work from scratch when the reviewer catches architectural issues that the missing architect would have prevented.

### Risk overrides size
XS + touches auth = invoke security. Always. Never skip security because "it's a small change" — small changes to auth are exactly where the bad bugs live.

### Triage output is advisory; orchestrator owns the call
If triage says "M, low risk" but the change touches payments code, override to high risk and log the override in `state.json.skipped` with reason. Triage is one signal, not gospel.

## Spec / PM

### EARS requirements feel stiff; write them anyway
"When X, the system shall Y" is ugly prose but testable. Plain English requirements drift into implementation detail or get two readings. Stiff wording, clear tests.

### Out-of-scope is as important as in-scope
Every spec must have an "Out of scope" section. Otherwise scope creeps during Build. If the engineer asks "should I also update the logout flow?", the answer is in Out of scope: "Logout flow is not in scope — track separately."

### Open questions must be marked [BLOCKING] or [NON-BLOCKING]
`[BLOCKING]` gates Gate 1. `[NON-BLOCKING]` can proceed with an assumption logged. Never leave an unmarked open question — it'll bite you at review.

## Design / Architect

### ADRs are for decisions, not descriptions
An ADR documents a choice made between alternatives with tradeoffs. "Use Postgres" is not an ADR unless you considered MongoDB, DynamoDB, and SQLite and rejected them with reasons. If there's no "Alternatives Considered" section, it's not an ADR — it's a design note, put it in `design.md`.

### Rollback plan is not optional
Every design must specify: how do we undo this if it ships and breaks? For data migrations, this is the down script. For API changes, this is the backward-compat layer. For feature flags, this is the off switch. No rollback plan = Gate 2 fails.

## Plan

### The plan critique step pays for itself
Spend the 30s to have the engineer subagent roast the plan before implementing. You're looking for: missing prerequisites, steps in wrong order, steps that assume something not yet built, steps too vague to execute. Budget a 1-message revise cycle before Build.

### Plan steps must be atomic
"Implement webhook handler" is not a plan step; it's a phase. Break it: "1. Add route registration. 2. Write signature validator. 3. Write body parser. 4. Write event dispatcher. 5. Write error path. 6. Wire into existing event bus." Each is one diff, one commit-sized chunk.

## Build

### Minimal diff, no drive-by refactors
Builders implement the plan. They do NOT: rename unrelated variables, "fix" adjacent code they find ugly, update dependencies, modify files not in the plan. If the builder spots something that should be fixed, they append to `plan.md` under `## Follow-ups` and continue. Separate concern, separate PR.

### Don't let the builder write tests
The builder knows the implementation. They will write tests that exercise their code path rather than tests against the spec. Tests are the tester subagent's job, written from `spec.md` ONLY — no access to the diff.

### Iteration count is real; escalate at cap
If Build→Test→Review loops hit the iteration cap (3/5/8/10 for S/M/L/XL), stop. Print a structured summary: attempts, failures, suspected blocker, what you'd need. Don't keep grinding — the problem is probably upstream in the spec or design.

## Test / QA

### The tester must NOT see the implementation
Spawn tester with `spec.md` and `test-plan.md` template, and with Read access locked to `specs/<slug>/` only. Tests written while looking at implementation = tests that pass because they mirror implementation, not because the code is correct. This is the #1 failure mode of AI-written tests.

### Every acceptance criterion gets at least one test
Literally. Open `spec.md`, enumerate ACs, check `test-plan.md` has a row for each. If AC-3 has no test, that's a Gate 4 CRITICAL. No exceptions.

### Edge cases per AC
For each AC, the tester writes at minimum: happy path, empty input, invalid input, concurrent/race, failure-of-dependency. If `test-plan.md` is a flat list without this structure per AC, bounce back.

## Security

### Spawn fresh, provide spec + design + diff only
Security reviewer gets `spec.md`, `design.md`, and the diff. No chat history. No plan.md. No test-plan. They're looking for vulnerabilities, not for whether the tests cover the happy path.

### OWASP 2025 checklist is the floor, not the ceiling
The OWASP categories (injection, broken access, crypto, etc.) are the minimum scan surface. Domain-specific risks (webhook signature reuse, replay attacks, SSRF via fetch tools, timing oracles, privilege escalation via role mutation) are on top. Security playbook has the full list.

### Secrets in diff = hard-halt
If security finds any secret, key, token, or credential in the diff, it's a Gate 4 CRITICAL and orchestrator halts immediately. Do not proceed with ship even if user wants to. Rotate first, then reland.

## Review

### Reviewer has no memory
Fresh Agent call. New context. Reviewer gets `spec.md`, `design.md`, the diff, and the `review-checklist.md` template. That's it. If you catch yourself "passing the conversation so far" to the reviewer, stop.

### Reviewer must not summarize the code
Its job is to find problems. A review that opens with "This PR adds a webhook handler that validates HMAC signatures and dispatches events..." has already wasted tokens. The playbook forbids this explicitly.

### Finding-free review with no check-list = red flag
If reviewer says "Looks good, nothing to flag", the orchestrator MUST verify the review listed what was checked. "I checked: X, Y, Z, and found no issues" is acceptable. "LGTM" alone is not.

### Cite file:line for every finding
"There's a race condition" with no file:line is useless. Playbook requires citations. If a finding lacks citation, reviewer has to resubmit.

### AC coverage check
For each AC in `spec.md`, reviewer locates implementing lines. If any AC has no corresponding code, flag CRITICAL "AC-N appears to be missing implementation at [expected location]". This is the single highest-value review check.

## Gates

### Auto-approve does not mean silent
Even when Gate 1 auto-approves, print: "Gate 1 auto-approved (size=S, risk=low, 0 blocking questions)". User needs to be able to audit trail.

### Skipping a gate is an operator action
If user says "skip Gate 3", respond with the skip text: "Confirm you want to skip Gate 3 — Build will proceed without lint/typecheck/test verification. This will be logged in state.json and review.md as an operator override."

### Iteration reset on phase rollback
Rolling back from Review → Build does NOT reset iteration count. Rolling back from Build → Plan does. Reason: changing the plan starts a new attempt; re-building on an existing plan is the same attempt being refined.

## Stack detection

### detect_stack.sh is deterministic — treat unknowns as "ask user"
If the script emits `unknown` for lint_cmd, never guess. Ask user: "Could not detect lint command for this repo. What do you use?" Cache their answer in `state.json.stack` so future phases use it.

### Multi-stack repos
If repo has both package.json and pyproject.toml (common: Python backend + JS frontend), detect_stack.sh should emit `languages: ["python", "typescript"]` and the orchestrator must pick per-surface. Frontend build phase uses `pnpm build`; backend test phase uses `pytest`.

### Monorepo awareness
If you detect a monorepo (pnpm-workspace.yaml, nx.json, turbo.json), `{{stack.test_cmd}}` might be `pnpm -F <pkg> test` rather than `pnpm test`. Prefer scoped commands to avoid running the entire monorepo CI on a 3-file change.

## State / Resume

### state.json corruption
If `state.json` is malformed or phase is in an impossible state (e.g., `gate_2.status=approved` but no `design.md` exists), halt and ask user. Do not try to "recover" by guessing.

### Long-running feature across sessions
After ~24h, stack detection and gotchas have possibly changed (new deps, new linters). Re-run `detect_stack.sh` on resume and diff against cached `stack` in `state.json`. If different, ask user if they want to re-plan.

## Docs / Changelog

### Changelog entry is a spec snapshot
Write `## [version]`, user-visible change in one sentence, link to spec slug. Don't paraphrase what the code does — paraphrase the user-visible behavior change. If no user-visible change, skip docs and note in `state.json.skipped`.

### User-visible ≠ API-changing
A new database index is not user-visible. A changed error message IS user-visible. A new config key IS user-visible. Err on the side of documenting.

## Ship

### Commit message from spec, not from diff
Commit message subject = one-sentence spec summary. Body = "Why" from spec rationale, "What" from design summary, "Tests" from test-plan summary, "Review" link to `review.md`. Never generate commit message from diff — it'll be a restatement of the code.

### PR body pulls from artifacts
`references/templates/pr-body.md` has the format. Summary from `spec.md`, approach from `design.md`, test plan from `test-plan.md`, security section from `security-review.md` (if exists), review summary from `review.md`. Assemble by transclusion, not paraphrase.

---

## Add new gotchas here

After every real feature run, if something surprised you, add it. This file is the project's institutional memory. Untracked gotchas repeat.
