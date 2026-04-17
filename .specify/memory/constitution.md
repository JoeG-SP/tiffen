<!--
Sync Impact Report
- Version change: 1.0.0 → 1.0.1 (platform constraint narrowed)
- Modified principles: N/A (initial)
- Added sections: Core Principles (5), Technical Constraints,
  Development Workflow, Governance
- Removed sections: None
- Templates requiring updates:
  - .specify/templates/plan-template.md — ✅ no updates needed
  - .specify/templates/spec-template.md — ✅ no updates needed
  - .specify/templates/tasks-template.md — ✅ no updates needed
  - .specify/templates/commands/*.md — no files present
- Follow-up TODOs: None
-->

# Tiffen Constitution

## Core Principles

### I. Data Safety

Original TIFF files MUST NOT be modified in place unless the user
explicitly opts in via a flag (e.g., `--in-place`). The default
behavior MUST write normalized outputs to a separate location or
use a non-destructive naming convention. Any operation that could
cause data loss MUST require explicit confirmation or a force flag.

### II. Correctness First

Exposure normalization MUST produce pixel-accurate results. The
exposure range of every output file MUST match the base TIFF's
range within documented numerical precision. Rounding, clamping,
and bit-depth conversion behavior MUST be explicitly defined and
tested against known reference images.

### III. CLI-First

Tiffen is a command-line tool. All functionality MUST be accessible
via CLI arguments and flags. Input is file paths and options; output
is normalized TIFF files plus human-readable status on stdout and
errors on stderr. Exit codes MUST follow standard conventions
(0 = success, non-zero = failure).

### IV. Simplicity

Tiffen does one thing: normalize exposure across a set of TIFFs to
match a base file. Features MUST directly serve this purpose. YAGNI
applies — no speculative abstractions, plugin systems, or GUI layers
unless explicitly requested. Prefer the standard library and minimal
dependencies.

### V. Testability

Every exposure calculation and file-handling path MUST be testable
with known reference TIFF fixtures. Tests MUST verify round-trip
correctness: a file normalized to a base and then re-normalized to
itself MUST be unchanged within precision bounds.

## Technical Constraints

- **Supported format**: TIFF files (all common bit depths: 8, 16,
  32-bit integer and floating point).
- **Performance**: Processing MUST scale linearly with the number
  of files. Large directories (1000+ files) MUST remain usable.
- **Platform**: MUST run on macOS. Cross-platform support is not
  a goal.
- **Dependencies**: Minimize external dependencies. Image I/O
  libraries are acceptable; large frameworks are not.

## Development Workflow

- All changes MUST be developed on feature branches and merged via
  pull request.
- Each PR MUST include tests that exercise the changed behavior.
- CI MUST pass before merge: linting, type checking (if applicable),
  and all tests green.
- Commit messages MUST be descriptive and reference the relevant
  spec or issue when applicable.

## Governance

This constitution is the authoritative source of development
principles for Tiffen. It supersedes informal conventions or
ad-hoc decisions.

- **Amendments**: Any change to this constitution MUST be documented
  with a version bump, rationale, and updated date.
- **Versioning**: Constitution versions follow semantic versioning
  (MAJOR.MINOR.PATCH). MAJOR for principle removals or redefinitions,
  MINOR for new principles or material expansions, PATCH for
  clarifications and wording fixes.
- **Compliance**: All PRs and code reviews SHOULD verify alignment
  with these principles. Deviations MUST be justified in the PR
  description.

**Version**: 1.0.1 | **Ratified**: 2026-04-17 | **Last Amended**: 2026-04-17
