# Engineering Judgment Rules

Design principles for the recurring "which way should this go" decisions.
They bias toward simplicity, single ownership, and deferring complexity
until it is justified by real evidence.

## Prefer Explicit Choices Over Clever Auto-Detection

When a behavior can be selected explicitly at the call site, prefer that
over building "smart" detection into a low-level primitive.

- Keep primitives mechanism-only: they do one thing and take their inputs
  directly. Let the caller (or a higher-level policy layer) decide which
  variant to use.
- Do not have a primitive inspect global or ambient state to change its
  own output unless explicitly asked. That inference duplicates and
  eventually conflicts with the caller's own decisions.
- Exception: a genuinely global, invariant contract (one that must hold
  the same way everywhere) can be keyed centrally rather than passed at
  every call site. The test is whether it is a per-call *policy* choice
  (pass it in) or a system-wide *invariant* (centralize it).

## Do Not Design Abstractions Against a Single Instance

Defer extracting a shared abstraction until a second real instance exists
to reveal what is actually common. Designing the "general" interface from
one example (n=1) almost always guesses wrong and bakes in the wrong
seams.

- Build the concrete thing first. When the second case arrives, the
  shared shape becomes evident from the difference between the two.
- It is cheaper to extract a clean abstraction from two known instances
  than to bend a premature one to fit a case it never anticipated.

## Single Source of Truth per Datum; Derived Views Are Rebuildable

Each piece of data has exactly one authoritative store. Anything else
that holds the same data is a derived view, and it must be rebuildable
from the authoritative source.

- Do not maintain two stores that must be kept in sync by hand. If a
  second representation exists for speed or query convenience, make it
  explicitly derived and provide a command that rebuilds it from the
  source of truth.
- This keeps recovery simple ("rebuild the derived view") and prevents
  the classic drift between two competing sources.

## One Writer per Fact (Many Readers Are Fine)

When the same fact is observable from several places, decide which single
component *owns writing it*. Everyone else may read it; only the owner
emits the canonical value.

- The fix for a fact that several stages can each compute is never to
  blind the other stages to it — it is to designate one owner and have
  the others consume the owner's value instead of emitting a competing
  copy.

## Decide Each Surface's Exposure Explicitly

When a project has multiple interfaces (e.g. a CLI, an API, a UI, a tool
or plugin surface), every feature explicitly decides its exposure on each
one. Silence is not a decision.

- State, at the end of a feature, which surfaces expose it: added,
  already covered, or deliberately excluded with a reason.
- Asymmetry is fine and often correct (some surfaces aim for full
  operational parity; others expose only a safe read subset) — but make
  it a deliberate, recorded choice.

## Reference Material Is for Understanding, Not Bulk Porting

When a prior implementation, a competitor, or an old version exists,
treat it as a source of *requirements and edge cases*, not as code to
copy verbatim.

- Use it to learn what a feature must do and which corner cases matter.
- Design the new implementation fresh against current standards. Do not
  propose "porting" or "migrating" old code wholesale unless explicitly
  asked.
