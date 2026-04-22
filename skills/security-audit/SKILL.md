---
name: security-audit
description: Audit code, configuration, dependencies, scripts, firmware security surfaces, and system design for exploitable security vulnerabilities based on the actual attack surface.
when_to_use: Use when reviewing authentication, authorization, secrets, cryptography, input trust boundaries, dependencies, deployment exposure, firmware security, or other exploitable security risks.
argument-hint: "[file|directory|project|branch|commit|changes]"
allowed-tools: Read Grep Glob
---

Audit a project, file, directory, branch, or change for security
vulnerabilities. Use this skill when asked to find security issues,
review exposed attack surface, assess secrets or credentials, check
authentication or authorization behavior, inspect cryptography, review
dependency risk, or evaluate firmware security concerns.

This skill is adaptive. Identify the attack surface first, then apply
only the security checks that match the project. Do not produce generic
checklist output for categories that are not relevant.

## Target Selection

Determine the audit target from the user request:

- No target: audit changed security-relevant files and configuration.
- File path: audit that file.
- Directory path: audit relevant surfaces under that directory.
- `project`: audit the repository.
- Branch, commit, or diff: audit the security impact of those changes.

For changed-code audits, inspect both staged and unstaged changes. Use
`git diff --name-only`, `git diff --cached --name-only`, and
`git status --short` when available.

Prefer `rg --files` to find likely targets. Include source files,
configuration, environment examples, scripts, CI files, dependency
manifests, lockfiles, Docker or deployment files, firmware update or boot
code, protocol parsers, auth middleware, access-control code, crypto
helpers, key handling, and documentation that describes security
behavior.

If the target has no meaningful security surface, say so and state what
was checked.

## Attack Surface First

Before looking for findings, identify:

- **Entry points:** HTTP routes, CLIs, RPC handlers, webhooks, parsers,
  file imports, queues, protocol handlers, bootloader commands, debug
  commands, update flows, and admin tools.
- **Trust boundaries:** User input, network input, local files, external
  devices, buses, plugins, dependencies, environment variables, build
  artifacts, manufacturing tools, and privileged processes.
- **Assets:** Credentials, tokens, keys, private data, firmware images,
  personal data, regulated data, device identity, user accounts,
  persistent state, money, permissions, control of hardware, and
  availability.
- **Privileges:** Caller identity, process user, filesystem permissions,
  cloud roles, device modes, admin paths, debug access, and production
  versus development behavior.

Use this map to decide which audit areas apply.

## Audit Areas

### Injection and Input Handling

- Shell, command, SQL, NoSQL, LDAP, template, path, format-string, and
  code injection.
- Unsafe deserialization, dynamic imports, dynamic evaluation, or plugin
  loading from untrusted data.
- Missing validation for type, length, encoding, range, canonical form,
  and duplicate fields.
- Trusting client-provided identifiers, paths, filenames, object keys, or
  user roles.
- Parser behavior on malformed, nested, truncated, oversized, or
  ambiguous input.
- File upload, archive import, webhook, callback, and redirect handling
  that trusts attacker-controlled metadata or destinations.

### Authentication and Authorization

- Missing authentication on sensitive routes, commands, handlers, or
  device operations.
- Broken object-level, tenant-level, role-level, or admin authorization.
- Privilege escalation through confused deputy paths or trusted internal
  calls.
- Insecure password storage, reset, enrollment, pairing, or provisioning.
- Session fixation, weak token lifecycle, missing logout invalidation, or
  missing expiry.
- Missing rate limiting, lockout, abuse controls, or replay protection
  where they matter.
- Authentication decisions made in client-side code or bypassable
  middleware ordering.
- Missing tenant, account, workspace, or project isolation checks.

### Secrets and Credentials

- Hardcoded passwords, API keys, tokens, private keys, certificates, or
  connection strings.
- Real secrets in examples, tests, logs, build artifacts, firmware
  images, scripts, or documentation.
- Unsafe secret defaults, fallback credentials, or development bypasses.
- Secrets passed through command lines, URLs, world-readable files, crash
  dumps, or logs.
- Device identity keys, provisioning secrets, or manufacturing keys
  stored without appropriate protection.

### Cryptography

- Weak or inappropriate algorithms, modes, hashes, key sizes, or random
  sources.
- Missing authentication or integrity checks around encrypted data.
- Reused nonces, IVs, salts, sequence numbers, or counters.
- Hardcoded keys, static IVs, predictable randomness, or shared secrets
  across devices or tenants.
- Custom crypto protocols when a standard construction should be used.
- Certificate, signature, or key validation that can be bypassed.

### Filesystem and Local Environment

- Path traversal, symlink races, unsafe temporary files, and unsafe
  archive extraction.
- Privileged writes using user-controlled paths or filenames.
- Insecure file or directory permissions.
- Unsafe cleanup, backup, restore, migration, or installer behavior.
- Local configuration that crosses the boundary between private machine
  state and tracked project files.

### Network, Web, and API Security

- Sensitive data sent over cleartext or logged in transit.
- TLS verification disabled or weakened.
- SSRF, open redirect, request smuggling, cache poisoning, or DNS
  rebinding risks.
- Overly permissive CORS, missing CSRF protection, or unsafe cookie
  attributes.
- XSS, unsafe HTML rendering, unsafe markdown rendering, or content
  injection.
- Missing or incorrectly verified webhook signatures.
- Missing security headers when the project serves browser-facing
  content.

### Dependency and Supply Chain

- Known-vulnerable dependencies, abandoned packages, unpinned critical
  dependencies, or stale lockfiles.
- Dependency confusion, typosquatting, untrusted registries, or install
  scripts with elevated risk.
- Build, release, CI, or deployment steps that trust unverified artifacts.
- Generated code, vendored code, or binaries with unclear provenance.
- CI tokens, workflow permissions, caches, artifacts, or pull-request
  triggers that let untrusted code reach secrets or releases.

### Cloud, Deployment, and Operations

- Overbroad IAM roles, service accounts, tokens, or deployment secrets.
- Public storage, databases, dashboards, metrics, admin panels, or debug
  endpoints.
- Environment-specific bypasses that can leak into production.
- Containers running as root, mounting sensitive host paths, or embedding
  secrets.
- Missing audit logging for security-relevant actions.
- Public debug, profiling, tracing, documentation, health, or metrics
  endpoints exposing sensitive data or control surfaces.

### Firmware and Device Security

Apply this section only when the project includes firmware, devices,
hardware-facing code, update flows, debug access, or exposed protocols.
For general firmware correctness, use `firmware-review` instead.

- Missing or bypassable secure boot, image signature verification, or
  boot chain validation.
- Firmware update flows that allow unsigned images, tampering, replay, or
  rollback/downgrade.
- Debug, manufacturing, test, JTAG, SWD, serial console, or diagnostic
  modes left available in production.
- Device credentials, identity keys, calibration secrets, or pairing
  material stored or provisioned insecurely.
- Unauthenticated or weakly authenticated commands over UART, CAN, BLE,
  MQTT, USB, radio, local network, or maintenance channels.
- Weak crypto, nonce reuse, shared keys, or missing integrity checks in
  device protocols.
- Malicious peripheral, bus, host, or update server inputs trusted across
  a security boundary.
- Recovery or factory-reset behavior that bypasses security controls.

## Review Process

1. Identify the attack surface, assets, trust boundaries, and privilege
   levels before reporting findings.
2. Read the relevant files before forming findings.
3. Trace how untrusted input reaches sensitive operations.
4. Trace authentication and authorization decisions to the protected
   resource or action.
5. Trace secret and key lifetimes from creation or load through use,
   storage, logging, and disposal.
6. Check tests, docs, examples, deployment files, and configuration for
   mismatches with the code's security behavior.
7. For diffs, inspect surrounding routing, middleware, validation,
   serialization, authorization, and deployment context instead of
   reviewing only changed lines.
8. Use dependency scanners, secret scanners, static analysis, or package
   audit tools when available and relevant, but confirm tool output
   against the actual project.
9. Report only issues with a realistic security consequence.

Do not report generic hardening advice unless it closes a concrete risk
in the reviewed project.

Do not turn this into a generic code review. Correctness bugs belong here
only when they create or materially increase a security risk.

Do not run commands that modify files, install packages, contact
production services, rotate credentials, scan external systems, exploit
vulnerabilities, or require elevated privileges unless the user
explicitly asks for that execution. Prefer static inspection, local
tests, read-only scanners, and dry-run modes.

Do not attempt exploitation, fuzzing against external systems, password
guessing, token validation against live services, or production probing
unless the user explicitly authorizes the exact scope.

Do not include secrets in the response. If a secret is found, identify
the file, line, and type of secret without repeating the full value.
Recommend rotation or revocation when a real secret may have been
committed or exposed.

Do not disclose exploit steps beyond what is needed to explain impact and
fix the issue. Keep proof-of-concept details minimal and local to the
reviewed code.

## Finding Standard

Each finding must include:

- The affected asset or security boundary.
- The attacker or untrusted input that can reach the issue.
- The realistic impact.
- The specific code path, configuration, dependency, command, or protocol
  involved.
- A concrete fix or mitigation.

Suppress a concern when it is only theoretical, requires an attacker
capability outside the project's trust model, is already blocked by
surrounding controls, or is general best practice without an exploit path
or meaningful risk reduction.

If exploitability depends on deployment, cloud policy, hardware fuses,
production configuration, or undocumented infrastructure, label it as an
assumption to verify rather than stating it as fact.

If a scanner reports an issue, verify whether the vulnerable code path is
reachable, whether the affected version is actually used, and whether
existing controls reduce exploitability before reporting it.

Separate confirmed findings from assumptions. Do not inflate severity for
unverified deployment or hardware behavior; instead state what evidence
would confirm the risk.

## Output Format

Start with a short attack surface summary, then list findings grouped by
severity:

```text
Attack Surface
- Entry points:
- Trust boundaries:
- Assets:

Critical
- path:line - Issue. Impact. Suggested fix.

High
- path:line - Issue. Impact. Suggested fix.

Medium
- path:line - Issue. Impact. Suggested fix.

Low
- path:line - Issue. Impact. Suggested fix.

Assumptions To Verify
- path:line - Condition that could become a finding if confirmed.
```

Use these severities:

- **Critical:** Direct path to system compromise, credential compromise,
  remote code execution, destructive device control, signed-update bypass,
  or broad unauthorized data access.
- **High:** Realistic privilege escalation, auth bypass, secret exposure,
  significant injection, firmware downgrade/tamper path, or access to
  sensitive resources.
- **Medium:** Security control weakness requiring specific conditions,
  limited data exposure, abuse path with constraints, or defense-in-depth
  gap with realistic impact.
- **Low:** Minor hardening issue, limited information leak, unclear
  production exposure, or best-practice gap with small direct impact.

After findings, include:

- Tools, tests, scanners, or commands run, if any.
- Categories that were applicable, plus major categories skipped as not
  relevant.
- Assumptions that need verification.
- Residual risk, especially deployment, hardware, or production behavior
  that was not available for review.

If no issues are found, say that clearly and still state what was
audited, what attack surface was considered, and what was not verified.
