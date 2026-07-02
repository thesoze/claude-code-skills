#!/usr/bin/env bash
# Stack profile emitter for feature-crew.
# Reads manifest files from $PWD and emits a JSON profile.
# Exits 0 on success, 1 on fatal error. Unknowns are emitted as "unknown" strings.
set -o pipefail

root="${1:-$PWD}"
cd "$root" 2>/dev/null || { echo "{\"error\":\"cannot cd to $root\"}"; exit 1; }

langs=()
frameworks=()
pm="unknown"
lint_cmd="unknown"
typecheck_cmd="unknown"
test_cmd="unknown"
build_cmd="unknown"
fmt_cmd="unknown"
is_monorepo="false"
monorepo_tool="none"

detect_json() {
  local file="$1" key="$2"
  # Lightweight JSON key grab without jq dep
  python3 -c "
import json, sys
try:
    with open('$file') as f: d = json.load(f)
    keys = '$key'.split('.')
    for k in keys: d = d.get(k, {}) if isinstance(d, dict) else {}
    print(d if d else '')
except Exception: print('')
" 2>/dev/null
}

has() { [[ -f "$1" ]]; }
has_any() { for f in "$@"; do [[ -f "$f" ]] && return 0; done; return 1; }

# Monorepo detection
has pnpm-workspace.yaml && { is_monorepo="true"; monorepo_tool="pnpm"; }
has nx.json && { is_monorepo="true"; monorepo_tool="nx"; }
has turbo.json && { is_monorepo="true"; monorepo_tool="turbo"; }
has lerna.json && { is_monorepo="true"; monorepo_tool="lerna"; }

# --- Node / TypeScript / JavaScript ---
if has package.json; then
  langs+=("javascript")
  has tsconfig.json && langs+=("typescript")

  # Package manager
  if has pnpm-lock.yaml; then pm="pnpm"
  elif has yarn.lock; then pm="yarn"
  elif has bun.lockb || has bun.lock; then pm="bun"
  elif has package-lock.json; then pm="npm"
  else pm="npm"
  fi

  # Frameworks
  if grep -q '"next"' package.json 2>/dev/null; then frameworks+=("next"); fi
  if grep -q '"react"' package.json 2>/dev/null; then frameworks+=("react"); fi
  if grep -q '"vue"' package.json 2>/dev/null; then frameworks+=("vue"); fi
  if grep -q '"svelte"' package.json 2>/dev/null; then frameworks+=("svelte"); fi
  if grep -q '"express"' package.json 2>/dev/null; then frameworks+=("express"); fi
  if grep -q '"fastify"' package.json 2>/dev/null; then frameworks+=("fastify"); fi
  if grep -q '"nestjs"\|"@nestjs/core"' package.json 2>/dev/null; then frameworks+=("nestjs"); fi
  if grep -q '"remix"\|"@remix-run"' package.json 2>/dev/null; then frameworks+=("remix"); fi
  if grep -q '"astro"' package.json 2>/dev/null; then frameworks+=("astro"); fi

  # Commands — prefer scripts, fall back to sensible defaults
  if grep -q '"lint"' package.json 2>/dev/null; then lint_cmd="$pm run lint"
  elif has .eslintrc.js || has .eslintrc.json || has eslint.config.js || has eslint.config.mjs; then lint_cmd="npx eslint ."
  fi
  if grep -q '"typecheck"\|"type-check"' package.json 2>/dev/null; then typecheck_cmd="$pm run typecheck"
  elif has tsconfig.json; then typecheck_cmd="npx tsc --noEmit"
  fi
  if grep -q '"test"' package.json 2>/dev/null; then test_cmd="$pm test"
  fi
  if grep -q '"build"' package.json 2>/dev/null; then build_cmd="$pm run build"
  fi
  if grep -q '"format"' package.json 2>/dev/null; then fmt_cmd="$pm run format"
  elif has .prettierrc || has .prettierrc.json || has prettier.config.js; then fmt_cmd="npx prettier --write ."
  fi
fi

# --- Python ---
if has_any pyproject.toml setup.py requirements.txt Pipfile; then
  langs+=("python")

  # Package manager / runner
  if has uv.lock || { has .python-version && has pyproject.toml; }; then
    if command -v uv >/dev/null 2>&1; then
      pm="${pm/unknown/uv}"
    fi
  fi
  if has poetry.lock; then pm="${pm/unknown/poetry}"; fi
  if has Pipfile.lock; then pm="${pm/unknown/pipenv}"; fi

  # Frameworks
  if grep -q "fastapi" pyproject.toml 2>/dev/null || grep -q "fastapi" requirements.txt 2>/dev/null; then frameworks+=("fastapi"); fi
  if grep -q "django" pyproject.toml 2>/dev/null || grep -q "django" requirements.txt 2>/dev/null; then frameworks+=("django"); fi
  if grep -q "flask" pyproject.toml 2>/dev/null || grep -q "flask" requirements.txt 2>/dev/null; then frameworks+=("flask"); fi

  # Commands
  runner="python"
  if command -v uv >/dev/null 2>&1 && (has uv.lock || grep -q "^\[tool.uv\]" pyproject.toml 2>/dev/null); then
    runner="uv run"
  elif command -v poetry >/dev/null 2>&1 && has poetry.lock; then
    runner="poetry run"
  fi

  if grep -q "^\[tool.ruff\]" pyproject.toml 2>/dev/null || has .ruff.toml || has ruff.toml; then
    lint_cmd="$runner ruff check ."
    fmt_cmd="$runner ruff format ."
  elif grep -q "flake8" pyproject.toml 2>/dev/null; then
    lint_cmd="$runner flake8"
  fi

  if grep -q "mypy\|pyright" pyproject.toml 2>/dev/null || has mypy.ini || has pyrightconfig.json; then
    if grep -q "pyright" pyproject.toml 2>/dev/null || has pyrightconfig.json; then
      typecheck_cmd="$runner pyright"
    else
      typecheck_cmd="$runner mypy ."
    fi
  fi

  if grep -q "pytest" pyproject.toml 2>/dev/null || has pytest.ini || has tests/; then
    test_cmd="$runner pytest"
  fi

  # Python usually has no build step unless it's a package
  if grep -q "^\[build-system\]" pyproject.toml 2>/dev/null; then
    build_cmd="$runner python -m build"
  else
    build_cmd="n/a"
  fi
fi

# --- Go ---
if has go.mod; then
  langs+=("go")
  lint_cmd="golangci-lint run"
  typecheck_cmd="go vet ./..."
  test_cmd="go test ./..."
  build_cmd="go build ./..."
  fmt_cmd="gofmt -w ."
fi

# --- Rust ---
if has Cargo.toml; then
  langs+=("rust")
  lint_cmd="cargo clippy -- -D warnings"
  typecheck_cmd="cargo check"
  test_cmd="cargo test"
  build_cmd="cargo build --release"
  fmt_cmd="cargo fmt"
fi

# --- Ruby ---
if has Gemfile; then
  langs+=("ruby")
  has .rubocop.yml && lint_cmd="bundle exec rubocop"
  grep -q "rspec" Gemfile 2>/dev/null && test_cmd="bundle exec rspec"
  grep -q "rails" Gemfile 2>/dev/null && { frameworks+=("rails"); test_cmd="bundle exec rails test"; }
fi

# --- Java / Kotlin ---
if has_any pom.xml build.gradle build.gradle.kts; then
  if has pom.xml; then
    langs+=("java")
    test_cmd="mvn test"
    build_cmd="mvn package"
    lint_cmd="mvn checkstyle:check"
  else
    if grep -q "kotlin" build.gradle build.gradle.kts 2>/dev/null; then langs+=("kotlin"); else langs+=("java"); fi
    test_cmd="./gradlew test"
    build_cmd="./gradlew build"
    lint_cmd="./gradlew ktlintCheck"
  fi
fi

# --- PHP ---
if has composer.json; then
  langs+=("php")
  grep -q "phpunit" composer.json 2>/dev/null && test_cmd="vendor/bin/phpunit"
  grep -q "phpstan" composer.json 2>/dev/null && typecheck_cmd="vendor/bin/phpstan analyse"
  grep -q "laravel" composer.json 2>/dev/null && frameworks+=("laravel")
fi

# --- .NET ---
if ls *.csproj *.sln 2>/dev/null | head -1 | grep -q .; then
  langs+=("csharp")
  test_cmd="dotnet test"
  build_cmd="dotnet build"
  lint_cmd="dotnet format --verify-no-changes"
fi

# --- Elixir ---
if has mix.exs; then
  langs+=("elixir")
  test_cmd="mix test"
  lint_cmd="mix credo"
  typecheck_cmd="mix dialyzer"
  build_cmd="mix compile"
  grep -q "phoenix" mix.exs 2>/dev/null && frameworks+=("phoenix")
fi

# --- Dart / Flutter ---
if has pubspec.yaml; then
  langs+=("dart")
  grep -q "flutter" pubspec.yaml 2>/dev/null && { frameworks+=("flutter"); test_cmd="flutter test"; build_cmd="flutter build apk"; }
  lint_cmd="dart analyze"
fi

# --- Swift ---
if has Package.swift || ls *.xcodeproj 2>/dev/null | head -1 | grep -q .; then
  langs+=("swift")
  has Package.swift && { test_cmd="swift test"; build_cmd="swift build"; }
fi

# --- Primary language heuristic ---
primary="unknown"
if [[ ${#langs[@]:-0} -gt 0 ]]; then primary="${langs[0]}"; fi

# --- Emit JSON ---
join_arr() { local IFS=","; echo "\"${*// /\",\"}\""; }

jq_array() {
  local arr=("$@")
  if [[ $# -eq 0 ]]; then echo "[]"; return; fi
  local out="["
  for i in "$@"; do out+="\"$i\","; done
  echo "${out%,}]"
}

cat <<EOF
{
  "primary_language": "$primary",
  "languages": $(jq_array "${langs[@]}"),
  "frameworks": $(jq_array "${frameworks[@]}"),
  "package_manager": "$pm",
  "is_monorepo": $is_monorepo,
  "monorepo_tool": "$monorepo_tool",
  "lint_cmd": "$lint_cmd",
  "typecheck_cmd": "$typecheck_cmd",
  "test_cmd": "$test_cmd",
  "build_cmd": "$build_cmd",
  "format_cmd": "$fmt_cmd",
  "detected_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "root": "$root"
}
EOF
