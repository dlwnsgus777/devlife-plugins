# devlife-plugins

개발 워크플로우를 위한 Claude Code 스킬 모음입니다.  
TDD, 기획 문서화, 브랜치 리뷰, 계획 수립, 멀티 에이전트 협업 등 반복되는 개발 작업을 자동화합니다.

## Plugins

| Plugin | Version | What it's for |
|--------|---------|---------------|
| [`devlife-planning`](#devlife-planning) | `1.0.0` | 기획 문서화 — 브레인스토밍부터 Spec, 계획 문서까지 |
| [`devlife-tdd`](#devlife-tdd) | `1.1.0` | TDD 실행 — 3에이전트 Red/Green/Refactor 자동화 |
| [`devlife-review`](#devlife-review) | `1.0.0` | 코드 리뷰 — 설계 심문 |
| [`devlife-tools`](#devlife-tools) | `1.0.0` | 유틸리티 — 멀티 에이전트 환경, 마크다운 변환, 터미널 제어, 작업 이력 문서화 |

---

### devlife-planning

기획·문서화 워크플로우. 아이디어 브레인스토밍부터 기술 명세, 태스크 계획까지 커버합니다.

**워크플로우:** `devlife-brainstorming → spec-creator → plan-creator → tdd-team`

#### Skills

| Skill | Version | Description |
|-------|---------|-------------|
| `devlife-brainstorming` | `1.10.0` | 아이디어 → 승인된 설계 spec 전환 — what/why + Architecture/Domain Model/Components/Data Flow/Error Handling/Testing 등 커버, DDD 렌즈(bounded context/aggregate/invariant/domain event/ubiquitous language)로 기존 도메인 확인, 우려 지점을 계속 표면화하고 명시적 지시가 있을 때만 문서 작성·plan-creator 핸드오프, 스펙 문서는 고정 템플릿 없이 자유 구성하되 필수 항목은 반드시 커버, 복잡도에 따라 깊이 조절 |
| `spec-creator` | `1.1.0` | 대규모 기능 기술 명세 작성 — 도메인 컨텍스트·불변성·하위 태스크 S/M/L 분해 포함 |
| `plan-creator` | `1.8.0` | 태스크 구현 계획 문서 작성 — API 설계·비즈니스 로직·TDD 순서 포함, Explore 서브에이전트 코드 탐색, 요청이 지목한 대상을 포함하는 가장 좁은 범위에서 시작해 결과가 경계에 닿으면 넓혀 재탐색(범위는 잠정, 8개 카테고리는 항상 전부 요청·카테고리당 상위 8개 상한), 질문 수·섹션 생략은 사전 분류가 아니라 탐색·답변 결과가 결정, 답변 모순 검사(범위·리스크·기술·일정), 불변성에 ID·출처 태그 부여해 tdd-team까지 추적, 자체 검증 6항목 결과 보고 및 미해결 시 핸드오프 차단, 도메인 변화 지점 추상화 제안(two-case rule로 억지 추상화 차단), 함정 스캔으로 기존 구현의 알려진 결함을 `→ 신규는` 대안과 함께 섹션 3에 기록(재사용 스캔의 역방향), 기존 구현과 병행하는 신규 플로우는 격리를 양방향 불변성으로 명시, 섹션 6에 코드 스니핏 자리를 템플릿 슬롯으로 고정(메서드 본문까지 포함 — 호출 순서·불변성 가드 절·예외·반환 형태), 계획 문서는 `docs/plan/`에 저장 |
| `pdf-to-spec` | `1.0.0` | PDF 텍스트 추출(PDFKit + Vision OCR) → spec-creator 워크플로우 자동 실행 |

---

### devlife-tdd

TDD 실행 워크플로우. 서브에이전트 기반 Red/Green/Refactor 사이클을 자동 오케스트레이션합니다.

#### Skills

| Skill | Version | Description |
|-------|---------|-------------|
| `tdd-team` | `2.2.0` | 3에이전트 TDD 사이클 (Red/Green/Refactor) — Cycle Reviewer·Final Reviewer·FIX 에이전트 포함, RED/GREEN 격리는 변경 크기와 무관하게 유지하되 주변 의식은 축소(시나리오 배치, Final Review는 세션에서 건드린 클래스만·전체 스위트는 옵트인, Cycle Reviewer는 기본 정적 추론), 에이전트 커밋 금지, 사이클 중엔 대상 테스트 클래스만 실행, Setup에서 프로젝트 컨텍스트 1회 캡처(구현 대상 파일·목표가 아닌 것·기존 코드의 함정을 경계로 포함해 결함 답습과 범위 이탈 차단), REFACTOR 체크 조건에 Feature Envy·단일 책임 위반·추상화 레벨 혼재 추가, 탐색 대신 에스컬레이션(스코프 펜스 + `MISSING_FACT`는 오케스트레이터가 사실을 구해 context.md에 추가 후 같은 컨텍스트로 재디스패치), Setup은 확인한 사실만 기록, 모든 재시도에 예산 부여(`OVERWHELMED` 축소 재시도 1회·결과 블록 재디스패치 1회·수정 2라운드)와 3사이클 연속 NEEDS_FIX 시 서킷 브레이커, 커버리지 하한(불변성마다 어기는/지키는 경계 양쪽 + 클래스당 해피패스, 상한 아님)과 한쪽만 검증 시 `PARTIAL` 지적, 1번 사이클만 게이트 후 진행 방식 1회 질의, 에이전트 통신을 `.tdd-team/` md 파일로 전환(컨텍스트·태스크·단계 결과·리뷰를 파일로 주고받고 반환값은 TDD_STATUS 봉투만), 세션 재개 지원(태스크 수 무관하게 session.md 기록, fix/서킷 카운터 포함), 사이클 중 context.md·task.md 직접 수정 가능, 태스크 분해 시 「이 태스크를 통과시키는 생산 코드 변경」 선제 체크로 Red가 될 수 없는 사이클을 목록 제시 전에 제거, 테스트 실행 출력은 전체 콘솔 로그가 아니라 결과(통과·실패 수, 실패 메시지, 이번 세션 코드의 첫 스택 프레임)만 읽도록 제약, RED는 컴파일(`TEST_COMPILE_CMD`)을 먼저 통과시킨 뒤 테스트를 1회 실행하고 `ALREADY_PASSES` 판정은 기존 생산 코드를 겨냥한 테스트에만 적용, 피드백은 사이클 리뷰어 승인 후 사이클 단위로 1회(단계마다 피드백을 요구하는 프로젝트 지시도 사이클 단위로 지킴), 불변성 ID(`INV-xxx`)는 `.tdd-team/` 산출물 전용 — 생산·테스트 코드의 주석·이름에 넣지 않음 |
| `test-driven-development` | `1.0.0` | Java/Spring Boot TDD 원칙 가이드 — Red/Green/Refactor 단계별 규칙, Iron Law, Fixture 패턴 |

#### Hooks

| Hook | Event | Description |
|------|-------|-------------|
| `allow-tdd-artifact` | `PreToolUse` | `tdd-team` 에이전트들이 주고받는 `.tdd-team/**/*.md` 아티팩트의 권한 프롬프트를 생략합니다. 그 외 경로는 평소대로 프롬프트가 뜹니다. |

---

### devlife-review

코드 리뷰 워크플로우. 설계 심문을 커버합니다.

#### Skills

| Skill | Version | Description |
|-------|---------|-------------|
| `grill-me` | `1.0.0` | 계획/설계 심문 검증 — 한 번에 한 질문, 추천 답안 제시, 설계 결정 트리 전체 검증 |

---

### devlife-tools

유틸리티 스킬 모음. 멀티 에이전트 환경 구성, 마크다운 변환, 터미널 앱 제어, 작업 이력 문서화를 담당합니다.

#### Skills

| Skill | Version | Description |
|-------|---------|-------------|
| `devlife-team-starter` | `1.0.0` | cmux에 Codex 에이전트 pane 생성 — Claude + Codex 병렬 작업 환경 구성 |
| `devlife-codex` | `1.0.0` | Codex cmux pane에 태스크 전송 + 결과 파일 수집 (`devlifeteam/` 폴더) |
| `cmux` | `1.0.0` | Ghostty 기반 터미널 제어 — pane/workspace 관리, 브라우저 자동화, 알림, SSH, 마크다운 뷰어 |
| `md-to-html` | `1.1.0` | Markdown → 독립형 HTML 변환 (외부 CSS/JS 없음) — 서브에이전트 위임 실행 |
| `project-history` | `1.0.0` | Jira 티켓 하위 이슈 + git diff 분석 → 이력서용 작업 이력 문서 생성 |

---

## Installation

```
/install-marketplace https://github.com/dlwnsgus777/devlife-plugins
```

---

## License

MIT © [dlwnsgus777](https://github.com/dlwnsgus777)
