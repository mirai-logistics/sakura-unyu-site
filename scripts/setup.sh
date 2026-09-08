#!/usr/bin/env bash
# このリポで作業する準備。何度実行しても同じ結果になる。
#   1) git と gitleaks があるか
#   2) git hooks (.githooks) の登録
#   3) フックが実行できる状態か (⚠ ここが静かに壊れる。下の注記)
#
# ⚠ clone しただけではフックは効かない。これを 1 回打つまで、
#    main への直接 push も秘密の混入も止まらない。
#
# ⚠ フックの実行権限は「git の index に記録された 100755」で決まる。
#    手元で chmod しても、index が 100644 のままだと clone や checkout のたびに
#    644 へ戻り、フックが効かなくなる。しかも git は hint を 1 行出すだけで
#    push を通してしまう (2026-09-08 に実測)。だから index のモードまで見る。
#
# 入れ方が分からないときは dev-rules の setup/mac.md か setup/windows.md。
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
fail=0

command -v git >/dev/null 2>&1 || { echo "✗ git が無い"; fail=1; }

if ! command -v gitleaks >/dev/null 2>&1; then
  echo "✗ gitleaks が無い(秘密の混入検査に必須。skip 設定は足さない)"
  echo "    Mac    : brew install gitleaks"
  echo "    Windows: dev-rules の setup/windows.md を読む"
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  echo
  echo "✗ 足りないものがあります。上の案内に従って入れてから、もう一度実行してください。"
  exit 1
fi

git config core.hooksPath .githooks
chmod +x .githooks/* scripts/*.sh 2>/dev/null || true

# index のモードが 644 のままだと、次の checkout でフックが黙って効かなくなる。
notexec="$(git ls-files -s .githooks/ | awk '$1 != "100755" { print $4 }')"
if [ -n "$notexec" ]; then
  echo
  echo "⚠ 次のフックが、git の記録では実行できない状態です(100644)。"
  echo "$notexec" | sed 's/^/    /'
  echo "  いまは手元だけ直しましたが、clone し直すと戻ります。直して commit してください:"
  echo "    git update-index --chmod=+x .githooks/*"
  echo "  ⚠ これは「フックが静かに効かなくなる」唯一の壊れ方です。放置しないでください。"
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "OK: git hooks(.githooks/)を登録しました。"
echo "確認: git config --get core.hooksPath  →  .githooks と出れば効いています。"
