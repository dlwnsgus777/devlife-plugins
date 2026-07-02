# devlife-plugins

개발 워크플로우를 위한 Claude Code 스킬 모음입니다.  
TDD, 기획 문서화, 브랜치 리뷰, 계획 수립, 멀티 에이전트 협업 등 반복되는 개발 작업을 자동화합니다.

## Plugins

| Plugin | Version | What it's for |
|--------|---------|---------------|
| [`devlife-planning`](#devlife-planning) | `1.0.0` | 기획 문서화 — 브레인스토밍부터 Spec, 계획 문서까지 |
| [`devlife-tdd`](#devlife-tdd) | `1.0.0` | TDD 실행 — 3에이전트 Red/Green/Refactor 자동화 |
| [`devlife-review`](#devlife-review) | `1.0.0` | 코드 리뷰 — 브랜치·PR 점수화, 설계 심문 |
| [`devlife-tools`](#devlife-tools) | `1.0.0` | 유틸리티 — 멀티 에이전트 환경, 마크다운 변환, 터미널 제어 |

---

### devlife-planning

기획·문서화 워크플로우. 아이디어 브레인스토밍부터 기술 명세, 태스크 계획까지 커버합니다.

**워크플로우:** `devlife-brainstorming → spec-creator → plan-creator → tdd-team`

#### Skills

| Skill | Version | Description |
|-------|---------|-------------|
| `devlife-brainstorming` | `1.0.0` | 아이디어 → 설계 결정 전환 — 핵심 문제·범위·성공 기준을 대화형으로 도출 후 brainstorming 문서 작성 |
| `spec-creator` | `1.0.0` | 대규모 기능 기술 명세 작성 — 도메인 컨텍스트·불변성·하위 태스크 S/M/L 분해 포함 |
| `prd-creator` | `1.0.0` | PRD 문서 작성 — 에픽 단위 기능을 plan-creator용 독립 하위 태스크로 분해 |
| `plan-creator` | `1.0.0` | 태스크 구현 계획 문서 작성 — API 설계·비즈니스 로직·TDD 순서 포함, Codex Explore 서브에이전트 코드 탐색 |
| `pdf-to-spec` | `1.0.0` | PDF 텍스트 추출(PDFKit + Vision OCR) → spec-creator 워크플로우 자동 실행 |

---

### devlife-tdd

TDD 실행 워크플로우. Codex 서브에이전트 기반 Red/Green/Refactor 사이클을 자동 오케스트레이션합니다.

#### Skills

| Skill | Version | Description |
|-------|---------|-------------|
| `tdd-team` | `1.0.0` | 3에이전트 TDD 사이클 (Red/Green/Refactor) — Cycle Reviewer·Final Reviewer 포함, Codex 호환 |
| `test-driven-development` | `1.0.0` | Java/Spring Boot TDD 원칙 가이드 — Red/Green/Refactor 단계별 규칙, Iron Law, Fixture 패턴 |

---

### devlife-review

코드 리뷰 워크플로우. 브랜치 자체 점검부터 Bitbucket PR 리뷰, 설계 심문까지 커버합니다.

#### Skills

| Skill | Version | Description |
|-------|---------|-------------|
| `branch-review` | `1.0.0` | 현재 브랜치 4차원(컨벤션·테스트·도메인·설계) 점수화 — 타임스탬프 리뷰 리포트 저장 |
| `pr-review` | `1.0.0` | Bitbucket PR 코드리뷰 — PN 룰(P1~P5) 우선순위, 도메인 문서 연동, 테스트 커버리지 확인 |
| `grill-me` | `1.0.0` | 계획/설계 심문 검증 — 한 번에 한 질문, 추천 답안 제시, 설계 결정 트리 전체 검증 |

---

### devlife-tools

유틸리티 스킬 모음. 멀티 에이전트 환경 구성, 마크다운 변환, 터미널 앱 제어를 담당합니다.

#### Skills

| Skill | Version | Description |
|-------|---------|-------------|
| `devlife-team-starter` | `1.0.0` | cmux에 Codex 에이전트 pane 생성 — Claude + Codex 병렬 작업 환경 구성 |
| `devlife-codex` | `1.0.0` | Codex cmux pane에 태스크 전송 + 결과 파일 수집 (`devlifeteam/` 폴더) |
| `cmux` | `1.0.0` | Ghostty 기반 터미널 제어 — pane/workspace 관리, 브라우저 자동화, 알림, SSH, 마크다운 뷰어 |
| `md-to-html` | `1.0.0` | Markdown → 독립형 HTML 변환 (외부 CSS/JS 없음) |

---

## Installation

```bash
git clone https://github.com/dlwnsgus777/devlife-plugins.git
cp -r devlife-plugins/skills/* ~/.claude/skills/
```

---

## License

MIT © [dlwnsgus777](https://github.com/dlwnsgus777)
