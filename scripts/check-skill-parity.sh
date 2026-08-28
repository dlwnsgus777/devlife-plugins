#!/usr/bin/env bash
# skills/ (Claude) 와 codex/skills/ (Codex) 의 동기화 상태를 검사한다.
#
#   ./scripts/check-skill-parity.sh            전체 검사
#   ./scripts/check-skill-parity.sh tdd-team   특정 스킬만
#
# exit 0 = 통과, exit 1 = 동기화 깨짐
# bash 3.2 (macOS 기본) 에서 동작한다 — mapfile/연관배열 사용 금지.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

FAIL=0
note()  { printf '  \033[2m%s\033[0m\n' "$*"; }
pass()  { printf '  ✅ %s\n' "$*"; }
bad()   { printf '  ❌ %s\n' "$*"; FAIL=1; }
warn()  { printf '  ⚠️  %s\n' "$*"; }
head_() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# 플랫폼 어휘를 같은 토큰으로 접어 비교 가능하게 만든다.
plat_fold() {
  sed -E \
    -e 's/Agent\(\{[^}]*\}\)/AGENT/g' \
    -e 's/[Ss]ub-[Aa]gents?/AGENT/g' \
    -e 's/Agents?/AGENT/g' \
    -e 's/(AGENTS|CLAUDE)\.md/INSTRUCTIONS/g' \
    -e 's/apply_patch|`Edit`\/`Write`/EDIT/g' \
    -e 's/Codex Compatibility Rules/Execution Rules/g' \
    -e 's/AGENT (Tool )?Call Pattern|AGENT Pattern/AGENT Pattern/g' \
    -e 's/Fix AGENT Dispatch/Fix Dispatch/g' \
    -e 's/Codex ?//g'
}

# 접은 뒤에도 남는, 의도된 플랫폼 전용 앵커.
PLATFORM_RE='tool_search|subagent_type|general-purpose|model|haiku|opus|inherit|omit|tier|EDIT|AGENT|PHASE|`Read`|`Write`|`Edit`|INSTRUCTIONS'

# SKILL.md 크기 편차 허용치(%). 넘으면 한쪽에만 있는 블록을 의심한다.
SIZE_TOLERANCE=10

# skills/ 에 있으면 안 되는 Codex 전용 문구 (CLAUDE.md 플랫폼 분리 원칙).
CODEX_ONLY_RE='tool_search|apply_patch|AGENTS\.md'
# Codex/터미널 자체를 다루는 스킬은 오염 검사 예외.
CODEX_TOPIC_SKILLS=" devlife-codex devlife-team-starter cmux "

# 검사에서 통째로 제외할 스킬 (공백으로 감싸 나열).
# cmux: skills/ 는 reference 3개(v0.3.0), codex/ 는 7개(v0.2.0) 로 갈라져 있고
#       어느 쪽이 맞는지 미결이라 제외. 결론 나면 여기서 빼면 된다.
SKIP_SKILLS=" cmux "

TARGET="${1:-}"
CLAUDE_SKILLS=$(ls skills 2>/dev/null)
CODEX_SKILLS=$(ls codex/skills 2>/dev/null)

head_ "1. 스킬 목록"
BOTH=""
for s in $CLAUDE_SKILLS; do
  case "$SKIP_SKILLS" in
    *" $s "*) note "검사 제외: $s"; continue ;;
  esac
  if echo "$CODEX_SKILLS" | grep -qx "$s"; then
    BOTH="$BOTH $s"
  else
    note "codex 사본 없음 (의도된 것일 수 있음): $s"
  fi
done
for s in $CODEX_SKILLS; do
  case "$SKIP_SKILLS" in *" $s "*) continue ;; esac
  echo "$CLAUDE_SKILLS" | grep -qx "$s" || bad "codex 에만 존재: $s"
done
pass "양쪽 모두 존재: $(echo $BOTH | wc -w | tr -d ' ')개 — 아래 검사 대상"

for skill in $BOTH; do
  [ -n "$TARGET" ] && [ "$TARGET" != "$skill" ] && continue
  head_ "▸ $skill"

  # 2. SKILL.md 외 부속 파일은 바이트 단위로 동일해야 한다
  a_files=$(cd "skills/$skill" && find . -type f ! -name SKILL.md ! -name '.DS_Store' | sort)
  b_files=$(cd "codex/skills/$skill" && find . -type f ! -name SKILL.md ! -name '.DS_Store' | sort)
  if [ "$a_files" != "$b_files" ]; then
    bad "부속 파일 목록 불일치"
    diff <(echo "$a_files") <(echo "$b_files") | sed 's/^/       /'
  elif [ -z "$a_files" ]; then
    note "부속 파일 없음"
  else
    mismatch=0
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      cmp -s "skills/$skill/$f" "codex/skills/$skill/$f" || { bad "내용 다름: $f"; mismatch=1; }
    done <<< "$a_files"
    [ $mismatch = 0 ] && pass "부속 파일 $(echo "$a_files" | grep -c .)개 바이트 동일"
  fi

  # 3. SKILL.md 구조 비교 — 헤딩 / 부피 / 앵커
  A="skills/$skill/SKILL.md"; B="codex/skills/$skill/SKILL.md"
  if [ ! -f "$A" ] || [ ! -f "$B" ]; then
    bad "SKILL.md 누락"
  else
    # 3a. 섹션 헤딩 (플랫폼 리네임 접은 뒤 완전 일치해야 함)
    if diff -q <(grep '^#\{1,4\} ' "$A" | plat_fold) <(grep '^#\{1,4\} ' "$B" | plat_fold) >/dev/null; then
      pass "섹션 헤딩 일치"
    else
      bad "섹션 헤딩 불일치"
      diff <(grep '^#\{1,4\} ' "$A" | plat_fold) <(grep '^#\{1,4\} ' "$B" | plat_fold) | sed 's/^/       │ /'
    fi

    # 3b. 부피 편차 — 한쪽에만 남은 블록의 가장 값싼 신호
    sa=$(wc -c < "$A" | tr -d ' '); sb=$(wc -c < "$B" | tr -d ' ')
    d=$(( sa > sb ? sa - sb : sb - sa )); pct=$(( d * 100 / (sa > sb ? sa : sb) ))
    if [ "$pct" -gt "$SIZE_TOLERANCE" ]; then
      bad "크기 편차 ${pct}% (claude ${sa} / codex ${sb}) — 한쪽에만 있는 블록 의심"
    else
      pass "크기 편차 ${pct}% (허용 ${SIZE_TOLERANCE}%)"
    fi

    # 3c. 앵커(볼드 문구·백틱 식별자) 집합 — 문장 리워딩엔 둔감하고 내용 누락엔 민감
    anchors() { grep -oE '\*\*[^ *][^*]{1,58}[^ *]\*\*|`[^ `][^`]{1,58}`' "$1" | plat_fold \
                | grep -Ev "$PLATFORM_RE" | sort -u; }
    only=$(diff <(anchors "$A") <(anchors "$B") | grep '^[<>]' || true)
    n=$(echo "$only" | grep -c . || true)
    if [ -n "$only" ] && [ "$n" -gt 0 ]; then
      warn "한쪽에만 있는 앵커 ${n}개 — 사람이 확인 (FAIL 아님)"
      echo "$only" | sed 's/^</       │ claude만: /; s/^>/       │ codex만 : /' | head -10
      [ "$n" -gt 10 ] && note "      … 이하 $((n-10))개 생략"
    else
      pass "앵커 집합 일치"
    fi
  fi

  # 4. skills/ 에 Codex 전용 문구가 새어 들어갔는지
  case "$CODEX_TOPIC_SKILLS" in
    *" $skill "*) note "Codex 관련 스킬 — 오염 검사 건너뜀" ;;
    *)
      leak=$(grep -rnE "$CODEX_ONLY_RE" "skills/$skill" 2>/dev/null || true)
      if [ -n "$leak" ]; then
        bad "skills/ 에 Codex 전용 문구"
        echo "$leak" | head -5 | sed 's/^/       │ /'
      else
        pass "플랫폼 오염 없음"
      fi ;;
  esac
done

# 5. 문서·README 연결
head_ "5. 문서 연결"
missing=0
for s in $CLAUDE_SKILLS; do
  [ -f "docs/$s.md" ] || { warn "docs/$s.md 없음"; missing=1; }
  grep -q "\`$s\`" README.md 2>/dev/null || { warn "README 테이블에 \`$s\` 없음"; missing=1; }
done
[ $missing = 0 ] && pass "모든 스킬에 docs/ 와 README 항목 존재"

head_ "결과"
if [ $FAIL = 0 ]; then printf '  ✅ 동기화 정상\n\n'; else printf '  ❌ 동기화 깨짐 — 위 항목 확인\n\n'; fi
exit $FAIL
