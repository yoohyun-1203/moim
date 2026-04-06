#!/usr/bin/env bash
# Stop hook: 체크리스트 미완료 알림 + 회고 미완료 경고
# exit 0 = 알림 없음, exit 2 = Claude에 피드백 (소프트 블로킹)
# 세션당 1회만 알림 (중복 방지)

set -euo pipefail

FEEDBACK=0

# === 체크리스트 리마인더 ===
CONTEXT_DIR=".claude/context"
CURRENT_TASK_FILE="$CONTEXT_DIR/current-task.txt"

if [[ -f "$CURRENT_TASK_FILE" ]]; then
  TASK_ID=$(cat "$CURRENT_TASK_FILE" 2>/dev/null | tr -d '[:space:]')

  if [[ -n "$TASK_ID" ]]; then
    CHECKLIST="$CONTEXT_DIR/$TASK_ID/checklist.md"

    if [[ -f "$CHECKLIST" ]]; then
      # 세션당 중복 알림 방지: 락 파일로 이미 알렸는지 확인
      LOCK_DIR="${TMPDIR:-${TEMP:-/tmp}}"
      LOCK_FILE="$LOCK_DIR/checklist-reminder-${TASK_ID}.lock"

      SHOULD_REMIND=true
      if [[ -f "$LOCK_FILE" ]]; then
        if [[ "$(uname)" == "Darwin" ]]; then
          LOCK_AGE=$(( $(date +%s) - $(stat -f %m "$LOCK_FILE") ))
        else
          LOCK_AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE") ))
        fi
        if [[ "$LOCK_AGE" -lt 3600 ]]; then
          SHOULD_REMIND=false
        fi
      fi

      if [[ "$SHOULD_REMIND" == "true" ]]; then
        INCOMPLETE_COUNT=$(grep -c '^\- \[ \]' "$CHECKLIST" 2>/dev/null) || INCOMPLETE_COUNT=0

        if [[ "$INCOMPLETE_COUNT" -gt 0 ]]; then
          touch "$LOCK_FILE"

          ITEMS=$(grep '^\- \[ \]' "$CHECKLIST" 2>/dev/null | head -10 | sed 's/^- \[ \] /  · /')
          {
            echo "[체크리스트 리마인더] 작업 '$TASK_ID'에 미완료 항목 ${INCOMPLETE_COUNT}건:"
            echo "$ITEMS"
            if [[ "$INCOMPLETE_COUNT" -gt 10 ]]; then
              echo "  ... 외 $((INCOMPLETE_COUNT - 10))건"
            fi
            echo "파일: $CHECKLIST"
          } >&2
          FEEDBACK=1
        fi
      fi
    fi
  fi
fi

# === 회고 미완료 경고 (소프트 블로킹) ===
TODAY=$(date '+%Y-%m-%d')
REFLECTION_FILE=".claude/reflections/${TODAY}.md"

# 회고 리마인더도 세션당 1회만 (중복 방지)
LOCK_DIR="${TMPDIR:-${TEMP:-/tmp}}"
REFLECTION_LOCK="$LOCK_DIR/reflection-reminder-${TODAY}.lock"

if [[ ! -f "$REFLECTION_LOCK" ]] && [[ ! -f "$REFLECTION_FILE" ]]; then
  # 코드 변경이 있었는지 확인 (변경 없으면 회고 불필요)
  CHANGED_FILES=$(git diff --name-only 2>/dev/null | wc -l | tr -d '[:space:]')
  STAGED_FILES=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d '[:space:]')

  if [[ "$((CHANGED_FILES + STAGED_FILES))" -gt 0 ]] || [[ -f "$CURRENT_TASK_FILE" ]]; then
    touch "$REFLECTION_LOCK"
    {
      echo "[회고 리마인더] 오늘($TODAY) 회고가 아직 작성되지 않았습니다."
      echo "작업이 있었다면 회고를 작성해주세요. 파일: $REFLECTION_FILE"
      echo "회고 질문: 이 작업에서 뭘 배웠나? / 다음에 다르게 할 점은? / 예상과 달랐던 점은?"
    } >&2
    FEEDBACK=1
  fi
fi

if [[ "$FEEDBACK" -eq 1 ]]; then
  exit 2
fi

exit 0
