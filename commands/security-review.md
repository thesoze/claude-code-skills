---
description: Stack-agnostic SAST (static application security testing) on the current repo. Detects stack, picks appropriate tools, runs checks against OWASP 2025 categories and project-specific risks.
---

# Security Review (SAST) — Global

Run **static** application security testing on this codebase. For dynamic testing against a running app, use `/pentest`.

Project-level `/security-review` commands take precedence over this global command — use this when dropped into a new repo without project-specific guidance.

## Step 1 — Detect stack

```bash
bash ~/.claude/skills/feature-crew/scripts/detect_stack.sh
```

Cache the output and read the relevant fields: `primary_language`, `frameworks`, `package_manager`, `lint_cmd`.

## Step 2 — Run automated SAST tools (per stack)

### Python
```bash
{{package_manager}} run ruff check .
{{package_manager}} run bandit -r <src-dir> -c pyproject.toml 2>/dev/null || {{package_manager}} run bandit -r <src-dir>
{{package_manager}} pip list --format=freeze | {{package_manager}} run pip-audit --requirement /dev/stdin 2>/dev/null || echo "pip-audit not installed"
```

### JavaScript / TypeScript
```bash
{{package_manager}} audit --audit-level=moderate
npx semgrep scan --config=auto --error
# If repo has `eslint-plugin-security`:
{{package_manager}} run lint
```

### Go
```bash
go vet ./...
# If gosec installed:
gosec ./... 2>/dev/null || echo "install: go install github.com/securego/gosec/v2/cmd/gosec@latest"
# Dep audit:
go list -json -m all | nancy sleuth 2>/dev/null || echo "nancy not installed"
```

### Rust
```bash
cargo clippy -- -D warnings
cargo audit 2>/dev/null || echo "install: cargo install cargo-audit"
```

### Ruby
```bash
bundle exec brakeman --no-pager 2>/dev/null || echo "install: gem install brakeman"
bundle audit check --update 2>/dev/null || echo "install: gem install bundler-audit"
```

### Java / Kotlin
```bash
# If Gradle:
./gradlew dependencyCheckAnalyze 2>/dev/null || echo "add: org.owasp.dependencycheck plugin"
# If Maven:
mvn dependency-check:check 2>/dev/null || echo "add dependency-check plugin"
```

### Cross-stack (any repo)
```bash
# Secret scanning
gitleaks detect --source . --redact -v 2>/dev/null || echo "install: brew install gitleaks"
# Semgrep rulesets (auto-detects language)
npx semgrep scan --config=p/owasp-top-ten --config=p/cwe-top-25 --error
```

## Step 3 — Review against OWASP 2025 categories

Parallel agents (one per category) for L/XL codebases; sequential for smaller repos.

### A01 — Broken Access Control
- Every write path has authorization check
- No IDOR (object IDs validated against caller identity/tenant)
- No function-level missing auth
- No forced browsing to admin paths

### A02 — Cryptographic Failures
- Passwords hashed with bcrypt/argon2/scrypt (not MD5/SHA-1/raw SHA-256)
- AEAD modes for symmetric crypto (AES-GCM, ChaCha20-Poly1305), never ECB
- Timing-safe comparison for HMAC/tokens (`hmac.compare_digest`, `crypto.timingSafeEqual`)
- TLS 1.2+ minimum, modern cipher suites
- No hardcoded IVs, no rolling-your-own crypto

### A03 — Injection
- No string-interpolated SQL (grep for `f"SELECT.*{`, `` `SELECT${ ``, etc.)
- No shell injection (`os.system`, `child_process.exec` with untrusted input)
- No LDAP/NoSQL/XPath injection
- No template injection (Jinja/Twig/etc. with untrusted template strings)
- No `eval`, `exec`, `Function()` with untrusted input

### A04 — Insecure Design
- Threat model documented for new sensitive surfaces
- Rate limiting on any public-facing mutation endpoint
- Defense in depth: authentication + authorization + input validation + output encoding

### A05 — Security Misconfiguration
- No default credentials in source
- No `.env` or secret files in git (`git log --all --oneline -- .env`)
- Security headers configured (CSP, HSTS, X-Frame-Options, X-Content-Type-Options)
- CORS not wide open (`*` with credentials)
- Error messages don't leak stack traces to users

### A06 — Vulnerable / Outdated Components
- Dep audit clean (from Step 2 outputs)
- Pinned versions, no floating `^` or `~` on security-critical deps
- Check for EOL runtimes (Python 3.8-, Node 16-, etc.)

### A07 — Identification & Authentication Failures
- Password complexity + length minimums enforced (prefer length over complexity)
- MFA supported for privileged accounts
- Session tokens: sufficient entropy, rotated on privilege change, invalidated on logout
- No predictable session IDs
- Rate limiting on auth endpoints

### A08 — Software & Data Integrity Failures
- Package lockfile committed and up-to-date
- CI builds verify signatures on dependencies where supported
- Webhook signature validation (HMAC with timing-safe compare)
- Deserialization: no `pickle.loads`, `YAML.load` (unsafe), `Marshal.load` on untrusted input

### A09 — Security Logging & Monitoring Failures
- Auth failures logged
- Privileged actions logged with actor, target, outcome
- No PII in logs (emails, SSNs, card numbers, access tokens)
- Log tampering resistance (append-only, centralized collection)

### A10 — SSRF
- Fetch-from-URL paths validate destination (no `localhost`, `169.254.169.254`, private IPs, `file://`, `gopher://`)
- URL parsers used consistently (no hand-rolled regex for URL validation)
- Protocol allowlist (only `http`/`https` if that's the intent)

## Step 4 — Domain-specific checks (beyond OWASP)

- **Webhook security:** HMAC-validated, timing-safe compare, replay defense (timestamp + nonce)
- **Multi-tenant:** all queries scoped by tenant ID at repository layer; no cross-tenant cache keys
- **File uploads:** size limit, content-type allowlist (not blocklist), path-traversal-safe storage names, virus scan policy
- **API security:** rate limiting per-tenant + per-endpoint, schema validation at trust boundary, response shape enforcement
- **Secrets management:** secret store abstraction (vault / 1Password / AWS Secrets Manager), rotation documented, no secrets in env files checked in
- **Background jobs:** idempotent (deduplication keys), poison-message DLQ, retry budget
- **Caching:** cache keys include tenant/user ID for tenant-sensitive data; cache TTL set; no secret data cached beyond use

## Step 5 — Severity calibration

- **CRITICAL:** exploitable, produces auth bypass / data exposure / RCE / secret exposure. Ship-blocker.
- **HIGH:** missing webhook signature, weak crypto, SSRF potential, credential in log, unparameterized query.
- **MEDIUM:** missing rate limit, info disclosure in error, missing circuit breaker, broken audit trail.
- **LOW:** code quality, missing type hints, dead imports, style gaps.

## Step 6 — Report

Write findings with `file:line` references. For each finding: category, severity, attack scenario, fix.

## Notes on this command

- If project has its own `/security-review`, that one runs instead (project precedence).
- If `detect_stack.sh` can't identify the stack, ask the user for hints before running Step 2.
- For monorepos, run Step 2 per package where different stacks live.

## Related

- `/pentest` — Dynamic Application Security Testing (DAST)
- `feature-crew` skill — full SDLC including security phase on risky changes
