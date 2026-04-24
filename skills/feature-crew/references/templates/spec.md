# Spec: {{feature_title}}

**Slug:** `{{slug}}`
**Author:** feature-crew-pm (via feature-crew)
**Date:** {{date}}
**Status:** draft

## 1. Problem Statement

<!-- One paragraph. What is the user/system pain, and why now? Cite origin: user request quote, incident ID, stakeholder ask. -->

## 2. Goals

- <!-- bulleted, outcome-oriented, testable -->

## 3. Non-Goals (out of scope)

- <!-- list what this feature is NOT doing. critical to prevent scope creep in Build. -->

## 4. Users and Roles

- **Primary:** <!-- who triggers / benefits -->
- **Secondary:** <!-- who sees effects -->
- **Privileged:** <!-- who can override / admin -->

## 5. Requirements (EARS format)

Every requirement uses one of the 5 EARS patterns. Each is testable.

### Ubiquitous
- **REQ-U-1:** The system shall <action/property>.

### Event-Driven
- **REQ-E-1:** When <trigger>, the system shall <response>.

### State-Driven
- **REQ-S-1:** While <state>, the system shall <behavior>.

### Optional-Feature
- **REQ-O-1:** Where <feature enabled>, the system shall <behavior>.

### Complex (unwanted behavior)
- **REQ-C-1:** If <unwanted condition>, then the system shall <fail-safe response>.

## 6. Acceptance Criteria

Given/When/Then. Every AC maps to at least one requirement above and will have at least one test in `test-plan.md`.

### AC-1: <short name>
- **Given** <initial state>
- **When** <action>
- **Then** <observable outcome>
- **Covers:** REQ-*-N
- **Measurable via:** <metric / assertion>

### AC-2: <short name>
...

## 7. Non-Functional Requirements

- **Performance:** <e.g., p95 latency <200ms at 100 RPS>
- **Scale:** <e.g., handles 10k concurrent users>
- **Availability:** <e.g., 99.9% over 30d>
- **Security:** <e.g., authn required, RBAC tier X, no PII in logs>
- **Accessibility:** <e.g., WCAG 2.1 AA where UI>
- **Observability:** <e.g., emits metric `feature.foo.latency`>
- **Data retention:** <e.g., 90d>
- **Compliance:** <e.g., GDPR right-to-deletion supported>

## 8. Dependencies

- **Upstream services:** <what this depends on>
- **Downstream consumers:** <what depends on this>
- **External APIs:** <third-party endpoints, SLAs>
- **Data migrations required:** <yes/no + rough shape>
- **Breaking changes to existing APIs:** <yes/no + details>

## 9. Rollout & Feature Flagging

- **Flag name (if any):** `<flag_key>`
- **Rollout plan:** <e.g., internal → 10% → 100% over 2 weeks>
- **Kill switch:** <how to disable>
- **Metrics to watch:** <leading / lagging indicators>

## 10. Open Questions

Mark each `[BLOCKING]` or `[NON-BLOCKING]`. Blocking items gate Gate 1.

- [ ] **[BLOCKING]** <question> — owner: @<name> — resolution needed by: <date>
- [ ] **[NON-BLOCKING]** <question> — assumption: <what we'll assume if unresolved>

## 11. Definition of Done

All of:
- [ ] All ACs pass their tests
- [ ] Security review passed (if required by triage)
- [ ] Docs updated (if user-visible)
- [ ] Changelog entry written
- [ ] Rollback plan verified (for high-risk changes)
- [ ] Monitoring in place (for production-impacting changes)

## 12. References

- Request source: `request.md`
- Discovery notes: `discovery.md`
- Related specs: <slugs>
- Related issues/tickets: <links>
