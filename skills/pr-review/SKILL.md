---
name: pr-review
description: >
  Review a Bitbucket pull request given a PR URL. Parses the URL, finds the
  local repository clone via ~/.claude/repo-dirs.md, fetches the diff with
  local git, and performs a structured code review across 4 dimensions:
  bugs/logic errors, architecture violations, convention compliance, and test
  quality. Each finding is tagged with P1–P5 priority per the team's PN rule.
  Trigger on ANY message that includes a Bitbucket PR URL
  (bitbucket.org/.../pull-requests/...) combined with review intent — including
  "PR 리뷰해줘", "코드리뷰해줘", "리뷰해줘", "봐줘", "확인해줘", "review this PR",
  "check this PR", or even just pasting a PR link with no other text. If the
  user provides a PR URL, assume they want a review unless stated otherwise.
---

# PR Code Review

Review a Bitbucket PR end-to-end: parse URL → find local repo → get diff → evaluate → report.

---

## PN 룰 (팀 코드리뷰 우선순위 기준)

모든 리뷰 코멘트는 아래 우선순위 태그를 앞에 붙인다:

| 태그 | 의미 | 대응 방식 |
|------|------|-----------|
| **[P1]** | 꼭 반영해주세요 | 중대한 오류 가능성 — 머지 전 필수 수정 |
| **[P2]** | 적극적으로 고려해주세요 | 수용하거나, 못하면 토론 권장 |
| **[P3]** | 웬만하면 반영해 주세요 | 수용하거나, 못하면 이유 설명 또는 JIRA 티켓으로 계획 명시 |
| **[P4]** | 반영해도 좋고 넘어가도 좋습니다 | 무시해도 무방, 고민해보는 정도면 충분 |
| **[P5]** | 사소한 의견 | 무시해도 됨 |

참고: `references/pn-rule.md`에 전체 룰 정의 및 케이스별 적용 기준 있음

---

## Step 1 — Parse the PR URL

Extract three components from the Bitbucket URL:
`https://bitbucket.org/{workspace}/{repo_slug}/pull-requests/{PR_ID}`

- `workspace` — Bitbucket organization/team
- `repo_slug` — repository name
- `PR_ID` — pull request number

## Step 2 — Find the Local Repository

Read `~/.claude/repo-dirs.md` and look up `repo_slug` in the table.

**If found:** use the path in the next steps.

**If not found (fallback):**
Most repos follow the convention `slug = directory name` under `/Users/finn/Desktop/develop/`.
Try: `/Users/finn/Desktop/develop/{repo_slug}` — check if it exists with `ls`.
If it's a git repo, use it and add a row to `repo-dirs.md`.

If still not found, ask the user for the local path and add it to `repo-dirs.md`.

## Step 3 — Get PR Metadata and Diff

### 3a. PR 메타데이터 파악 (source/destination 브랜치)

**Bitbucket API를 먼저 시도한다.** `~/.claude/settings.json`에 `BITBUCKET_API_TOKEN`과 `ATLASSIAN_EMAIL`이 있으면 API로 직접 조회한다. 실제 slug는 `ratel_pe/{repo_slug}` 형태다.

```bash
# settings.json에서 토큰 확인
cat ~/.claude/settings.json | grep -E "BITBUCKET_API_TOKEN|ATLASSIAN_EMAIL"

# Bitbucket API로 PR 메타데이터 조회
curl -s -u "{ATLASSIAN_EMAIL}:{BITBUCKET_API_TOKEN}" \
  "https://api.bitbucket.org/2.0/repositories/ratel_pe/{repo_slug}/pullrequests/{PR_ID}" | \
  python3 -c "
import sys, json
d = json.load(sys.stdin)
print('Source:', d['source']['branch']['name'])
print('Dest:  ', d['destination']['branch']['name'])
print('Title: ', d['title'])
print('State: ', d['state'])
"
```

API로 source/destination을 확인했으면 **3b로 바로 이동**한다.

**API 실패 시 fallback — git 로컬 정보로 파악:**

**Case A — 이미 머지된 PR:**
```bash
# 머지 커밋 찾기
git -C {LOCAL_PATH} log --all --oneline --merges | grep "pull request #{PR_ID}"
# → {MERGE_HASH} Merged in {source_branch} (pull request #{PR_ID})
#   메시지에서 source 브랜치명 추출

# 머지 커밋의 두 부모 확인
git -C {LOCAL_PATH} show {MERGE_HASH} --format="Merge: %P" -s
# → Merge: {PARENT1} {PARENT2}
# PARENT1 = destination HEAD, PARENT2 = source HEAD

# destination 브랜치 확인
git -C {LOCAL_PATH} branch -r --contains {MERGE_HASH} | grep -v "{source_branch}"
```

**Case B — 아직 머지 안 된 PR:**
```bash
git -C {LOCAL_PATH} fetch origin feature/{source_branch} feature/{destination_branch}
```

### 3b. diff 구성 — 반드시 세 점(`...`) 사용

> ⚠️ **절대 `..`(두 점)을 쓰지 않는다.** 두 점은 두 커밋의 직접 비교로, PR 페이지의 file change와 다른 결과를 낸다.
> PR 페이지의 diff = 공통 조상(merge base)부터 source까지의 변경 = `...`(세 점)

**Case A — 이미 머지된 PR:**
```bash
# PARENT1...PARENT2 (세 점) — 공통 조상 기준
git -C {LOCAL_PATH} diff --name-status {PARENT1}...{PARENT2}
git -C {LOCAL_PATH} diff -U5 {PARENT1}...{PARENT2}
git -C {LOCAL_PATH} log --oneline {PARENT1}..{PARENT2}
```

**Case B — 아직 머지 안 된 PR:**
```bash
# origin/{destination}...origin/{source} (세 점)
git -C {LOCAL_PATH} diff --name-status origin/{destination}...origin/{source}
git -C {LOCAL_PATH} diff -U5 origin/{destination}...origin/{source}
git -C {LOCAL_PATH} log --oneline origin/{destination}..origin/{source}
```

## Step 3c — Load Domain Context (optional)

변경된 파일이 속한 도메인과 관련된 문서가 있으면 리뷰 전에 읽어 도메인 규칙을 파악한다.

```bash
ls {LOCAL_PATH}/docs/domain/ 2>/dev/null
```

`docs/domain/` 폴더가 존재하면:
1. 변경된 파일의 패키지/도메인명(예: `fittingcommission`, `payment`, `coupon`)을 확인한다.
2. 해당 도메인 문서를 읽는다 (예: `docs/domain/fittingcommission.md`)
3. 문서에 정의된 **도메인 규칙, 제약 조건, 핵심 흐름**을 파악한 뒤 리뷰에 반영한다.

도메인 문서를 리뷰에 활용하는 방식:
- 도메인 규칙을 위반하는 코드 → P1~P2로 구체적 규칙 이름과 함께 지적
- 도메인 문서와 구현이 불일치하는 경우 → "의도 확인 필요" 섹션에 질문으로 작성
- 도메인 문서가 없는 변경 파일 → 도메인 문서 부재를 무시하고 코드만으로 리뷰

## Step 3d — 테스트 커버리지 확인

동작이 변경된 코드가 있으면, **이 PR diff 안에** 해당 변경을 검증하는 테스트가 존재하는지 확인한다.

```bash
# acuvue-application 모듈의 테스트 변경 여부 확인
git -C {LOCAL_PATH} diff --name-status origin/{destination}...origin/{source} -- acuvue-application/src/test/

# 변경된 비즈니스 로직 클래스명으로 기존 테스트 파일 존재 여부 확인
find {LOCAL_PATH}/acuvue-application/src/test -name "{ClassName}Test.java" 2>/dev/null
```

**판단 기준:**

| 상황 | 처리 |
|------|------|
| PR diff에 테스트 변경이 있고, 행동 변경을 커버한다 | 테스트 섹션에 "커버됨" 명시 |
| PR diff에 테스트 변경이 없으나 기존 테스트가 이미 커버 | 기존 테스트 파일 경로를 읽어 실제 커버 여부 확인 후 명시 |
| PR diff에 테스트가 없고 기존 테스트도 없거나 행동 변경을 커버 못 함 | **[P2]** 로 지적 |
| 순수 리팩토링(동작 변경 없음)이고 테스트 없음 | 지적 생략 가능 |

> ⚠️ "동작 변경"이란: 메서드 반환값·예외 조건·데이터 소스 교체 등 외부에서 관찰 가능한 행동이 달라지는 경우다. 단순 변수명 변경, import 정리, 포맷 수정은 해당하지 않는다.

## Step 4 — Code Review

4차원 평가 기준: `references/review-checklist.md` 참고
PN 룰 전체 정의: `references/pn-rule.md` 참고

### 리뷰 코멘트 작성 5원칙

리뷰를 쓰기 전에 아래 원칙을 따른다. 이 원칙은 PN 룰과 함께 적용된다.

---

**원칙 1 — 의도를 먼저 파악한다**
단정 전에 "왜 이렇게 짰나요?" 먼저 묻는다. 확장성·성능·도메인 이유가 있을 수 있다.
의도 불명확 → 질문 형식. 의도 확인 후 문제 맞으면 → 이유 설명하며 피드백.

**원칙 2 — 이유와 근거를 충분히 설명한다**
"바꾸세요"가 아닌 왜 개선이 필요한지 맥락을 함께 쓴다.

**원칙 3 — 답이 아닌 키워드와 방향을 제시한다**
완성 코드 제시 금지. 키워드·힌트 수준으로 스스로 찾게 유도한다.

**원칙 4 — 개발자 성향을 리뷰하지 않는다**
팀 컨벤션 합의 없는 순수 스타일 차이는 P5 이하 또는 생략.

**원칙 5 — 지적할 것이 없으면 칭찬한다**
추상적 칭찬 금지. 코드 라인을 인용해 왜 좋은지 구체적으로 쓴다.

예시가 필요하면 `references/kakao-review-principles.md` 참고.

---

### 코멘트 작성 체크리스트

각 발견 항목을 작성하기 전에 확인:
1. **의도가 명확한가?** — 불명확하면 질문 형식으로
2. **이유를 설명했는가?** — 왜 문제인지 맥락 포함
3. **키워드/방향만 줬는가?** — 완성 코드 제시 금지
4. **스타일 강요가 아닌가?** — 합의된 컨벤션 기준인지 확인
5. **PN 태그가 정확한가?** — P1(필수) ~ P5(사소) 중 선택
6. **실제 코드 스니펫을 인용했는가?** — diff에서 해당 라인 그대로
7. **삭제/대체된 코드가 있으면 기존 동작을 먼저 읽었는가?** — 변경이 버그인지 의도적 호환성 유지인지는 대체 대상 코드를 읽어야 판단 가능. 단정 전에 반드시 확인.

## Step 5 — Save Report

**Report path:** `{LOCAL_PATH}/docs/reviews/pr-{PR_ID}-review.md`

`docs/reviews/` 디렉토리가 없으면 생성한다.

리포트 작성 시 `references/report-template.md`를 읽어 스키마를 그대로 따른다.

저장 후 사용자에게 아래 순서로 인라인 출력한다.

### 5a. 리뷰 사항 목록 테이블

리포트에서 발견된 모든 리뷰 항목(코드리뷰 + 의도 확인 필요)을 하나의 테이블로 정리한다.

| 우선순위 | 파일 | 요약 | 카테고리 |
|----------|------|------|----------|
| P1 | `파일명:라인` | 한 줄 요약 | 버그/아키텍처/컨벤션/테스트/설계 중 택1 |
| P2 | `파일명:라인` | 한 줄 요약 | … |
| 의도확인 | `파일명:라인` | 질문 요약 | — |

**정렬 기준:** P1 → P2 → P3 → P4 → P5 → 의도확인 순서로 출력한다.
**카테고리 기준:** 버그·로직 오류 → `버그`, 레이어 의존성·패턴 위반 → `아키텍처`, 네이밍·포맷 → `컨벤션`, 테스트 누락·품질 → `테스트`, 책임 분리·추상화 → `설계`

### 5b. 점수 요약 테이블

리포트의 "점수 요약" 섹션을 그대로 인라인으로 출력한다.

### 5c. 저장 경로 안내

`> 리포트 저장됨: {LOCAL_PATH}/docs/reviews/pr-{PR_ID}-review.md` 형식으로 출력한다.
