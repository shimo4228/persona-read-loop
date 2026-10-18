# verify.sh の選定記録

入口は `.claude/verify.sh`（`--staged` = staged の Python に ruff format / lint、shell に shellcheck /
引数なし = 全体に加えて ty と pytest）。選定は `~/.claude/.claude/verify.md`（harness の棚卸し）と同じツールと
版を使う。skill の正本は harness にあり、この repo には同期で入るので、harness と同じゲートで揃える。

## format
tool: ruff format（`uvx ruff==0.16.5`、設定は `skills/persona-read-loop/pyproject.toml`）
selected: 2026-10-18
reason: harness と同じ版。shell の formatter は harness でも採っていない
re-research triggers: harness の verify.md が ruff を替える / 12 か月経過

## lint
tool: ruff check（同上。select は harness root と同じ E4/E7/E9/F/I/B/UP/C901/ANN、test は ANN を外す）
tool: shellcheck 0.11.0（`--norc -S style -e SC1091`）
selected: 2026-10-18
reason: 最も厳しい style 閾値。SC1091 は動的 source の偽陽性
re-research triggers: 12 か月経過 / 新版が出る

## type check
tool: ty（`uvx ty==0.0.75`、`skills/persona-read-loop/scripts`）
selected: 2026-10-18
reason: harness と同じ版。bash に型は無い
re-research triggers: ty が 1.0 に達する / harness が型検査器を替える

## security
tool: none（第三者の入力を実行しない。secret scan は commit 時の harness hook と公開前の verify-public-detail.sh が持つ）

## dependency
tool: none（実行時の依存は標準ライブラリだけ。pytest は dev）

## test
tool: pytest（`uv run --project skills/persona-read-loop`）
selected: 2026-10-18
re-research triggers: 12 か月経過

## 予算
C901 = 15（pyproject.toml。harness と同じ。上げずに刈る — 変更はここに日付と理由を書く）
measured 2026-10-18: drift_count.py の関数は最大でも 15 未満（ruff の C901 が無発火）

## 発火の確認（2026-10-18）
未使用 import と型注釈の無い引数（lint）・崩れた整形（format）・未クォート変数（shellcheck）・戻り値の型の
食い違い（ty）・`assert False` の test（pytest）を注入し、すべて FAIL を確かめて probe を消した

## CI
未設定。GitHub の repo を作る前（push は著者の GO 待ち）なので、作ったときに `.claude/verify.sh` を引数なしで
呼ぶ job を足す
