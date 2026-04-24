# Changelog Entry: {{feature_title}}

**Slug:** `{{slug}}`
**Target file:** `CHANGELOG.md` (project root)
**Format:** Keep a Changelog 1.1.0

## Entry to stage

Copy the block below into `CHANGELOG.md` under the next unreleased section.

```markdown
## [Unreleased]

### Added
- <user-visible addition — one sentence, user-facing language> ([{{slug}}](./specs/{{slug}}/spec.md))

### Changed
- <user-visible change>

### Deprecated
- <feature marked for removal>

### Removed
- <feature removed>

### Fixed
- <user-visible bugfix>

### Security
- <security-relevant change — always document these>
```

## Guidance

- **User-visible only.** Internal refactors, test-only changes, and non-breaking perf optimizations usually don't need a changelog entry.
- **User language.** "Added dark-mode support" not "Added `DarkModeProvider` context wrapper".
- **One line per change.** Link to the spec for depth.
- **Security entries are always warranted.** Even if the change is internal.
- **Breaking changes:** mark with `**BREAKING:**` prefix and include a migration note.

## If nothing user-visible changed

Note in `state.json.skipped`:
```json
{"phase": "docs", "reason": "no user-visible change", "at": "..."}
```
and skip this entry.
