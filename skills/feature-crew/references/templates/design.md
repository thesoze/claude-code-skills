# Design: {{feature_title}}

**Slug:** `{{slug}}`
**Author:** feature-crew-architect
**Related spec:** `spec.md`
**Date:** {{date}}

## 1. Summary

<!-- 3-5 sentences. What's being built, at what layer, integrated how. A reader should know the shape of the work from this alone. -->

## 2. High-Level Approach

<!-- Prose or ASCII diagram of the solution. Call out which existing components are extended vs. created. -->

```
[user] → [existing X] → [new Y] → [existing Z]
```

## 3. Data Model

### New entities
- **`<table_or_type>`**: purpose, fields, relationships, indices, constraints.

### Modified entities
- **`<existing>`**: what changes, migration implications.

### Data flow
<!-- Where does data originate, how is it transformed, where does it land, what's the retention? -->

## 4. API / Interface Contract

### New endpoints / functions / events
- `{{method}} {{path}}` (or `fn_name(args)` or `event_name`)
  - **Auth:** <>
  - **Input:** <schema>
  - **Output:** <schema>
  - **Errors:** <status + body shape for each failure mode>
  - **Idempotency:** <key, dedup window>

### Modified endpoints / functions / events
- <same shape, noting what changed>

### Backward compatibility
- <what breaks; what the migration path is>

## 5. Sequence / Flow

<!-- Happy path step-by-step. Keep concrete: who calls what, with what, and what's returned. -->

1. Client calls `POST /foo` with `{...}`
2. Service validates, writes row to `bar`
3. ...

## 6. Error Cases and Failure Modes

| Failure | Detection | Response | Recovery |
|---|---|---|---|
| Upstream timeout | 5s deadline | 503 + retry-after | circuit breaker opens at 5/min |
| Duplicate request | idem-key collision | 200 with original result | — |
| Malformed payload | schema validation | 400 + field-level detail | — |
| Downstream 5xx | status | 502 + structured error | retry 3x w/ backoff, then DLQ |
| Partial write | post-write readback | compensating delete | — |

## 7. Performance and Scale

- **Expected load:** <requests/sec, peak, growth>
- **Latency budget:** <p50, p95, p99>
- **Resource ceiling:** <memory, connections, queue depth>
- **Caching strategy:** <layer, TTL, invalidation>
- **Rate limiting:** <per-user, per-tenant, global>
- **Capacity test plan:** <what load test, what SLOs, what would flag a regression>

## 8. Security and Privacy

- **Authn:** <who can call>
- **Authz:** <RBAC/ABAC rules>
- **PII:** <what's stored, retention, redaction points>
- **Secrets:** <how injected, rotation strategy>
- **Input validation:** <schema, sanitization, size limits>
- **Output encoding:** <contexts where data is rendered>
- **Audit logging:** <what actions get logged, to where>
- **Threat model summary:** <top 3 risks, mitigations>

## 9. Observability

- **Metrics:** <name + unit + dimensions>
- **Logs:** <structured fields, sampling>
- **Traces:** <span names, attributes>
- **Dashboards to update:** <links/paths>
- **Alerts to add:** <condition + severity + runbook link>

## 10. Rollout

- **Feature flag:** `<key>` (if any)
- **Migration order:** <schema → backfill → deploy → cutover → cleanup>
- **Backfill strategy:** <online, chunk size, throttle>
- **Cutover:** <dual-write window, read switch, rollback trigger>

## 11. Rollback Plan

**This section is mandatory. No design ships Gate 2 without a concrete rollback plan.**

- **Trigger condition:** <what operationally signals "roll back">
- **Steps to roll back:**
  1. <>
  2. <>
- **Data compatibility during rollback:** <are writes compatible with old code?>
- **Decision authority:** <who makes the call>

## 12. Dependencies & Risks

- **External deps introduced:** <libs, services, versions>
- **Existing deps upgraded:** <pkg, from, to, breaking changes>
- **Unknown unknowns:** <where we're least confident, what a spike would resolve>

## 13. Decisions Requiring ADRs

If any of the following are true, emit a corresponding `adr-NNN-<slug>.md`:
- Chose between two or more viable approaches with different tradeoffs
- Introduced a new external dependency / service / data store
- Established a new pattern intended to be reused
- Made a decision someone may want to revisit in 6 months

**ADRs emitted:**
- [ ] `adr-NNN-<slug>.md`

## 14. Open Questions

- [ ] **[BLOCKING]** <>
- [ ] **[NON-BLOCKING]** <>
