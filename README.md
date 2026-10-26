# devlife-plugins

개발 워크플로우를 위한 Claude Code 스킬 모음입니다.  
기획 문서화, 계획 수립, TDD, 멀티 에이전트 협업 등 반복되는 개발 작업을 자동화합니다.

## Plugins

모든 스킬·에이전트·훅은 `devlife` 플러그인 하나로 배포됩니다. 아래 그룹은 용도별 분류입니다.  
스킬은 `devlife:{skill-name}`으로 호출합니다. 스킬별 상세 동작은 [`docs/{skill-name}.md`](docs/)를 참고하세요.

| Group | What it's for |
|-------|---------------|
| [`devlife-planning`](#devlife-planning) | 기획 문서화 — 브레인스토밍부터 Spec, 계획 문서까지 |
| [`devlife-tdd`](#devlife-tdd) | TDD 실행 — Red/Green/Refactor 자동화 (서브에이전트 순차 / agent teams 병렬), 테스트 작성 규칙 |
| [`devlife-tools`](#devlife-tools) | 유틸리티 — 멀티 에이전트 환경, 마크다운 변환, 터미널 제어 |

---

### devlife-planning

기획·문서화 워크플로우. 아이디어 브레인스토밍부터 기술 명세, 태스크 계획까지 커버합니다.

**워크플로우:** `devlife-brainstorming → spec-creator → plan-creator → tdd-subagent | tdd-agent-team`

#### Skills

| Skill | Version | Description |
|-------|---------|-------------|
| `devlife-brainstorming` | `1.10.1` | 대화로 아이디어의 what/why와 설계 결정을 정리해 승인된 설계 spec 문서로 만듦 |
| `spec-creator` | `1.1.1` | 대규모 기능 기술 명세 작성 — 도메인 컨텍스트·불변성·하위 태스크 S/M/L 분해 포함 |
| `plan-creator` | `1.11.1` | 코드를 탐색해 태스크 구현 계획 문서 작성 — API 설계·비즈니스 로직·불변성·TDD 순서 포함, `docs/plan/`에 저장 |
| `pdf-to-spec` | `1.0.0` | PDF 텍스트 추출(PDFKit + Vision OCR) → spec-creator 워크플로우 자동 실행 |

---

### devlife-tdd

TDD 실행 워크플로우. Red/Green/Refactor 사이클을 서브에이전트 순차 실행(`tdd-subagent`) 또는 agent teams 병렬 실행(`tdd-agent-team`)으로 자동화합니다.

#### Skills

| Skill | Version | Description |
|-------|---------|-------------|
| `tdd-subagent` | `3.1.0` | Red/Green/Refactor 서브에이전트를 순차 실행하는 TDD — 사이클마다 리뷰어 검수, 중단된 세션 재개 지원 |
| `tdd-agent-team` | `2.0.0` | RED·GREEN·REFACTOR 팀원이 공유 작업 목록으로 병렬 진행하는 TDD — 마지막에 도메인·테스트·설계 리뷰어 3명이 리뷰 |
| `test-writing` | `1.0.1` | 테스트 작성 규칙 — 무엇을 테스트할지, 한 테스트에 한 동작, 도메인 문장 이름, 계층별 테스트 전략 |

#### Agents

`tdd-agent-team`이 팀원으로 스폰하는 에이전트입니다. 직접 호출하지 않습니다.

| Agent | Description |
|-------|-------------|
| `tdd-red` | 태스크의 동작을 실패하는 테스트로 작성 |
| `tdd-green` | 실패하는 테스트를 통과시키는 최소 코드 작성 |
| `tdd-refactor` | 동작을 바꾸지 않고 프로덕션·테스트 코드 정리 |
| `tdd-reviewer` | 세션 전체를 도메인·테스트·설계 중 한 관점으로 최종 리뷰 |

#### Hooks

| Hook | Event | Description |
|------|-------|-------------|
| `allow-tdd-artifact` | `PreToolUse` | TDD 스킬이 주고받는 `_workspace/tdd-*/**/*.md` 파일의 권한 프롬프트 생략 |

---

### devlife-tools

유틸리티 스킬 모음. 멀티 에이전트 환경 구성, 마크다운 변환, 터미널 앱 제어를 담당합니다.

#### Skills

| Skill | Version | Description |
|-------|---------|-------------|
| `devlife-team-starter` | `1.0.0` | cmux에 Codex 에이전트 pane 생성 — Claude + Codex 병렬 작업 환경 구성 |
| `devlife-codex` | `1.0.0` | Codex cmux pane에 태스크 전송 + 결과 파일 수집 (`devlifeteam/` 폴더) |
| `cmux` | `1.0.0` | Ghostty 기반 터미널 제어 — pane/workspace 관리, 브라우저 자동화, 알림, SSH, 마크다운 뷰어 |
| `md-to-html` | `1.1.0` | Markdown → 독립형 HTML 변환 (외부 CSS/JS 없음) — 서브에이전트 위임 실행 |

---

## Installation

```bash
claude plugin marketplace add https://github.com/dlwnsgus777/devlife-plugins
claude plugin install devlife@devlife-plugins
```

업데이트:

```bash
claude plugin marketplace update devlife-plugins
claude plugin install devlife@devlife-plugins
```

새 세션부터 적용됩니다.

---

## License

MIT © [dlwnsgus777](https://github.com/dlwnsgus777)
