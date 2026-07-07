---
when: adding error paths, logging, or user-facing failure messages
load: recall
summary: >-
  Failure paths fail loudly and say something actionable: no
  swallowed exceptions or accidental silent fallbacks, messages name
  what failed and what to do about it, no secrets or personal data
  in logs or error output, and exit codes and error types stay
  consistent with the surrounding surface. Exists because a silently
  absorbed error resurfaces later as an unrelated-looking failure
  that is far harder to trace.
---
# Error Handling Rules

## Fail Loudly

- Do not swallow an exception or error result to keep the happy path
  green. An absorbed failure produces a wrong result downstream that
  is far harder to trace than the original error.
- A silent fallback — defaulting when a resource is missing,
  substituting a cached value, retrying indefinitely — is a design
  decision: make it explicit, log it when it triggers, and justify
  it. It must never be the accidental result of a broad catch.
- Catch narrowly. Handle the specific failures the code can actually
  recover from and let the rest propagate to a layer that can.

## Actionable Messages

- An error message names what failed, the input or path involved,
  and what the reader can do about it. "Operation failed" costs a
  debugging session; "config.toml missing key `api.base_url`" costs
  a minute.
- Never print success-sounding output when part of the work failed;
  partial completion is reported as partial.
- Match the surrounding surface: CLI errors go to stderr with a
  nonzero exit code, and library or API errors use the established
  error types and status conventions of that surface.

## Logging

- No secrets, tokens, credentials, or personal data in logs, error
  messages, or crash output — at any log level. Redact values when
  the field itself must be named.
- Log at the level the event warrants: expected conditions are not
  errors, and real failures do not hide at debug level.
- Log a failure once, at the layer with the richest context, rather
  than at every layer it passes through; duplicate reports of one
  event bury the signal.
