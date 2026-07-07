# devlife-plugins — 프로젝트 가이드

Claude Code 스킬 마켓플레이스 레포지토리입니다.  
이 파일은 이 레포 안에서 작업할 때 따라야 할 규칙을 정의합니다.

## 디렉토리 구조

```
devlife-plugins/
├── skills/               ← 실제 스킬 파일 (Claude Code용)
│   └── {skill-name}/
│       ├── SKILL.md      ← 스킬 본문 (필수)
│       ├── references/   ← 스킬이 런타임에 읽는 참조 문서
│       ├── assets/       ← 템플릿, 정적 파일
│       └── scripts/      ← 실행 스크립트 (Swift 등)
├── codex/                ← Codex 에이전트용 스킬 사본
│   └── skills/
├── docs/                 ← 스킬별 사람이 읽는 요약 문서
│   └── {skill-name}.md
├── agents/               ← 커스텀 에이전트 정의
├── .claude-plugin/
│   ├── plugin.json       ← 마켓플레이스 플러그인 메타데이터
│   └── marketplace.json  ← 마켓플레이스 등록 정보
└── README.md             ← 플러그인 그룹 기반 스킬 목록
```

## 스킬 작업 규칙

### 플랫폼 분리 원칙

`skills/`(Claude Code용)와 `codex/skills/`(Codex용)는 같은 스킬의 플랫폼별 사본입니다.

- `skills/{skill-name}/SKILL.md`에는 Codex 전용 문구(예: "Codex Explore 서브에이전트", `tool_search`로 멀티에이전트 툴 탐색, "Do not use Claude Code Agent 문법")가 들어가면 안 됩니다.
- Claude용 스킬에서 서브에이전트가 필요하면 Claude Code의 `Agent({ subagent_type: "..." })` 문법을 사용합니다.
- 두 버전은 프로세스 뼈대(단계 구성, 질문 흐름 등)는 동일하게 유지하되, 에이전트 호출 문법·툴 이름은 플랫폼에 맞게 다르게 작성합니다.
- `README.md` 등 사람이 읽는 문서에서도 Claude용 스킬을 설명할 때 Codex 전용 툴 이름을 쓰지 않습니다.

### 스킬 추가/수정 시

1. `skills/{skill-name}/SKILL.md` 수정 — 스킬 본문
2. `docs/{skill-name}.md` 동기화 — 사람이 읽는 요약 문서
3. `codex/skills/{skill-name}/SKILL.md` 동기화 — Codex 호환 버전
4. `README.md` 업데이트 — 해당 플러그인 그룹 Skills 테이블

### 스킬 삭제 시

- `skills/`, `codex/skills/`, `docs/` 세 곳 모두에서 제거
- `README.md` 테이블에서도 제거

### 버전 관리

스킬 내용이 수정되면 반드시 버전을 올립니다.

- `README.md` Skills 테이블의 해당 스킬 버전 업데이트
- 버전 규칙: `major.minor.patch`
  - `patch` — 오탈자, 설명 보완 등 동작 변화 없는 수정
  - `minor` — 기능 추가, 트리거 추가, 프로세스 변경
  - `major` — 하위 호환 불가한 구조 변경

### CHANGELOG 기록 규칙

버전이 올라가는 변경은 원칙적으로 `CHANGELOG.md`에 기록합니다 (patch 포함 — 의도적인 수정이라면 레벨과 무관하게 기록).

| 변경 유형 | 버전 갱신 | CHANGELOG 기록 |
|---|---|---|
| 의도적인 기능/트리거/프로세스/오탈자 수정 (patch/minor/major 불문) | O | O |
| `sync-skill`을 통한 글로벌 ↔ 프로젝트 병합 동기화 (`## 글로벌 동기화` 참고) | O | X |

- 기록 형식: 날짜, 스킬명, 버전, 변경 요약 — `README.md` Skills 테이블과 동일한 버전 값 사용
- 예외 이유: 병합 동기화는 두 위치의 내용을 맞추는 기계적 작업이라 별도의 변경 이력으로 보지 않음. 버전 숫자는 최신 내용을 반영하도록 올리되, `CHANGELOG.md`에는 남기지 않음
- 이 예외는 병합 동기화에만 한정되며, 스킬 삭제 등 다른 케이스는 이 규칙에 포함되지 않음 (필요 시 별도로 정의)

### 스킬 구조 컨벤션

- `SKILL.md` 상단 frontmatter에 `name`, `description`, 트리거 키워드 포함
- `docs/{skill-name}.md`는 `## 언제 사용하나요?`, `## 트리거 문구`, `## 실행 흐름` 구조 유지
- 트리거 예시는 README 테이블에 넣지 않음 — SKILL.md와 docs에서만 관리

## README 형식

플러그인 그룹(`###`) → `#### Skills` 테이블 구조를 유지합니다.

```
| Skill | Version | Description |
```

- 스킬명은 backtick으로 표기: `` `skill-name` ``
- 스킬 추가/삭제 시 `## Plugins` 상단 요약 테이블도 함께 업데이트

## 글로벌 동기화

이 레포의 스킬은 `~/.claude/skills/`의 글로벌 스킬과 동기화됩니다.

```bash
# 글로벌 → 프로젝트
cp ~/.claude/skills/{skill-name}/SKILL.md skills/{skill-name}/SKILL.md

# 프로젝트 → 글로벌
cp -r skills/{skill-name} ~/.claude/skills/
```

## 커밋 메시지 규칙

형식: `type: subject`

- `feat` — 스킬 신규 추가, 기능/트리거/프로세스 추가, 글로벌 ↔ 프로젝트 스킬 동기화 반영
- `fix` — 버그 수정
- `docs` — README, docs/, CLAUDE.md 등 문서 변경
- `chore` — 설정 파일, 권한, 잡무성 변경

예:
```
feat: sync devlife-brainstorming skill from global
docs: add versioning/changelog rules to CLAUDE.md
chore: update allowed permissions in settings.local.json
```

- subject는 소문자로 시작, 명령형으로 작성 (add/update/remove/sync 등)
- 하나의 커밋에는 하나의 관심사만 담기 — 여러 스킬을 동시에 바꿨다면 스킬별로 커밋 분리 고려

## 마켓플레이스

`.claude-plugin/marketplace.json`과 `plugin.json`이 설정되어 있어 아래 명령으로 설치 가능합니다.

```
/install-marketplace https://github.com/dlwnsgus777/devlife-plugins
```
