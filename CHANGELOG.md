# Changelog

## [Unreleased]

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
