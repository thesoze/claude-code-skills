#!/usr/bin/env bash
# audit_probe.sh — collect current project state for /project-kickoff
#
# Modes:
#   --mode=kickoff  emit baseline probe for first-run setup
#   --mode=audit    emit full probe including hook hashes, recent tool usage, secret scan
#
# Output: JSON to stdout. Errors go to stderr.

set -o pipefail

MODE="kickoff"
for arg in "$@"; do
  case "$arg" in
    --mode=kickoff) MODE="kickoff" ;;
    --mode=audit)   MODE="audit" ;;
    *) ;;
  esac
done

root="$PWD"

# ---- helpers ---------------------------------------------------------------

jstr() {
  # JSON-quote a string value
  python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"
}

has() { [[ -f "$1" ]]; }
has_any() { for f in "$@"; do [[ -f "$f" ]] && return 0; done; return 1; }
dir_has() { [[ -d "$1" ]]; }

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    echo "unknown"
  fi
}

# ---- stack detection -------------------------------------------------------

primary_language="unknown"
package_manager="unknown"
frameworks=()

if has package.json; then
  primary_language="typescript"
  # crude: presence of tsconfig means ts, else js
  has tsconfig.json || primary_language="javascript"
  if has pnpm-lock.yaml; then package_manager="pnpm"
  elif has yarn.lock; then package_manager="yarn"
  elif has bun.lockb; then package_manager="bun"
  else package_manager="npm"; fi
  # framework sniff
  grep -q '"next"' package.json 2>/dev/null && frameworks+=("nextjs")
  grep -q '"react"' package.json 2>/dev/null && frameworks+=("react")
  grep -q '"vue"' package.json 2>/dev/null && frameworks+=("vue")
  grep -q '"@nestjs/core"' package.json 2>/dev/null && frameworks+=("nestjs")
  grep -q '"express"' package.json 2>/dev/null && frameworks+=("express")
  grep -q '"fastify"' package.json 2>/dev/null && frameworks+=("fastify")
elif has pyproject.toml || has requirements.txt || has Pipfile || has setup.py; then
  primary_language="python"
  if has pyproject.toml && grep -q "tool.poetry" pyproject.toml 2>/dev/null; then package_manager="poetry"
  elif has pyproject.toml && grep -q "\[tool.uv\]" pyproject.toml 2>/dev/null; then package_manager="uv"
  elif has Pipfile; then package_manager="pipenv"
  else package_manager="pip"; fi
  grep -rqE "from django|import django" --include="*.py" . 2>/dev/null && frameworks+=("django")
  grep -rqE "from flask|import flask" --include="*.py" . 2>/dev/null && frameworks+=("flask")
  grep -rqE "from fastapi|import fastapi" --include="*.py" . 2>/dev/null && frameworks+=("fastapi")
elif has go.mod; then
  primary_language="go"
  package_manager="go"
elif has Cargo.toml; then
  primary_language="rust"
  package_manager="cargo"
elif has Gemfile; then
  primary_language="ruby"
  package_manager="bundler"
  grep -q 'rails' Gemfile 2>/dev/null && frameworks+=("rails")
elif has build.gradle || has build.gradle.kts; then
  primary_language="kotlin"
  package_manager="gradle"
elif has pom.xml; then
  primary_language="java"
  package_manager="maven"
elif has_any *.xcodeproj/project.pbxproj */Package.swift Package.swift; then
  primary_language="swift"
  package_manager="spm"
fi

# ---- git / remote ----------------------------------------------------------

git_remote=""
git_branch=""
if [[ -d .git ]] || git rev-parse --git-dir >/dev/null 2>&1; then
  git_remote="$(git remote get-url origin 2>/dev/null || echo '')"
  git_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
fi

# ---- claude code state -----------------------------------------------------

has_claude_dir="false"
dir_has .claude && has_claude_dir="true"

has_claude_md="false"
claude_md_has_kickoff_markers="false"
if has CLAUDE.md; then
  has_claude_md="true"
  grep -q "project-kickoff:begin" CLAUDE.md 2>/dev/null && claude_md_has_kickoff_markers="true"
fi

# ---- hooks on disk (audit mode only) ---------------------------------------

hooks_present_json="[]"
if [[ "$MODE" == "audit" ]] && dir_has .claude/hooks; then
  hook_entries=()
  while IFS= read -r -d '' f; do
    hash=$(sha256_file "$f")
    relpath="${f#./}"
    hook_entries+=("{\"path\":$(jstr "$relpath"),\"sha256\":$(jstr "$hash")}")
  done < <(find .claude/hooks -type f \( -name "*.py" -o -name "*.sh" -o -name "*.js" \) -print0 2>/dev/null)

  if [[ ${#hook_entries[@]} -gt 0 ]]; then
    hooks_present_json="[$(IFS=,; echo "${hook_entries[*]}")]"
  fi
fi

# ---- claude_md sections present (audit mode) -------------------------------

claude_md_sections_json="[]"
if [[ "$MODE" == "audit" ]] && has CLAUDE.md; then
  sections=$(grep -oE "project-kickoff:begin [a-z0-9-]+" CLAUDE.md 2>/dev/null | awk '{print $2}' | sort -u)
  if [[ -n "$sections" ]]; then
    section_entries=()
    while IFS= read -r s; do
      [[ -n "$s" ]] && section_entries+=("$(jstr "$s")")
    done <<< "$sections"
    claude_md_sections_json="[$(IFS=,; echo "${section_entries[*]}")]"
  fi
fi

# ---- recent tool usage (audit mode, best-effort) ---------------------------

recent_tool_usage_json="[]"
if [[ "$MODE" == "audit" ]]; then
  # Heuristic: grep source for external-fetch patterns. A richer version would
  # parse ~/.claude/projects/*/transcripts for actual tool calls, but that path
  # varies and is not guaranteed present.
  tools_seen=()
  if grep -rqE "WebFetch|fetch\(|axios|requests\.get|urllib|http\.Get|curl |wget " \
       --include="*.py" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
       --include="*.go" --include="*.rs" --include="*.rb" \
       . 2>/dev/null; then
    tools_seen+=("external_fetch")
  fi
  if grep -rqE "subprocess|exec\(|child_process|os\.system|Bash\(" \
       --include="*.py" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
       . 2>/dev/null; then
    tools_seen+=("shell_exec")
  fi
  if [[ ${#tools_seen[@]} -gt 0 ]]; then
    entries=()
    for t in "${tools_seen[@]}"; do entries+=("$(jstr "$t")"); done
    recent_tool_usage_json="[$(IFS=,; echo "${entries[*]}")]"
  fi
fi

# ---- secret scan (audit mode only) -----------------------------------------

# Emits: status, findings_count, and findings[] = [{path, tracked}]. The
# tracked flag lets Dimension 3 split BREACH (secret in a git-tracked file) from
# DRIFT (secret only in an untracked/gitignored file like a local .env).
# Shared regex set — keep in sync with hook-pretool-secret-scan.py and
# drift-dimensions.md Dimension 3.
SECRET_REGEX="(AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{80,}|sk-ant-api03-[A-Za-z0-9_-]{90,}|sk-[A-Za-z0-9]{48,}|xox[baprs]-[0-9A-Za-z-]{10,}|AIza[0-9A-Za-z_-]{35}|-----BEGIN (RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----)"

is_tracked() { git ls-files --error-unmatch "$1" >/dev/null 2>&1 && echo "true" || echo "false"; }

secret_scan_status="not_run"
secret_scan_findings_count=0
secret_findings_json="[]"
if [[ "$MODE" == "audit" ]]; then
  found_paths=()
  if command -v gitleaks >/dev/null 2>&1; then
    if gitleaks detect --no-git --redact --exit-code 0 --report-format json --report-path /tmp/gitleaks-audit-$$.json . >/dev/null 2>&1; then
      if [[ -f /tmp/gitleaks-audit-$$.json ]]; then
        while IFS= read -r p; do [[ -n "$p" ]] && found_paths+=("$p"); done < <(
          python3 -c "import json,sys; d=json.load(open('/tmp/gitleaks-audit-$$.json')); print('\n'.join(sorted({f.get('File','') for f in d if f.get('File')})))" 2>/dev/null
        )
        rm -f /tmp/gitleaks-audit-$$.json
      fi
      secret_scan_status="gitleaks"
    fi
  else
    # Regex fallback — list matching files (not line counts) so we can report paths.
    while IFS= read -r p; do [[ -n "$p" ]] && found_paths+=("${p#./}"); done < <(
      grep -rlE "$SECRET_REGEX" \
        --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=build \
        . 2>/dev/null
    )
    secret_scan_status="regex_fallback"
  fi

  secret_scan_findings_count=${#found_paths[@]}
  if [[ ${#found_paths[@]} -gt 0 ]]; then
    fentries=()
    for p in "${found_paths[@]}"; do
      fentries+=("{\"path\":$(jstr "$p"),\"tracked\":$(is_tracked "$p")}")
    done
    secret_findings_json="[$(IFS=,; echo "${fentries[*]}")]"
  fi
fi

# ---- emit JSON -------------------------------------------------------------

# Build a frameworks JSON array safely
if [[ ${#frameworks[@]} -gt 0 ]]; then
  frameworks_json=$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1:]))' "${frameworks[@]}")
else
  frameworks_json="[]"
fi

# Pipe all shell values into python via env vars to avoid literal-substitution footguns
export P_MODE="$MODE"
export P_ROOT="$root"
export P_LANG="$primary_language"
export P_PM="$package_manager"
export P_FRAMEWORKS_JSON="$frameworks_json"
export P_GIT_REMOTE="$git_remote"
export P_GIT_BRANCH="$git_branch"
export P_HAS_CLAUDE_DIR="$has_claude_dir"
export P_HAS_CLAUDE_MD="$has_claude_md"
export P_CLAUDE_MD_MARKERS="$claude_md_has_kickoff_markers"
export P_HOOKS_JSON="$hooks_present_json"
export P_SECTIONS_JSON="$claude_md_sections_json"
export P_TOOLS_JSON="$recent_tool_usage_json"
export P_SECRET_STATUS="$secret_scan_status"
export P_SECRET_COUNT="$secret_scan_findings_count"
export P_SECRET_FINDINGS_JSON="$secret_findings_json"

python3 <<'PYEOF'
import json, os

def to_bool(s):
    return s.strip().lower() == "true"

out = {
    "mode": os.environ["P_MODE"],
    "root": os.environ["P_ROOT"],
    "stack": {
        "primary_language": os.environ["P_LANG"],
        "package_manager": os.environ["P_PM"],
        "frameworks": json.loads(os.environ["P_FRAMEWORKS_JSON"]),
    },
    "git": {
        "remote": os.environ["P_GIT_REMOTE"],
        "branch": os.environ["P_GIT_BRANCH"],
    },
    "claude_code": {
        "has_dot_claude_dir": to_bool(os.environ["P_HAS_CLAUDE_DIR"]),
        "has_claude_md": to_bool(os.environ["P_HAS_CLAUDE_MD"]),
        "claude_md_has_kickoff_markers": to_bool(os.environ["P_CLAUDE_MD_MARKERS"]),
    },
}

if os.environ["P_MODE"] == "audit":
    out["hooks_present"] = json.loads(os.environ["P_HOOKS_JSON"])
    out["claude_md_sections_present"] = json.loads(os.environ["P_SECTIONS_JSON"])
    out["recent_tool_usage"] = json.loads(os.environ["P_TOOLS_JSON"])
    out["secret_scan"] = {
        "status": os.environ["P_SECRET_STATUS"],
        "findings_count": int(os.environ["P_SECRET_COUNT"] or 0),
        "findings": json.loads(os.environ.get("P_SECRET_FINDINGS_JSON") or "[]"),
    }

print(json.dumps(out, indent=2))
PYEOF
