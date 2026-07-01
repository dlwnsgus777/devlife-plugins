---
name: project-history
description: |
  Jira 티켓 기반으로 프로젝트 작업 이력을 이력서용 마크다운 문서로 정리하는 스킬.
  "RB-623 이력 정리해줘", "이 티켓 이력서용으로 정리해줘", "작업 이력 문서화해줘", Jira URL + "이력서/정리/문서화" 등으로 트리거된다.
  "/project-history {티켓번호}" 형태로도 사용 가능.
  Jira 하위 이슈 전체 + 관련 git 브랜치 코드 diff까지 분석해서 기능 개요, 도메인 설계, 기술적 도전, 이력서 어필 포인트를 담은 문서를 생성한다.
---

# Project History: 이력서용 작업 이력 정리

## 목적

Jira 티켓 하나를 기준으로 실제 코드 변경 내역까지 분석해서, 이력서·포트폴리오에 바로 쓸 수 있는 수준의 기술 문서를 생성한다.

출력 문서는 항상 `templates/document.md` 구조를 따른다. 이 파일을 먼저 읽고 시작한다.

**핵심 원칙**: 추측이나 과장 없이 실제 Jira 티켓과 git 커밋·코드에서 확인된 사실만 작성한다.

---

## Step 1: 입력 파싱 및 저장 경로 확인

사용자 입력에서 티켓 키를 추출한다.

- URL 형태: `https://*.atlassian.net/browse/RB-623` → cloudId: `*.atlassian.net`, 티켓: `RB-623`
- 직접 입력: `RB-623` → cloudId는 현재 프로젝트의 git remote URL 또는 사용자에게 확인

저장 경로가 명시되지 않았으면 묻는다:
> "어디에 저장할까요? (기본: 현재 프로젝트의 `docs/` 폴더)"

---

## Step 2: Jira 데이터 수집 (병렬)

Jira MCP 도구를 사용하기 전에 ToolSearch로 스키마를 먼저 로드한다.

다음을 동시에 실행한다:

```
1. getJiraIssue(티켓키)
   - fields: summary, description, status, assignee, created, updated, subtasks, comment

2. searchJiraIssuesUsingJql("parent = {티켓키} ORDER BY created ASC")
   - fields: summary, description, status, issuetype, assignee
   - maxResults: 50
```

하위 이슈가 없으면 `issueLinks`로 연관 이슈도 확인한다.

---

## Step 3: Git 브랜치 탐색

메인 티켓 + 하위 이슈 번호를 모두 수집한 뒤, 관련 브랜치를 한 번에 탐색한다.

```bash
# 티켓 번호 목록으로 브랜치 검색
git branch -a | grep -E "({티켓번호1}|{티켓번호2}|...)"
```

각 브랜치별로 수집:
```bash
git log --oneline {브랜치} --not main 2>/dev/null | head -30
git log --stat {브랜치} --not main 2>/dev/null | head -80
```

---

## Step 4: 코드 분석

각 브랜치에서 다음 우선순위로 핵심 파일을 읽는다:

1. **Entity / Domain 객체** — 도메인 모델, VO 파악
2. **Service** — 비즈니스 로직, 정책 파악
3. **Controller / Executor** — API 엔드포인트 (URL, method, 요청/응답 구조)
4. **Repository** — 쿼리 방식 (@Query, QueryDSL, Native 등)

버그 수정 브랜치는 수정 전후 diff에 집중해 **원인과 해결 방식**을 파악한다.

파일이 많을 때는 신규 파일(A)과 크게 수정된 파일(M)을 우선한다.

---

## Step 5: 문서 생성

`templates/document.md`의 플레이스홀더를 채워 문서를 완성한다.

### 각 섹션 작성 기준

**기능 개요 (`FEATURE_OVERVIEW`)**
- 무슨 기능인지, 왜 만들었는지 2-3문장
- 외부 파트너 연동, 레거시 이관 등 배경이 있으면 포함

**티켓별 구현 내용 (`TICKET_DETAILS`)**
- 각 하위 티켓마다 `### {티켓키} — {제목}` 형식
- 실제 클래스명·API 엔드포인트 직접 인용
- 브랜치명 포함

**기술적 도전 포인트 (`TECHNICAL_CHALLENGES`)**
- 코드에서 확인된 비자명한 결정·버그 원인·해결 방식만
- "왜 이렇게 했는가"를 설명할 수 있는 것만 포함
- 번호 매긴 항목으로 정리

---

### 이력서 작성 포인트 작성 기준 (중요)

이 섹션이 이 문서의 핵심 출력물이다. 아래 네 항목을 빠짐없이 작성한다.

**한 줄 요약 (`ONE_LINE_SUMMARY`)**
경력 기술서 '주요 프로젝트'에 바로 쓸 수 있는 1문장.
기술적 챌린지 + 해결 방식 구조로 작성.
예: "Oracle 프로시저에 묻혀있던 정기 배송 비즈니스 규칙을 분석해 Java 도메인 계층으로 이관하고, 판매 유형·쿠폰 유형별 배송 정책을 역할별 도메인 객체로 명시화했습니다."

**주요 업무 bullet points (`RESUME_BULLETS`)**
경력 기술서 '담당 업무'에 붙여넣을 수 있는 3-5개 항목.
형식: `- {동사} {기술적 내용} ({구체적 임팩트 또는 방식})`
예:
```
- Oracle 프로시저 기반 정기 배송 로직을 Java 서비스로 이관 (SmartServicePolicy, BonusPackTransaction 등 역할별 도메인 객체 분리)
- Admin·ECP 두 채널에 걸친 정기 배송 그룹 관리 기능 end-to-end 단독 구현 (11개 티켓, 150개 이상 파일 변경)
- 제품 식별 키를 BrandUomLocalKey 3-tuple로 재설계해 중복 반환 버그 근본 해결
```
동사는 명사형으로 마무리 (이관, 구현, 수정, 설계, 개선 등).
실제 클래스명·수치를 가능하면 포함한다.

**사용 기술 (`TECH_STACK`)**
코드에서 실제 확인된 기술만 나열.
예: `Java 21, Spring Boot, JPA, QueryDSL, Oracle, MSSQL, Jira`

**면접 대비 포인트 (`INTERVIEW_POINTS`)**
이 프로젝트로 면접관이 물어볼 법한 질문과 답변 방향.
형식:
```
Q. {예상 질문}
A. {답변 방향 한두 문장}
```
2-3개 작성.

**주의할 점 (`CAUTIONS`)**
이 프로젝트를 언급할 때 역효과 날 수 있는 표현이나 맥락.
예: "버그 6개를 그냥 나열하면 품질 이슈처럼 보일 수 있으니 '복잡한 외부 파트너 데이터 구조와 연동하면서 엣지케이스를 정제했다'로 맥락화할 것"

---

## Step 6: 저장 및 보고

지정된 경로에 파일을 저장한다.

파일명 기본값: `{티켓키}-{제목을-kebab-case로}.md`

저장 후 한 줄 요약 보고:
> "`{경로}` 저장 완료. 하위 이슈 {N}개, 브랜치 {N}개 분석. 핵심 어필: {한 줄 요약 첫 문장}"
