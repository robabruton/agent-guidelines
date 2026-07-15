#!/usr/bin/env bash
# Verifies rule-body formatting preserves headings inside code fences.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d /tmp/agent-guidelines-rule-assembly.XXXXXX)"

trap 'rm -rf "$TMP_ROOT"' EXIT

# shellcheck source=lib/assemble-rules.sh
. "${ROOT_DIR}/lib/assemble-rules.sh"

RULE_FILE="${TMP_ROOT}/rule.md"
EXPECTED_FILE="${TMP_ROOT}/expected.md"
ACTUAL_FILE="${TMP_ROOT}/actual.md"

cat > "$RULE_FILE" <<'EOF'
---
when: testing rule assembly
load: recall
---
# Outside heading

~~~text
# Tilde fence heading
```
## Different marker remains code
~~~text
### Same marker with content remains code
~~~

  ```text
## Indented backtick heading
  ~~~
### Different marker remains code
  ```

   ~~~text
#### Three-space tilde heading
   ~~~

###### Level six stays unchanged
EOF

cat > "$EXPECTED_FILE" <<'EOF'
## Outside heading

~~~text
# Tilde fence heading
```
## Different marker remains code
~~~text
### Same marker with content remains code
~~~

  ```text
## Indented backtick heading
  ~~~
### Different marker remains code
  ```

   ~~~text
#### Three-space tilde heading
   ~~~

###### Level six stays unchanged
EOF

agent_guidelines_format_rule_body "$RULE_FILE" > "$ACTUAL_FILE"
cmp -s "$EXPECTED_FILE" "$ACTUAL_FILE"

printf 'rule assembly safety tests passed\n'
