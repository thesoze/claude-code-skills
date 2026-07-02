# Review: {{feature_title}}

**Slug:** `{{slug}}`
**Reviewer:** feature-crew-reviewer (fresh context, no build history)
**Inputs:** `spec.md`, `design.md`, diff, this checklist
**Date:** {{date}}

> Your job is to find problems, not to praise.
> Do NOT summarize what the code does.
> Cite `file:line` for every finding.
> If you find nothing, list what you checked.

## Findings

Format:
```
### [SEVERITY] <title>
- **Category:** correctness | security | maintainability | observability | tests
- **Location:** `path/to/file.ext:42`
- **Issue:** <what's wrong, concretely>
- **Impact:** <what breaks, under what conditions>
- **Fix:** <specific remediation>
```

### CRITICAL
<!-- Ship-blocking. Must be fixed before Gate 4 passes. -->

<!-- none — or list findings -->

### WARN
<!-- Should be fixed. Dismissal requires a one-line justification in `## Dismissed`. -->

<!-- none — or list findings -->

### SUGGEST
<!-- Advisory. Improves the change but not required. -->

<!-- none — or list findings -->

## Checks performed

If no findings above, explicitly list what was checked here. A finding-free review with no check-list is itself a red flag.

### AC coverage (highest priority)
For each acceptance criterion in `spec.md`, locate the implementing lines.
If any AC has no corresponding code, flag CRITICAL.

- [ ] AC-1: implemented at `<file>:<line>` ✓ / MISSING
- [ ] AC-2: ...
- [ ] AC-N: ...

### Correctness
- [ ] Logic matches design flow and error-case table
- [ ] No off-by-one / boundary bugs
- [ ] Concurrency safety (if applicable): locking, atomics, idempotency keys
- [ ] Migration up/down scripts balanced (if schema change)
- [ ] Error handling: no swallowed exceptions, no bare `except:`, no empty catch blocks

### Security
- [ ] No secrets in diff (grep for API keys, tokens, passwords, private keys)
- [ ] New endpoints have authn + authz
- [ ] Inputs validated at trust boundary
- [ ] No unparameterized queries / string-interpolated SQL
- [ ] Output encoded for context (HTML, shell, log)
- [ ] No PII in logs
- [ ] Cryptographic primitives correct (timing-safe compare, random source, IV handling)
- [ ] Signed / HMAC-validated at ingress for webhooks/callbacks

### Maintainability
- [ ] Uses existing utilities / helpers rather than reinventing
- [ ] Matches local code style and naming
- [ ] Minimal diff: no drive-by refactors, no unrelated rename
- [ ] No dead code, no commented-out blocks
- [ ] Comments explain WHY only where non-obvious
- [ ] Function sizes reasonable; nesting depth reasonable

### Observability
- [ ] Structured logs at key decision points (success + error)
- [ ] Metrics emitted per design §9
- [ ] No PII fields in emitted logs/metrics
- [ ] Log levels appropriate (DEBUG vs INFO vs WARN vs ERROR)

### Tests
- [ ] Each AC has at least one test that would fail if the behavior regresses
- [ ] Tests written against spec contract, not implementation internals
- [ ] Edge cases (empty / invalid / boundary / concurrent / dependency-failure) exercised by the test suite for each AC
- [ ] No flaky patterns (sleeping, real network, unpinned time)
- [ ] `{{stack.test_cmd}}` passes clean

### Rollback
- [ ] Rollback plan from design §11 is actually executable against this diff
- [ ] No non-reversible data transformations without a dual-write / shadow window

## Dismissed

If any `WARN` finding is dismissed, add a one-liner here:

- **WARN:** <title> — dismissed because <reason>. Author: <@name>. Date: <>.

## Reviewer confidence

How thorough was this review? (self-assessment)
- [ ] High — inspected every changed file, ran `{{stack.test_cmd}}` mentally against AC list, checked rollback plan
- [ ] Medium — covered diff but didn't trace all call sites
- [ ] Low — diff too large or unfamiliar; flag in `## Dismissed` with "review confidence low, recommend human second-pass"
