#!/usr/bin/env bash
# verify.sh — persona-read-loop の機械ゲート（pre-commit hook と手元の完全検査の単一入口）。
#   --staged  = commit 境界の高速検査（staged の Python に ruff format / lint、shell に shellcheck）
#   引数なし  = repo 全体（上に加えて ty の型検査と pytest）
# exit: 0 PASS / 1 FAIL / 2 検査できない（ツール不在。眠っているゲートは stdout に名指しする）
# ツールの選定理由と再調査の条件は .claude/verify.md。
set -uo pipefail

if [[ -n "${VERIFY_REPO_ROOT:-}" ]]; then
  ROOT="$VERIFY_REPO_ROOT"
else
  ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P) || exit 2
fi
cd "$ROOT" || exit 2

STAGED=0
[[ "${1:-}" == "--staged" ]] && STAGED=1
SKILL=skills/persona-read-loop

fail=0 asleep=0
check() { # check <label> <command...>
  local label=$1 out
  shift
  if ! out=$("$@" 2>&1); then
    printf '[%s] FAIL\n%s\n' "$label" "$out"
    fail=1
  fi
}
sleeping() {
  printf '[verify] %s 不在 — %s をスキップ\n' "$1" "$2"
  asleep=1
}

files() { # files <glob-pattern> — staged か tracked のうち、存在するもの
  if ((STAGED)); then
    git diff --cached --name-only --diff-filter=ACMR
  else
    git ls-files
  fi | while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    # shellcheck disable=SC2254
    case "$f" in $1) printf '%s\n' "$f" ;; esac
  done
}

py=() sh=()
while IFS= read -r f; do py+=("$f"); done < <(files '*.py')
while IFS= read -r f; do sh+=("$f"); done < <(files '*.sh')

# 版は ~/.claude の verify.sh と揃える（pin。上げるのは手で）
if command -v uvx >/dev/null 2>&1; then
  RUFF=(uvx 'ruff==0.16.5')
  TY=(uvx 'ty==0.0.75')
else
  RUFF=() TY=()
fi

# --- Python: format と lint（ruff は各ファイルに最も近い pyproject.toml を読む）------------------
if ((${#py[@]})); then
  if ((${#RUFF[@]})); then
    check format "${RUFF[@]}" format --check -- "${py[@]}"
    check lint "${RUFF[@]}" check --no-cache -- "${py[@]}"
  else
    sleeping uvx "ruff の format / lint"
  fi
fi

# --- shell: shellcheck（最も厳しい style 閾値。SC1091 は動的 source の偽陽性）---
if ((${#sh[@]})); then
  if command -v shellcheck >/dev/null 2>&1; then
    check shellcheck shellcheck --norc -S style -e SC1091 -- "${sh[@]}"
  else
    sleeping shellcheck "shell lint"
  fi
fi

if ((!STAGED)); then
  if ((${#TY[@]})); then
    check types "${TY[@]}" check "$SKILL/scripts"
  else
    sleeping uvx "ty の型検査"
  fi
  if command -v uv >/dev/null 2>&1; then
    check pytest uv run --quiet --project "$SKILL" --directory "$SKILL" pytest -q -p no:cacheprovider
  else
    sleeping uv "pytest"
  fi
fi

((fail)) && exit 1
((asleep)) && exit 2
exit 0
