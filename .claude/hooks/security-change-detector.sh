#!/usr/bin/env bash
# PostToolUse hook: 수정된 파일이 보안 관련인지 경로 패턴으로 판단
# 보안 관련 파일만 피드백, 나머지는 스킵
# exit 0 = 스킵, exit 2 = Claude에 피드백

set -euo pipefail

# stdin에서 hook context (JSON) 읽기
INPUT=$(cat)

# file_path 추출
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || true)

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# 보안 관련 경로/파일명 패턴
SECURITY_PATTERN='(auth|login|session|token|password|credential|permission|role|acl|oauth|jwt|crypto|encrypt|secret|apikey|guard|policy|middleware.*(auth|session)|sanitiz|validat.*(input|request))'

if echo "$FILE_PATH" | grep -qiE "$SECURITY_PATTERN"; then
  {
    echo "[보안 변경 감지] 보안 관련 파일 수정: $(basename "$FILE_PATH")"
    echo "인증, 권한, 입력 검증, 암호화 관련 변경사항을 점검하세요."
  } >&2
  exit 2
fi

exit 0
