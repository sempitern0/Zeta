#!/usr/bin/env bash
# Test failure propagation and staged-only linting without installing ShellCheck.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/repo"
cat > "$tmp/bin/shellcheck" <<'STUB'
#!/usr/bin/env bash
exit 23
STUB
chmod +x "$tmp/bin/shellcheck"
if PATH="$tmp/bin:$PATH" make -C "$ROOT" lint > "$tmp/lint.log" 2>&1; then
    echo 'make lint swallowed a failure' >&2; exit 1
fi
if grep -q 'ShellCheck passed' "$tmp/lint.log"; then echo "Unexpected matching content" >&2; exit 1; fi
cd "$tmp/repo"
git init -q
git config user.email test@example.invalid
git config user.name Test
printf '# Example\n' > README.md
git add README.md
# Documentation-only commits do not invoke the failing checker.
bash "$ROOT/githooks/pre-commit"
printf '#!/bin/bash\necho staged\n' > 'space name.sh'
git add 'space name.sh'
printf '#!/bin/bash\necho unstaged\r\n' > 'space name.sh'
cp 'space name.sh' "$tmp/working-copy"
cat > "$tmp/bin/shellcheck" <<'STUB'
#!/usr/bin/env bash
[[ "$1" == -- && "$2" == 'space name.sh' && $# == 2 ]] || exit 1
grep -qx 'echo staged' "$2" || exit 1
if grep -q unstaged "$2"; then echo "Unexpected matching content" >&2; exit 1; fi
STUB
PATH="$tmp/bin:$PATH" bash "$ROOT/githooks/pre-commit"
cmp 'space name.sh' "$tmp/working-copy"
git show ':space name.sh' | grep -qx 'echo staged'
cat > "$tmp/bin/shellcheck" <<'STUB'
#!/usr/bin/env bash
exit 23
STUB
if PATH="$tmp/bin:$PATH" bash "$ROOT/githooks/pre-commit"; then
    echo 'Hook swallowed a lint failure' >&2; exit 1
fi
printf 'PASS: lint failure propagation, staged-only checks and unchanged working tree\n'
