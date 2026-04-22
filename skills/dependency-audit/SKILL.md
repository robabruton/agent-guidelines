---
name: dependency-audit
description: Audit dependency additions, updates, removals, manifests, and lockfiles for necessity, security, maintenance, licensing, and supply-chain risk.
when_to_use: Use when adding, updating, removing, or questioning dependencies, package manifests, lockfiles, vendored code, generated clients, or third-party assets.
argument-hint: "[file|directory|package|changes|project]"
allowed-tools: Read Grep Glob
---

Audit dependency decisions. Use this skill when a project adds, updates,
removes, vendors, or questions a dependency, or when package manifests
and lockfiles need a focused risk review.

This is a decision workflow, not a generic security scan. Produce a
clear recommendation: accept, accept with conditions, replace, remove,
defer, or investigate further.

Apply the audit areas selectively based on the dependency and project.
Do not turn every checklist item into a finding; report only issues that
change the dependency decision or require explicit follow-up.

## Target Selection

Determine the target from the user request:

- No target: audit changed dependency files.
- Package name: audit that dependency and its usage.
- Manifest or lockfile: audit dependencies represented by that file.
- Directory or project: audit dependency surfaces in that scope.
- Branch or changes: audit staged and unstaged dependency changes.

For changed-dependency targets, inspect both staged and unstaged
changes. Use `git diff --name-only`, `git diff --cached --name-only`,
and `git status --short` when available.

Prefer `rg --files` to find dependency files. Common surfaces include
package manifests, lockfiles, vendored directories, generated clients,
container files, language toolchain files, plugin manifests, and
third-party asset directories.

Examples include `package.json`, lockfiles, `requirements.txt`,
`pyproject.toml`, `Pipfile`, `Gemfile`, `go.mod`, `Cargo.toml`,
`pom.xml`, `build.gradle`, NuGet project files, `composer.json`,
container images, package manager config, and vendored source trees.

## Audit Areas

### Necessity and Scope

- The dependency duplicates standard-library or existing project
  functionality without a clear reason.
- The dependency is much broader than the feature needs.
- A small local implementation would be safer or simpler.
- Runtime dependencies are used only in development, tests, build steps,
  examples, or optional integrations.
- Transitive dependencies add significant weight or risk for limited
  value.
- A direct dependency exists only because an indirect dependency was not
  understood.

### Maintenance and Provenance

- The package appears abandoned, poorly maintained, newly published, or
  controlled by an unclear maintainer.
- Release history, issue activity, or compatibility policy creates
  upgrade risk.
- The package source, registry entry, or repository metadata is
  inconsistent.
- The dependency is pinned to an unstable branch, commit, local path, or
  unpublished source without a reason.
- Vendored or copied code lacks origin, version, or update instructions.
- Generated clients or SDKs are checked in without enough provenance to
  regenerate or update them.

### Security and Supply Chain

- The dependency handles untrusted input, credentials, network traffic,
  filesystem paths, code execution, serialization, or cryptography.
- Known vulnerability data, advisory output, or project policy indicates
  risk.
- Install scripts, postinstall hooks, native extensions, generated code,
  or binary artifacts expand the trust boundary.
- Typosquatting, dependency confusion, maintainer takeover, or package
  substitution risk is plausible from the package source.
- The dependency adds risky transitive dependencies.

### License and Distribution

- License metadata is missing, unclear, incompatible with distribution,
  or different between registry and source repository.
- Copied assets, generated files, vendored code, or examples lack
  license attribution.
- Optional commercial, copyleft, patent, export, or notice obligations
  need project-owner review.

Do not provide legal advice. Flag license concerns as project or legal
review items when compatibility is unclear.

### Versioning and Lockfiles

- Manifest and lockfile changes do not match.
- Lockfile churn is unrelated to the requested dependency change.
- Version ranges are broader than the project's update policy.
- Major upgrades lack migration review or compatibility testing.
- Multiple versions of the same package are introduced without a reason.
- Dependency removals leave unused imports, docs, scripts, or generated
  files behind.
- Dependency updates require generated files, API clients, or lockfiles
  to be refreshed but only part of the update is present.

## Verification Sources

Use local project sources first:

- Manifests and lockfiles.
- Imports, requires, includes, generated code, and build scripts.
- Tests, examples, docs, and CI configuration.
- Existing dependency policy or license files.
- Package manager audit output, when available and safe to run.

If network access or registry lookups are unavailable, state that
package health, vulnerabilities, and license metadata were assessed only
from local sources.

Do not install packages, update lockfiles, run package manager commands
that mutate files, or contact external registries unless the user asks
and the environment policy allows it.

When an audit relies on external data that is unavailable, do not guess.
List the exact checks that remain unresolved.

## Finding Standard

Each finding must include:

- The dependency or file involved.
- The decision risk.
- The local evidence.
- The recommended action.

Suppress concerns that are theoretical, already mitigated by project
constraints, or unrelated to the dependency decision.

## Output Format

Lead with a recommendation:

```text
Recommendation: accept | accept with conditions | replace | remove |
defer | investigate further
```

Then list findings by severity:

```text
High
- package/file - Risk. Evidence. Recommended action.

Medium
- package/file - Risk. Evidence. Recommended action.

Low
- package/file - Risk. Evidence. Recommended action.
```

After findings, include:

- Dependency surfaces audited.
- Local evidence checked.
- Commands or audit reports used, if any.
- Unknowns, especially registry, vulnerability, or license information
  that could not be verified.

If no material issues are found, say that clearly and state whether the
recommendation is unconditional or depends on unverified external
metadata.
