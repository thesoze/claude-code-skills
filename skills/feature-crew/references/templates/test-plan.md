# Test Plan: {{feature_title}}

**Slug:** `{{slug}}`
**Author:** feature-crew-tester
**Sourced from:** `spec.md` (ACs) — tester has NOT seen implementation
**Date:** {{date}}

> **Critical rule:** Tests are written from the spec, not from the code. If a test's existence or shape depends on implementation details visible only in the diff, it belongs in `## Implementation-aware tests (justify each)` with explicit reasoning — otherwise reject and rewrite from the AC.

## 1. Coverage Matrix

One row per acceptance criterion. Every AC MUST appear. Missing AC = CRITICAL finding at review.

| AC | Covered by tests | Edge cases covered | Notes |
|---|---|---|---|
| AC-1 | `test_ac1_happy`, `test_ac1_empty_input`, `test_ac1_invalid_input`, `test_ac1_concurrent` | empty, malformed, race, dep-fail | — |
| AC-2 | ... | ... | — |
| AC-N | ... | ... | — |

## 2. Per-AC Edge Case Checklist

For each AC, at minimum:
- [ ] Happy path
- [ ] Empty / null / zero input
- [ ] Invalid / malformed input
- [ ] Boundary values (min, max, off-by-one)
- [ ] Concurrent / race condition (if stateful)
- [ ] Failure of upstream dependency (if external call)
- [ ] Idempotency (if mutating)
- [ ] Permission denied / unauthorized (if gated)

## 3. Non-Functional Test Plan

### Performance
- **Load test:** <tool, duration, concurrency, target SLO>
- **Regression threshold:** <p95 latency must stay under X>

### Security (handed to feature-crew-security)
- **Injection surface checks:** <>
- **Authn/authz test matrix:** <>

### Accessibility (UI only)
- **Keyboard navigation:** all interactive elements reachable
- **Screen reader:** labels, roles, live regions
- **Color contrast:** WCAG AA

## 4. Test Infrastructure

- **Unit test command:** `{{stack.test_cmd}}`
- **Integration test command:** <>
- **E2E test command:** <>
- **Fixtures:** <paths, factories>
- **Mock boundaries:** <what's mocked, what's not — integration tests should hit real deps where feasible>

## 5. Test Data Strategy

- **Generation:** <factory library, deterministic seeds>
- **Isolation:** <per-test teardown, transaction rollback, separate schema>
- **PII-safe:** <no real user data in fixtures>

## 6. Flakiness Guards

- **Retry policy:** <none by default; individual flake → fix, don't retry>
- **Time control:** <freeze clock for time-dependent tests>
- **Network control:** <record/replay or pinned mocks for external HTTP>

## 7. Expected Test File Layout

```
tests/
├── unit/
│   └── test_<slug>.py           # or .ts, .go, etc.
├── integration/
│   └── test_<slug>_integration.py
└── e2e/
    └── test_<slug>_e2e.py       # UI flows only
```

## 8. Implementation-aware Tests (justify each)

If any test must reference implementation details (e.g., an internal function boundary, a specific error class), list here with reasoning. Default: empty.

- None.

## 9. Ship Gates

Gate 3 re-run criteria (the tester writes these after the initial Build→Gate 3; all must be green before ship):
- [ ] All rows in §1 have tests written
- [ ] All edge case checklists (§2) green per AC
- [ ] Lint passes: `{{stack.lint_cmd}}`
- [ ] Typecheck passes: `{{stack.typecheck_cmd}}`
- [ ] Test suite passes: `{{stack.test_cmd}}`
- [ ] Build succeeds: `{{stack.build_cmd}}`

## 10. Known Limitations of This Plan

<!-- Honest list. "E2E coverage deferred because staging env not provisioned" is acceptable; leaving it off entirely is not. -->
