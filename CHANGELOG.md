# Changelog

## [Unreleased]

---

## 2026-09-11

### devlife-tdd

| Skill | Version | Change |
|-------|---------|--------|
| `tdd-team` | `2.0.0` | 에이전트 통신을 프롬프트 인라인 데이터에서 `.tdd-team/` md 파일 경유로 전환 — 컨텍스트·태스크·단계별 결과·리뷰를 파일로 주고받고 반환값은 `TDD_STATUS` 봉투(`phase`/`status`/`result_file`/`tests`/`verdict`/`findings`/`note`)만. 세션 재개 지원(태스크 수 무관하게 `session.md` 기록, fix·서킷 카운터 포함), 사이클 중 `context.md`·`task.md` 직접 수정 시 다음 단계부터 반영, 사이클별 산출물을 디버깅 기록으로 보존(`.git/info/exclude`로 추적 제외). 오케스트레이터의 반환 계약과 산출물 경로가 바뀌어 진행 중이던 기존 세션(구 경로 `docs/tdd/session-{feature}.md`)과는 호환되지 않음 아울러 태스크 분해 시 「이 태스크를 통과시키는 생산 코드 변경」을 먼저 답하게 해 Red가 될 수 없는 사이클을 목록 제시 전에 제거하고(기존 `ALREADY_PASSES` 신호는 백스톱으로 재규정), 테스트 실행 출력은 전체 콘솔 로그 대신 결과만 읽도록 제약하며, RED는 `TEST_COMPILE_CMD`로 컴파일을 먼저 통과시킨 뒤 테스트를 1회 실행하고 `ALREADY_PASSES` 판정을 기존 생산 코드를 겨냥한 테스트로 한정. 피드백 단위를 사이클로 고정 — 리뷰어 승인으로 사이클이 완료된 시점에만 1회 요청하고, 단계마다 피드백을 요구하는 프로젝트 지시도 사이클 단위로 이행(그 경우 자동 진행 모드는 제안하지 않음). (breaking) |

---

## 2026-08-31

### devlife-planning

| Skill | Version | Change |
|-------|---------|--------|
| `plan-creator` | `1.7.0` | 섹션 6에 `코드 스니핏` 슬롯을 템플릿에 추가. 기존에는 SKILL.md 산문에만 있어 누락되기 쉬웠음. 클래스 선언·필드에 더해 **메서드 본문까지 작성** — 호출 순서, 불변성 가드 절(`INV-xxx` 주석), 예외, 반환 형태가 드러나야 함. 로깅·트랜잭션 설정 등 부수 코드는 생략. 자체 검증 4번을 파일 테이블·스니핏·섹션 8 구현 항목 3자 대조로 확장하고, 스니핏 위치를 섹션 8로 잘못 지칭하던 검증 문구를 정정 |

---

## 2026-08-28

### devlife-tdd

| Skill | Version | Change |
|-------|---------|--------|
| `tdd-team` | `1.9.0` | 무한 루프 가능 지점 4곳에 예산 도입 — `NEEDS_FIX` 수정 2라운드, `BLOCKED` 시 컨텍스트 축소 재시도 1회, 결과 블록 누락 시 재디스패치 1회, GREEN 통과 실패 2회. 소진 시 한 번 더 시도하지 않고 사용자에게 판단을 넘김. 3사이클 연속 `NEEDS_FIX`면 서킷 브레이커로 사이클을 멈추고 불변성·태스크 분해를 재확인(반복 지적은 코드가 아니라 상류 문제인 경우가 대부분). 태스크 분해에 커버리지 하한 추가 — 불변성마다 어기는 케이스·바로 옆 지키는 케이스·규칙이 직접 언급하는 상태까지 **경계**를 짚고 클래스당 해피패스 1개(상한이 아니라 하한). TDD에서는 테스트 없는 엣지 케이스가 곧 미구현 동작이므로 테스트 수는 줄이지 않고, 비용은 배칭 규칙으로 사이클 수에서만 통제. Cycle/Final Reviewer도 한쪽만 검증된 불변성을 `PARTIAL`로 지적하도록 확장. 계획 문서의 `[REGRESSION]` 항목은 사이클이 아니라 Final Review 대상으로 처리. 피드백 주기는 1번 사이클만 무조건 게이트한 뒤 이후 진행 방식을 한 번만 질의. 태스크 4개 이상이면 세션 원장(`docs/tdd/session-*.md`)을 남겨 중단·압축 후 준비 단계 재실행을 방지. Cycle Reviewer에 탐색 금지(grep·glob 포함) 명시, Final Reviewer는 불변성↔테스트 양방향 대조로 `ORPHAN` 판정 추가. 기존 산문 압축으로 파일 순증 최소화 |

### devlife-planning

| Skill | Version | Change |
|-------|---------|--------|
| `plan-creator` | `1.5.0` | Step 0 신설 — Brownfield/Greenfield 구분과 깊이 3단계(Minimal/Standard/Comprehensive) 판정 후 결과를 명시해 확인. 깊이 판정이 Step 1 탐색까지 실제로 이어지도록 Explore 요청 카테고리를 깊이별 표로 분기(Minimal은 대상 파일+직접 호출부 3개 카테고리, Standard/Comprehensive는 7개)하고, 카테고리당 상위 8개 상한과 `+N more` 요약을 강제. 카테고리 7은 도메인 테스트 인벤토리가 아니라 요구사항과 겹치는 동작을 검증하는 테스트로 한정하고, 스펙이 불변성을 확정한 경우 카테고리 6은 생략. 버그 수정에도 7항목 전수 탐색과 8개 섹션 전체를 돌리던 고정 비용을 제거. 질문 수를 깊이별 목표(2~4/5~8/8~12)로 전환하고, 답변 수집 후 모순 검사(범위·리스크·기술·일정) 및 회피성 답변 재질의 규칙 추가. 불변성에 고정 ID(`INV-001`)와 출처 태그(`[문서]`/`[사용자확인]`/`[코드추론]`) 부여 — 섹션 7이 ID를 참조하고 tdd-team이 그대로 이어받아 커버리지 대조가 판단이 아닌 조회가 됨. 자체 검증에 불변성 커버리지 항목을 더해 6개로 늘리고, 결과를 조용히 고치는 대신 보고하며 미해결 항목이 있으면 핸드오프 차단 |

---

## 2026-08-11

### devlife-tdd

| Skill | Version | Change |
|-------|---------|--------|
| `tdd-team` | `1.8.0` | REFACTOR 체크 조건에 클린 코드 냄새 3종 추가 — 함수가 한 가지 일만 하는지, 다른 클래스의 책임을 침범하는지(Feature Envy), 고수준/저수준 로직을 섞지 않고 한 단계씩만 추상화를 내려가는지. 기존 "10줄 초과" 규칙만으로는 잡지 못하던 케이스(짧지만 여러 책임을 겸하거나, 다른 객체의 데이터를 과도하게 다루는 메서드)를 보완. 글로벌 CLAUDE.md에 먼저 추가한 동일 체크리스트를 tdd-team의 REFACTOR 단계에도 명시적으로 박아 넣어, 서브에이전트가 전역 지침 상속 여부와 무관하게 항상 적용받도록 함. `references/refactor-agent.md`(skills/codex) 동기화 |

---

## 2026-07-29

### devlife-tdd

| Skill | Version | Change |
|-------|---------|--------|
| `tdd-team` | `1.6.0` | FIX 에이전트 배선 — SKILL.md가 3곳(사이클 `NEEDS_FIX`, Final Review 테스트 실패, 최종 `NEEDS_FIX`)에서 fix 에이전트를 호출하는데 프롬프트 파일 목록에도, dispatch 지시에도 `references/fix-agent.md`가 없어 fix 단계만 프롬프트 없이 실행되던 공백을 메움. 글로벌 스킬에만 존재하던 `fix-agent.md`를 `skills/`·`codex/skills/`로 편입하고, dispatch 블록은 `Fix Agent Dispatch` 섹션 1곳에만 두고 나머지 3곳은 참조하도록 배선(중복 서술 방지). 반환된 `FIX_RESULT`의 테스트 결과를 리뷰어 재실행 시 넘겨 같은 테스트 재실행을 막는 규칙도 명시 — 기존 "리뷰어는 보고된 결과를 신뢰" 원칙의 fix 경로 누락분. `SKILL.md`·`references/fix-agent.md`(skills/codex/global)·docs 동기화 |

## 2026-07-28

### devlife-planning

| Skill | Version | Change |
|-------|---------|--------|
| `plan-creator` | `1.4.0` | 도메인 변화 지점 추상화 제안 추가 — Step 1에 variation point 스캔(enum/타입/채널 분기, 하드코딩된 정책값, 한 단계만 다른 중복 메서드)과 억지 추상화를 막는 **two-case rule**(케이스 2개 이상 또는 이번 요구사항이 두 번째일 때만 제안, 1개면 금지, 없으면 `해당 없음`), Step 2에 "그 축이 실제로 늘어나는지" 질문, Step 3.5에 근거 없는 항목 삭제 체크. 템플릿 섹션 0을 `0-1. Tidy First` + `0-2. 추상화 제안`(변화 지점/도메인 근거/제안 추상화/적용 여부)으로 분리 — 설계 결정이므로 Step 4 승인 전까지 적용 여부 보류, 반려 시 삭제, 승인 시 기존 케이스로 먼저 추출(`refactor`) 후 새 케이스 구현(`feat`). 판정 기준은 Step 1에만 두고 나머지 단계는 참조만 해 중복 서술 제거, Step 3.5 문구를 영어로 통일.<br><br>함께 진행한 군더더기 정리 — 기본 동작이라 지시가 필요 없는 항목 제거(파일명 지정 시 그대로 사용, "확인됨 → 다음 단계", 디렉토리 자동 생성, 일반 리팩터링 냄새 열거, 명확화 질문의 자명한 3개 사유), 중복 지시 축소(추측 금지 3→2회, 답변 대기 2→1회, `[NEW]`/`[REGRESSION]` 4→1회, "해당 없는 섹션 생략" 2→1회, 구현 승인 게이트 2→1회), frontmatter description의 트리거 3중 열거를 catch-all 규칙으로 통합(상시 로드되는 부분), `Chain` 주석을 README 워크플로우(`spec-creator` 포함)와 일치시킴. 전체 170줄 1683단어 → 161줄 1761단어. `SKILL.md`·`assets/plan-template.md`(skills/codex)·docs 동기화 |

### devlife-tdd

| Skill | Version | Change |
|-------|---------|--------|
| `tdd-team` | `1.4.0` | 중복 서술 4곳 제거 — `Right-Size`의 mid-session 다운시프트 문단(Step 4와 동일), Setup 2 `Speed configuration` 블록(`--offline`·`clean` 금지는 이미 명령 템플릿과 phase 프롬프트에 있고, 웜업 빌드는 비용 절감이 아닌 이동), Setup 5 콜드스타트 설명, Final Review의 전체 스위트 비용 근거. 지시와 예외 조건은 모두 유지.<br><br>이 과정에서 드러난 정합성 오류 2건 수정 — ⑴ ORCHESTRATOR ONLY 규칙의 `Read` 금지가 Setup 5의 오케스트레이터 1회 탐색과 충돌해 제거(`Edit`/`Write`만 금지). ⑵ `red/green/refactor-agent.md`가 "전체 스위트는 Final Review에서 돈다"고 안내했으나 실제로는 스코프 실행이 기본 — "전체 스위트는 옵트인이므로 교차 클래스 파손 탐지를 여기에 의존하지 말 것"으로 교정 (minor 사유).<br><br>`red-agent.md` 규칙 보강 — 같은 규칙·다른 데이터는 `@ParameterizedTest` 하나로(다른 규칙은 항상 별도 메서드), `@Nested` 내부 클래스 식별자 영어화.<br><br>plan-creator 결합 제거 — 리뷰어들이 계획 문서의 `Section 2`/`Section 7`/`[NEW]` 태그를 조회하도록 되어 있어, SKILL.md가 공식 지원하는 "문서 없이 PRD로 시작" 경로에서 final reviewer의 관점 1번과 하드 규칙 2개가 통째로 무력화됐음. 리뷰어 입력을 문서 경로에서 **확정된 태스크 목록·불변성**으로 교체하고, Step 3은 특정 스킬 산출물이 아닌 요구사항 문서 일반(스펙·계획서·티켓·PRD)을 받도록 일반화. 문서에 불변성·태스크 목록이 이미 있으면 재도출 없이 채택. `SKILL.md`·`references/`(skills/codex/global)·docs·README 동기화 |
| `tdd-team` | `1.3.0` | 참조되지 않는 `references/agent-prompts.md` 제거 (skills/codex) — 프롬프트가 phase별 5개 파일로 분리된 뒤에도 갱신만 계속되던 고아 파일로, 어떤 SKILL.md도 읽지 않는데 제거된 옛 커밋 지시(`git add && git commit`)가 남아 최신 `refactor-agent.md`의 커밋 금지 규칙과 모순 상태였음. 같은 버전의 나머지 변경은 글로벌 스킬 병합 동기화라 CHANGELOG 기록 대상 아님 |

---

## 2026-07-27

### devlife-tools

| Skill | Version | Change |
|-------|---------|--------|
| `md-to-html` | `1.1.0` | 변환 작업 전체를 서브에이전트(`general-purpose`)로 위임 — 메인 세션은 입력 경로 확정과 결과 경로 보고만 담당하고 `.md` 읽기·HTML 작성을 하지 않아 HTML 본문이 메인 컨텍스트에 쌓이지 않음. 붙여넣은 Markdown은 서브에이전트가 대화 컨텍스트를 상속하지 않으므로 스크래치패드에 `.md`로 먼저 저장하도록 명시, 여러 파일은 파일당 서브에이전트 병렬 dispatch, 후속 수정은 `SendMessage`로 동일 에이전트 재사용. 단 HTML 출력은 붙여넣은 경우에도 스크래치패드가 아닌 현재 작업 디렉토리에 저장 — 세션 임시 경로라 사용자가 결과물을 찾지 못함. Guardrails(메인 직접 작성 금지·경로 검증·덮어쓰기 사전 고지) 추가. `SKILL.md`(skills/global)·docs 동기화 |

---

## 2026-07-16

### devlife-planning

| Skill | Version | Change |
|-------|---------|--------|
| `devlife-brainstorming` | `1.10.0` | 확인 절차 단축 — Step 4를 "설계 6섹션을 하나씩 발표하고 매번 승인"에서 "전체 설계를 한 메시지에 발표하고 1번만 확인"으로 변경(수정 요청 시 해당 섹션만 재발표). spec 문서까지의 왕복 확인이 약 10회 → 약 4회로 감소. 문서 작성·plan-creator 핸드오프 HARD-GATE는 유지. `SKILL.md`(skills/codex)·docs 동기화 |
| `plan-creator` | `1.2.0` | 계획 문서 저장 위치를 프로젝트 루트에서 `docs/plan/`로 변경(디렉토리 없으면 생성). `SKILL.md`(skills/codex)·docs 동기화 |
| `plan-creator` | `1.3.0` | Section 5에서 "패키지 위치" ASCII 트리 제거 — 다음 소비자 tdd-team이 Setup에서 패키지/디렉토리 레이아웃을 재스캔(`PROJECT_CONTEXT`)하므로 중복이고, 구현 전 추측성 트리라 stale 위험. 파일/역할 테이블·코드 스니핏은 유지. `SKILL.md`·`assets/plan-template.md`(skills/codex) 동기화 |

---

## 2026-07-15

### devlife-planning

| Skill | Version | Change |
|-------|---------|--------|
| `devlife-brainstorming` | `1.9.0` | 자동 진행 제거 — Step 5 문서 작성과 Step 7 plan-creator 핸드오프를 "명시적 지시가 있을 때만" 수행하도록 변경(단계 확인은 작성/핸드오프 지시가 아님), HARD-GATE에 두 게이트 명시. Step 4→5 사이에 "우려 지점 계속 표면화 → 없으면 요약 후 진행 확인" 흐름 추가. 군더더기·중복 문장 정리(레거시 주석 제거, Principles에서 단계 재진술 제거, 새 가드레일 원칙 추가) — Step 5 필수 커버리지 체크리스트는 유지 |

### devlife-tdd

| Skill | Version | Change |
|-------|---------|--------|
| `tdd-team` | `1.2.0` | 사이클 속도 개선 (두 축) — (1) RED/GREEN/REFACTOR가 매번 전체 테스트 스위트를 돌리던 것을 `TEST_SCOPED_CMD`(작업 중 테스트 클래스만 실행)로 교체, 전체 스위트는 Final Review에서 1회만 실행해 교차 클래스 회귀 확인, Setup에 빌드 데몬 워밍업·`--offline`·`clean` 금지 추가. (2) Setup에 "5. Capture Project Context" 단계 추가 — 오케스트레이터가 기능 영역을 1회만 탐색해 `PROJECT_CONTEXT` 블록(패키지 구조·테스트/픽스처 컨벤션·관련 타입 시그니처·도메인 앵커) 캡처, RED/GREEN/REFACTOR가 매번 코드를 재탐색하던 workflow를 `PROJECT_CONTEXT` 참조로 교체하고 dispatch 템플릿에 주입. `SKILL.md`(skills/codex/global)·`references`(red/green/refactor/agent-prompts)·docs 동기화 |

---

## 2026-07-06

### devlife-planning

| Skill | Version | Change |
|-------|---------|--------|
| `plan-creator` | `1.1.0` | Step 1 코드 탐색 방식을 Claude용으로 수정 — Codex 전용 문구("Codex Explore 서브에이전트", "Do not use Claude Code Agent 문법")를 제거하고 Claude의 `Agent({ subagent_type: "Explore" })` 방식으로 교체. `codex/skills/plan-creator`는 기존 Codex 방식 그대로 유지 |
| `spec-creator` | `1.1.0` | Step 3.5 Spec Review 방식을 Claude용으로 수정 — `tool_search`로 Codex 서브에이전트를 찾던 방식을 `Agent({ subagent_type: "general-purpose" })`로 교체. `codex/skills/spec-creator`는 기존 방식 유지 |

### devlife-tdd

| Skill | Version | Change |
|-------|---------|--------|
| `tdd-team` | `1.1.0` | "Codex Compatibility Rules" 섹션 및 RED/GREEN/REFACTOR/Cycle Reviewer/Final Reviewer 전 구간의 "Codex 서브에이전트", `tool_search`, `apply_patch`, `AGENTS.md` 언급을 제거하고 Claude의 `Agent({ subagent_type: "..." })` 방식과 `CLAUDE.md`로 교체. `codex/skills/tdd-team`은 기존 Codex 방식 유지. README·docs의 "Codex 호환" 설명도 함께 수정 |

### devlife-review

| Skill | Version | Change |
|-------|---------|--------|
| `pr-review` | - | 스킬 제거 — `skills/`, `docs/`, README.md `devlife-review` 테이블에서 삭제. 플랫폼(Bitbucket)·회사 조직(`ratel_pe`, `acuvue-*` 모듈)에 강하게 결합된 스킬이라 공개 마켓플레이스 레포에는 부적합하다고 판단. 글로벌 `~/.claude/skills/pr-review`는 개인 업무용으로 유지 (제거하지 않음). `devlife-review` 카테고리 자체는 유지되며 이제 `grill-me`만 포함 |
| `branch-review` | - | 스킬 제거 — `skills/`, `codex/skills/`, `docs/`, README.md 테이블에서 삭제, 글로벌 `~/.claude/skills/branch-review`도 함께 삭제 |

---

## 2026-07-03 (3)

### devlife-planning

| Skill | Version | Change |
|-------|---------|--------|
| `devlife-brainstorming` | `1.7.0` | Step 1을 도메인 이해 확인 게이트로 전환 (기존 도메인 레이어 코드를 실제로 읽고 이해한 내용을 사용자에게 확인받은 후 진행), Step 2 체크리스트에 도메인 정합성·사이드이펙트 항목 추가, 설계 spec 템플릿에 Domain Impact 섹션(영향받는 기존 도메인 요소/충돌 및 해결 방식/예상 사이드이펙트) 추가, Step 6 셀프 리뷰에 도메인 정합성·사이드이펙트 근거 검증 항목 추가 |

---

## 2026-07-03 (2)

### devlife-planning

| Skill | Version | Change |
|-------|---------|--------|
| `devlife-brainstorming` | `1.6.0` | Step 7·8 통합 — 문서 확인 후 명시적 '승인' 요구를 없애고, 수정 요청이 없으면 별도 확인 질문 없이 바로 plan-creator로 핸드오프 (프롬프트 왕복 1회로 축소) |

---

## 2026-07-03

### devlife-planning

| Skill | Version | Change |
|-------|---------|--------|
| `devlife-brainstorming` | `1.5.0` | Step 2 질문 방식 변경 — 체크리스트 항목을 한 번에 하나씩 묻던 방식에서 한 메시지에 모아 묻는 방식으로 변경, 불명확한 항목만 개별 후속 질문 |

---

## 2026-07-02 (4)

### devlife-planning

| Skill | Version | Change |
|-------|---------|--------|
| `devlife-brainstorming` | `1.4.0` | 설계 섹션 발표 단계 추가 (Step 4: Architecture / Components / Data Flow / Error Handling / Testing), 문서 템플릿 확장, 핸드오프 대상을 spec-creator → plan-creator로 변경, 문서명 "Brainstorming" → "Design Spec" |

---

## 2026-07-02 (3)

### devlife-planning

| Skill | Version | Change |
|-------|---------|--------|
| `devlife-brainstorming` | `1.3.0` | 질문 언어를 한국어로 변경 (Ask in English → Ask in Korean) |

---

## 2026-07-02 (2)

### devlife-planning

| Skill | Version | Change |
|-------|---------|--------|
| `devlife-brainstorming` | `1.2.0` | 대화 언어를 영어로 변경 (질문, 안내 메시지, 승인 프롬프트 전체) |
| `devlife-brainstorming` | `1.1.0` | Scope 분해 규칙 추가 (Step 1.5), 문서 저장 위치 변경 (`docs/brainstorming/YYYY-MM-DD-{topic}.md`), 사용자 리뷰 Gate 강화 (명시적 '승인' 필요), Step 7 Terminal State 명확화 |

---

## 2026-07-02

### devlife-planning

| Skill | Version | Change |
|-------|---------|--------|
| `devlife-brainstorming` | `1.0.0` | 신규 추가 |
| `spec-creator` | `1.0.0` | 신규 추가 — brainstorming 문서 입력, 자동 검토 서브에이전트 |
| `plan-creator` | `1.0.0` | 워크플로우 체인 반영 (brainstorming → spec-creator → plan-creator), Codex Explore 서브에이전트 |
| `prd-creator` | `1.0.0` | 초기 버전 |
| `pdf-to-spec` | `1.0.0` | 초기 버전 |

### devlife-tdd

| Skill | Version | Change |
|-------|---------|--------|
| `tdd-team` | `1.0.0` | Codex 서브에이전트 기반으로 개편 — Cycle Reviewer, Final Reviewer 추가 |
| `test-driven-development` | `1.0.0` | 초기 버전 |

### devlife-review

| Skill | Version | Change |
|-------|---------|--------|
| `branch-review` | `1.0.0` | 설계 품질 평가 항목 업데이트 (Feature Envy, 유지보수성 체크 추가) |
| `pr-review` | `1.0.0` | 신규 추가 |
| `grill-me` | `1.0.0` | 초기 버전 |

### devlife-tools

| Skill | Version | Change |
|-------|---------|--------|
| `devlife-team-starter` | `1.0.0` | 초기 버전 |
| `devlife-codex` | `1.0.0` | 초기 버전 |
| `cmux` | `1.0.0` | 초기 버전 |
| `md-to-html` | `1.0.0` | 초기 버전 |

### 삭제

| Skill | 사유 |
|-------|------|
| `plan-grill` | plan-creator + grill-me 개별 사용으로 대체 |
| `spec-to-jira` | 미사용 |
| `spec-workflow` | 미사용 |
