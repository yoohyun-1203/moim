#!/usr/bin/env bash
# PreToolUse(Bash) hook: 위험한 명령어 차단
# exit 0 = 허용, exit 2 = 차단 (stderr가 Claude에 피드백)

set -euo pipefail

# stdin에서 JSON 입력 읽기
INPUT=$(cat)

# 명령어 추출 (jq 우선, grep fallback)
if command -v jq &>/dev/null; then
  COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")
else
  COMMAND=$(echo "$INPUT" | grep -o '"command":"[^"]*"' | head -1 | sed 's/"command":"//;s/"$//' 2>/dev/null || echo "")
fi

if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# 위험 명령 감지 패턴 (정규식, grep -E 호환)
DANGEROUS_EXACT=(
  "rm -rf /$"
  "rm -rf /\*"
  "rm -rf ~"
  "sudo rm -rf"
  "git push --force main"
  "git push --force master"
  "git push -f origin main"
  "git push -f origin master"
  "git push --force-with-lease origin main"
  "git push --force-with-lease origin master"
  "git reset --hard$"
  "git clean -fd"
  "git checkout -- \."
  "DROP TABLE"
  "DROP DATABASE"
  "TRUNCATE TABLE"
  "> /dev/sda"
  "mkfs\."
  ":\(\)\{ :\|:& \};:"
  "chmod 777 /"
  "chmod -R 777 /"
  "git add -A"
  "git add --all"
  "git add \.[[:space:]]*$"
)

for pattern in "${DANGEROUS_EXACT[@]}"; do
  if echo "$COMMAND" | grep -qiE "$pattern" 2>/dev/null; then
    echo "차단됨: '$pattern' 패턴이 감지되었습니다. 이 명령은 실행할 수 없습니다." >&2
    exit 2
  fi
done

exit 0
