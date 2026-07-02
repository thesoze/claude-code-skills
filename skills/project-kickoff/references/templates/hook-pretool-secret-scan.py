#!/usr/bin/env python3
"""
PreToolUse hook — blocks Write/Edit of files that contain hard-coded secrets.

Registered in .claude/settings.json under hooks.PreToolUse with matcher for
Write, Edit, NotebookEdit.

Reads the tool call envelope from stdin, extracts the content being written,
and scans for common credential patterns. If a high-confidence match is
found, blocks the tool call with a clear error message.

This is a DETERMINISTIC guard — catches accidental commits of creds that made
it into a file the model is about to save. False positives are possible
(random base64 strings); override with env var PROJECT_KICKOFF_SECRET_SCAN=off
for ad-hoc bypass.
"""
from __future__ import annotations
import json
import os
import re
import sys
from typing import Any

DISABLED = os.environ.get("PROJECT_KICKOFF_SECRET_SCAN", "").lower() == "off"

# (pattern, label, description)
PATTERNS: list[tuple[re.Pattern[str], str, str]] = [
    (re.compile(r"AKIA[0-9A-Z]{16}"), "aws_access_key", "AWS access key ID"),
    (re.compile(r"aws_secret_access_key\s*=\s*['\"]?[A-Za-z0-9/+=]{40}['\"]?", re.I), "aws_secret_key", "AWS secret access key"),
    (re.compile(r"gh[pousr]_[A-Za-z0-9]{36,}"), "github_token", "GitHub personal access token"),
    (re.compile(r"github_pat_[A-Za-z0-9_]{80,}"), "github_fine_grained_pat", "GitHub fine-grained PAT"),
    (re.compile(r"sk-ant-api03-[A-Za-z0-9_-]{90,}"), "anthropic_key", "Anthropic API key"),
    (re.compile(r"sk-[A-Za-z0-9]{48,}(?!\S)"), "openai_key", "OpenAI-style API key"),
    (re.compile(r"xox[baprs]-[0-9A-Za-z-]{10,}"), "slack_token", "Slack token"),
    (re.compile(r"AIza[0-9A-Za-z_-]{35}"), "google_api_key", "Google API key"),
    (re.compile(r"-----BEGIN\s+(RSA\s+|EC\s+|OPENSSH\s+|DSA\s+|PGP\s+)?PRIVATE\s+KEY-----"), "private_key", "Private key block"),
    (re.compile(r"[A-Za-z0-9_\-]{0,20}(api[_-]?key|secret[_-]?key|auth[_-]?token|access[_-]?token|bearer[_-]?token)[A-Za-z0-9_\-]{0,10}\s*[:=]\s*['\"][A-Za-z0-9_\-]{24,}['\"]", re.I), "generic_named_secret", "Generic named secret assignment"),
    (re.compile(r"postgres(ql)?://[^:]+:[^@]+@[a-z0-9.-]+", re.I), "postgres_url_with_password", "PostgreSQL URL with inline credentials"),
    (re.compile(r"mongodb(\+srv)?://[^:]+:[^@]+@", re.I), "mongo_url_with_password", "MongoDB URL with inline credentials"),
    (re.compile(r"mysql://[^:]+:[^@]+@", re.I), "mysql_url_with_password", "MySQL URL with inline credentials"),
    (re.compile(r"amqps?://[^:]+:[^@]+@", re.I), "amqp_url_with_password", "AMQP URL with inline credentials"),
    (re.compile(r"redis://[^:]*:[^@]+@", re.I), "redis_url_with_password", "Redis URL with inline credentials"),
]

# Files where a "secret-looking" string is almost certainly fine (test fixtures, docs about secrets)
ALLOWLIST_PATH_PATTERNS = [
    re.compile(r"(^|/)tests?/.*fixtures?/"),
    re.compile(r"(^|/)test_data/"),
    re.compile(r"\.example(\.|$)"),
    re.compile(r"\.sample(\.|$)"),
    re.compile(r"CHANGELOG\."),
]


def extract_write_payload(envelope: dict[str, Any]) -> tuple[str, str]:
    """Return (file_path, content). Best-effort across Write/Edit/NotebookEdit envelopes."""
    tool_name = envelope.get("tool_name") or envelope.get("tool") or ""
    params = envelope.get("tool_input") or envelope.get("params") or envelope.get("input") or {}

    file_path = params.get("file_path") or params.get("path") or ""
    content = ""

    if "content" in params:
        content = params["content"]
    elif "new_string" in params:
        content = params["new_string"]  # Edit tool — scan the replacement
    elif "source" in params:  # NotebookEdit
        content = params.get("source", "")

    return str(file_path), str(content)


def is_allowlisted(path: str) -> bool:
    for pat in ALLOWLIST_PATH_PATTERNS:
        if pat.search(path):
            return True
    return False


def scan(content: str) -> list[dict[str, Any]]:
    findings = []
    for pattern, label, desc in PATTERNS:
        m = pattern.search(content)
        if m:
            matched = m.group(0)
            redacted = matched[:6] + "…" + matched[-4:] if len(matched) > 14 else "…"
            findings.append({
                "label": label,
                "description": desc,
                "redacted_match": redacted,
                "line": content[: m.start()].count("\n") + 1,
            })
    return findings


def main() -> int:
    if DISABLED:
        sys.stdout.write(sys.stdin.read())
        return 0

    raw = sys.stdin.read()
    if not raw.strip():
        return 0

    try:
        envelope = json.loads(raw)
    except json.JSONDecodeError:
        sys.stdout.write(raw)
        return 0

    path, content = extract_write_payload(envelope)

    if is_allowlisted(path) or not content:
        sys.stdout.write(raw)
        return 0

    findings = scan(content)

    if findings:
        # Block the tool call. PreToolUse honors a JSON permission decision on
        # stdout with exit 0 — this delivers the full reason to the model. (Exit
        # 2 would block too, but only the terse stderr line would reach it.)
        error_msg = (
            f"Secret-scan guard blocked this write to {path}:\n"
            + "\n".join(
                f"  - Line {f['line']}: {f['description']} (match: {f['redacted_match']})"
                for f in findings
            )
            + "\n\nOptions:\n"
            "  1. Remove the secret from content and retry.\n"
            "  2. If the file is a legit fixture/example, rename to match allowlist "
            "(*.example, tests/fixtures/, etc.) or add its path to the allowlist in "
            ".claude/hooks/pretool-secret-scan.py.\n"
            "  3. Ad-hoc override: run with PROJECT_KICKOFF_SECRET_SCAN=off set in env.\n"
        )

        # Emit a permission decision that Claude Code surfaces to the model and
        # prevents the tool call from proceeding.
        response = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": error_msg,
            },
            "_secret_scan_findings": findings,
        }
        sys.stdout.write(json.dumps(response))
        sys.stderr.write(f"[pretool-secret-scan] BLOCKED write to {path}: {[f['label'] for f in findings]}\n")
        return 0  # exit 0 — the JSON deny above is the block signal

    # Clean — pass through unchanged
    sys.stdout.write(raw)
    return 0


if __name__ == "__main__":
    sys.exit(main())
