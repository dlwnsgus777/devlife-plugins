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
- `CHANGELOG.md`에 변경 내용 기록 (날짜, 스킬명, 버전, 변경 요약)

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

## 마켓플레이스

`.claude-plugin/marketplace.json`과 `plugin.json`이 설정되어 있어 아래 명령으로 설치 가능합니다.

```
/install-marketplace https://github.com/dlwnsgus777/devlife-plugins
```
