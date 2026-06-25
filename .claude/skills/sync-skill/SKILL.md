---
name: sync-skill
description: Syncs a skill from the global ~/.claude/skills/ into this project's
  claude/skills/ directory. Use when the user wants to copy or update a skill from
  their global config into the project. Trigger on "스킬 복사", "스킬 동기화", "스킬 최신화",
  "sync skill", "copy skill", or any phrase like "[스킬명] 스킬 프로젝트에 복사/추가/최신화".
---

# Sync Skill

Copies or merges a skill from `~/.claude/skills/` into `skills/` of the current project,
then propagates the result to `codex/skills/` if the same skill exists there.

## Usage

User specifies a target skill name, e.g.:
- "plan-creator 스킬 동기화해줘"
- "tdd 스킬 프로젝트에 복사해줘"
- "backend-standards 스킬 최신화해줘"

If no skill name is given, ask the user which skill to sync using `AskUserQuestion`.

---

## Scope

동기화 대상 디렉토리:

| 디렉토리 | 역할 | 싱크 대상 |
|---|---|---|
| `~/.claude/skills/` | 전역 소스 | 읽기 전용 (소스) |
| `skills/` | 프로젝트 Claude 스킬 (플러그인 표준 경로) | **대상** |
| `codex/skills/` | 프로젝트 Codex 스킬 | **대상** (스킬이 존재할 때만) |
| `.claude/skills/` | 현재 프로젝트의 Claude Code 설정 | **제외** — 절대 읽거나 쓰지 않음 |

> `.claude/skills/`는 Claude Code 하네스가 관리하는 디렉토리이므로 싱크 대상에서 제외한다.

---

## Process

### Step 1: Resolve Skill Name

Extract the target skill name from the user's message.

If ambiguous or not provided:
- List available global skills via `ls ~/.claude/skills/`
- Ask the user to pick one using `AskUserQuestion`

---

### Step 2: Inspect All Three Locations

Run the following checks in parallel:

1. **Global skill** — `~/.claude/skills/{skill-name}/`
   - List all files inside (SKILL.md, assets/, etc.)

2. **Project skill** — `skills/{skill-name}/`
   - If it exists, read `SKILL.md` for comparison

3. **Codex skill** — `codex/skills/{skill-name}/`
   - Check if it exists; if so, read `SKILL.md`

---

### Step 3: Sync Global → skills/

| Situation | Action |
|---|---|
| Project skill does not exist | **Copy** all files from global to `skills/` |
| Project skill exists, content identical | No changes needed |
| Project skill exists, content differs | **Merge** — see Step 4 |

---

### Step 4: Merge (when global and claude/skills/ differ)

Read both `SKILL.md` files fully, then produce a merged result:

**Merge rules (apply in order):**
1. Keep all trigger patterns from **both** versions (union)
2. For procedural content (steps, rules), prefer the version with **more detail**
3. If a section exists only in one version, include it
4. Never silently drop content — if two versions conflict in meaning, include both and add a comment `<!-- merged: check this section -->`

Write the merged result to `skills/{skill-name}/SKILL.md`.

For asset files (e.g., `assets/*.md`):
- If identical: no action
- If project version is missing: copy from global
- If both exist and differ: show a brief diff summary and ask the user which to keep via `AskUserQuestion`

---

### Step 5: Propagate to codex/skills/

After `claude/skills/` is up to date, check `codex/skills/{skill-name}/`:

| Situation | Action |
|---|---|
| `codex/skills/` does not have this skill | Skip (do not create) |
| `codex/skills/` has the skill, content identical to `skills/` | No changes needed |
| `codex/skills/` has the skill, content differs | **Preserve codex frontmatter, replace body** — see below |

**Codex SKILL.md 업데이트 규칙**:
codex 고유의 프런트매터(name, description 등 `---...---` 블록)는 그대로 유지하고,
닫는 `---` 이후의 body 내용만 `skills/` 버전으로 교체한다.
(codex 형식 차이를 보호하기 위함)

For asset files under `codex/skills/{skill-name}/assets/`:
- If identical: no action
- If missing: copy from `skills/`
- If different: overwrite with `skills/` version

---

### Step 6: Report

After all writes are complete, summarize:

```
## 동기화 결과: {skill-name}

### skills/
- SKILL.md: [복사됨 / 병합됨 / 변경 없음]
- assets/{file}: [복사됨 / 변경 없음]

### codex/skills/
- SKILL.md: [업데이트됨 / 변경 없음 / 해당 없음(스킬 없음)]
- assets/{file}: [복사됨 / 변경 없음]

변경된 내용:
- [추가된 트리거 패턴]
- [추가된 섹션]
- [기타 변경사항]
```

Then ask:
> "동기화 결과를 확인해 주세요. 수정이 필요한 부분이 있으신가요?"
