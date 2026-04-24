#!/usr/bin/env bash
# Scaffold a new feature directory under specs/<slug>/ with empty templates.
set -euo pipefail

slug="${1:-}"
if [[ -z "$slug" ]]; then
  echo "Usage: $0 <slug>"
  echo "  slug format: YYYY-MM-DD-<kebab-title>"
  exit 1
fi

skill_root="$(cd "$(dirname "$0")/.." && pwd)"
templates="$skill_root/references/templates"
target="specs/$slug"

if [[ -d "$target" ]]; then
  echo "Error: $target already exists" >&2
  exit 1
fi

mkdir -p "$target"

# Copy templates
for t in spec.md design.md test-plan.md review-checklist.md changelog-entry.md pr-body.md; do
  if [[ -f "$templates/$t" ]]; then
    cp "$templates/$t" "$target/$t"
  fi
done

# Rename a couple for feature-local naming
[[ -f "$target/review-checklist.md" ]] && mv "$target/review-checklist.md" "$target/review.md"
[[ -f "$target/changelog-entry.md" ]] && mv "$target/changelog-entry.md" "$target/changelog.md"

# Empty stubs
: > "$target/request.md"
: > "$target/discovery.md"
: > "$target/plan.md"

# Initial state.json
cat > "$target/state.json" <<EOF
{
  "slug": "$slug",
  "phase": "intake",
  "iteration": 0,
  "size": null,
  "risk": null,
  "crew": [],
  "gates": {},
  "skipped": [],
  "stack": null,
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# Empty crew_plan.json — triage will fill
cat > "$target/crew_plan.json" <<'EOF'
{}
EOF

echo "Scaffolded $target/"
ls -la "$target/"
