#!/usr/bin/env bash
# PreToolUse(Write) hook: 비밀 파일 쓰기 차단
# exit 0 = 허용, exit 2 = 차단 (stderr가 Claude에 피드백)

set -euo pipefail

# stdin에서 JSON 입력 읽기
INPUT=$(cat)

# 파일 경로 추출 (jq 우선, grep fallback)
if command -v jq &>/dev/null; then
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")
else
  FILE_PATH=$(echo "$INPUT" | grep -o '"file_path":"[^"]*"' | head -1 | sed 's/"file_path":"//;s/"$//' 2>/dev/null || echo "")
fi

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# 파일명만 추출
FILENAME=$(basename "$FILE_PATH")

# 차단 패턴: 비밀/인증 정보 파일
SECRET_PATTERNS=(
  '^\.env$'
  '^\.env\.'
  '^credentials\.'
  '^secrets\.'
  '\.key$'
  '\.pem$'
  '\.p12$'
  '\.pfx$'
  '\.keystore$'
  '^id_rsa'
  '^id_ed25519'
  '^\.npmrc$'
  '^\.pypirc$'
  '^token\.json$'
  '^service[-_]account.*\.json$'
)

for pattern in "${SECRET_PATTERNS[@]}"; do
  if echo "$FILENAME" | grep -qiE "$pattern" 2>/dev/null; then
    echo "차단됨: 비밀 파일('$FILENAME')에 쓰기가 감지되었습니다. 비밀 정보가 포함된 파일은 직접 생성/수정할 수 없습니다." >&2
    exit 2
  fi
done

exit 0
