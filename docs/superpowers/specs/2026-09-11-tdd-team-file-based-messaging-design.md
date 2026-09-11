# tdd-team 파일 기반 에이전트 통신 설계

- 작성일: 2026-09-11
- 대상 스킬: `tdd-team` (`1.10.0` → `2.0.0`)
- 상태: 승인 대기

## 1. 문제

현재 `tdd-team`은 에이전트의 **역할 지시**만 md 파일(`references/*.md`)로 관리하고, **세션·태스크 데이터**는 매 디스패치마다 프롬프트에 인라인으로 넣는다.

프롬프트에 반복해서 들어가는 것:

| 블록 | 성격 |
|---|---|
| `ENVIRONMENT` | 세션당 고정 — 디스패치마다 반복 |
| `PROJECT_CONTEXT` | 세션당 고정 — 디스패치마다 반복 (~450 토큰) |
| Task description | 태스크당 1개 |
| `RED_RESULT` / `GREEN_RESULT` / `FIX_RESULT` | 단계 간 전달, 오케스트레이터가 중계 |
| findings 목록 | 리뷰어 → fix 에이전트, 오케스트레이터가 중계 |
| workspace 경고문 | 전역 고정 |

결과도 에이전트 반환 텍스트로 오케스트레이터 컨텍스트를 거친다.

이 구조의 비용은 **오케스트레이터 트랜스크립트의 영구 누적**이다. `PROJECT_CONTEXT`를 사이클당 4회 재작성하면 ~2,600 토큰이 쌓이고, 이후 모든 턴에서 재과금된다. 긴 세션이 압축에 걸리는 주된 원인이다.

동시에 세 가지가 구조적으로 불가능하다.

- **세션 재개** — 원장(`docs/tdd/session-{feature}.md`)은 태스크 4개 이상일 때만 기록되고, 단계 결과와 fix/서킷 카운터를 담지 않는다.
- **사람의 중간 개입** — 지시가 프롬프트 안에만 있어 사용자가 손댈 지점이 없다.
- **사이클 디버깅** — 실패한 사이클의 단계별 산출물이 디스크에 남지 않는다.

## 2. 결정

에이전트 통신을 전면 파일 기반으로 바꾼다. 산출물은 대상 레포의 `.tdd-team/`에 모으고, **태스크 수와 무관하게 항상** 적용한다.

핵심 원칙: **전문은 파일, 반환값은 STATUS 봉투 한 장.**

오케스트레이터는 봉투만으로 모든 분기를 판단하고 결과 전문은 읽지 않는다. 다음 단계 에이전트가 이전 단계의 결과 파일을 직접 읽는다.

## 3. 디렉토리 구조

```
.tdd-team/
  context.md              # ENVIRONMENT + PROJECT_CONTEXT + 불변식 (Setup에서 1회)
  session.md              # 태스크 목록 + 진행 포인터 + 카운터 (재개용)
  task-01/
    task.md               # 오케스트레이터가 쓴 태스크 지시서
    red-result.md
    green-result.md
    refactor-result.md
    diff.md               # 리뷰어용 사이클 diff (오케스트레이터가 생성)
    review.md             # cycle reviewer findings
    fix-result.md         # fix 라운드가 있을 때만
  task-02/
    ...
  branch-diff.md          # 최종 리뷰용 전체 diff (오케스트레이터가 생성)
  final-review.md
```

기존 `docs/tdd/session-{feature}.md` 원장은 `.tdd-team/session.md`로 흡수하고 폐지한다. 산출물이 한 곳에 모이고 추적 제외가 한 번에 끝난다.

## 4. STATUS 봉투

모든 단계가 이 모양으로만 반환한다. 오케스트레이터 컨텍스트에 들어가는 것은 이것뿐이다.

```
TDD_STATUS
phase: RED | GREEN | REFACTOR | CYCLE_REVIEW | FIX | FINAL_REVIEW
status: OK | BLOCKED | ALREADY_PASSES
result_file: .tdd-team/task-01/red-result.md
tests: {passed}/{failed}
verdict: APPROVED | NEEDS_FIX
findings: {Critical}/{Important}/{Minor}
note: {한 줄 — BLOCKED일 때만}
```

해당 없는 필드는 `n/a`로 채운다. 필드를 생략하지 않는 이유는 기존 결과 블록 규칙과 같다 — 빈 값과 누락을 구분할 수 있어야 한다.

기존 분기가 전부 봉투로 살아난다.

| 기존 분기 | 판단 근거 |
|---|---|
| 전 메서드 `ALREADY_PASSES` → GREEN/REFACTOR 스킵 | `status` |
| GREEN 실패 처리 | `tests` |
| 리뷰어 `APPROVED` / `NEEDS_FIX` | `verdict` |
| Critical/Important만 fix 대상, Minor는 로그 | `findings` |
| fix 라운드 예산 (2회), 서킷 브레이커 (3사이클) | `verdict` 누적 — `session.md`에 기록 |

전문(`RED_RESULT` 등 기존 결과 블록)은 형식을 그대로 두고 위치만 `result_file`로 옮긴다.

## 5. 사이클 리뷰어의 diff

현재 오케스트레이터는 "이번 사이클에서 작성된 테스트 코드 + 구현 코드"를 리뷰어 프롬프트에 인라인으로 넣는다. 인라인 블록 중 가장 크고, 파일 기반에서 누가 만들지 정해야 한다.

**오케스트레이터가 `{task_dir}/diff.md`를 생성한다.** 단, 내용을 컨텍스트에 들이지 않기 위해 Bash 리다이렉션으로 바로 파일에 쓴다.

1. `red-result.md`의 `test_file`·`stubs`, `green-result.md`·`refactor-result.md`의 `files_modified`에서 경로를 모은다 — 경로만 필요하므로 `grep`으로 뽑는다.
2. 그 경로들에 한정해 `git diff`를 돌리고 출력을 `{task_dir}/diff.md`로 리다이렉트한다.
3. 리뷰어에게는 경로만 넘긴다.

**알려진 한계**: 에이전트는 커밋하지 않으므로(기존 규칙), 이전 사이클에서 이미 건드린 파일은 diff에 누적 변경이 함께 나온다. 리뷰어에게 `red-result.md`의 `test_method`에 해당하는 변경에 집중하라고 명시해 범위를 좁힌다. 사이클마다 커밋하도록 바꾸는 것은 "에이전트 커밋 금지" 규칙을 건드리므로 이 설계의 범위 밖이다.

## 6. Result Block Gate

두 단계로 나뉜다.

**봉투 검증** — 반환값이므로 오케스트레이터가 그대로 확인한다. 필드 누락 시 기존 규칙 유지: 같은 에이전트를 1회 재디스패치하고 `BLOCKED` 예산에 계상한다.

**결과 파일 검증** — 파일 내용을 컨텍스트에 들이지 않기 위해 Bash로 키 존재만 확인하고 `PASS` 또는 `MISSING:{field}` 한 줄만 출력한다. 실패 시 봉투 누락과 동일하게 처리한다.

이 분리가 있어야 "컨텍스트 절약"과 "게이트 유지"가 동시에 성립한다.

## 7. 세션 재개

`.tdd-team/session.md`가 재개에 필요한 상태를 전부 보유한다.

```markdown
# TDD Session: {feature}
skill_dir: {절대경로}
test_command: {TEST_SCOPED_CMD}
feedback_mode: per-cycle | auto
consecutive_needs_fix: {N}
fix_rounds_this_cycle: {N}

| # | task | status | last_phase |
|---|------|--------|------------|
| 1 | {도메인 규칙 문장} | DONE | CYCLE_REVIEW:APPROVED |
| 2 | {도메인 규칙 문장} | IN_PROGRESS | GREEN |
```

`feedback_mode`와 두 카운터를 파일에 두는 것이 핵심이다. 이게 없으면 재개한 세션이 fix 예산과 서킷 브레이커를 0부터 다시 세어, 이미 두 번 실패한 사이클을 또 돌린다.

**Setup 0단계**를 신설한다. `.tdd-team/session.md`가 있으면 이어서 할지 새로 시작할지 묻고, 이어갈 경우 Setup 1~5를 건너뛰고 `context.md`를 재사용한 뒤 첫 비-`DONE` 행부터 진행한다.

## 8. 사람의 중간 개입

에이전트가 `context.md`와 `task.md`를 **디스패치 시점에** 읽으므로, 피드백 게이트에서 사용자가 파일을 수정하면 다음 단계부터 반영된다.

이를 보장하기 위해 두 가지를 명시한다.

- 오케스트레이터는 `context.md` / `task.md` 내용을 캐싱해 재사용하지 않는다. 항상 경로만 전달한다.
- 피드백 게이트 문구에 파일을 직접 수정할 수 있다는 안내를 한 줄 추가한다.

## 9. 추적 제외

`.tdd-team/`은 사용자의 `.gitignore`를 건드리지 않고 `.git/info/exclude`에 1회 추가한다. 이미 있으면 skip, git 저장소가 아니면 skip.

`.gitignore`를 고르지 않은 이유: 그 파일은 사용자 레포의 커밋 대상이고, 스킬이 남의 레포에 커밋될 변경을 만드는 것은 범위를 벗어난다.

## 10. 에이전트 reference 변경 (공통)

6개 reference 모두 같은 형태로 바뀐다.

- 입력: "프롬프트에 주어진 태스크/컨텍스트" → "`.tdd-team/context.md`와 `{task_dir}/task.md`를 읽어라"
- 이전 단계 결과: 프롬프트 인라인 → "`{task_dir}/{prior}-result.md`를 읽어라"
- 출력: "결과 블록을 반환하라" → "결과 블록을 `{result_file}`에 쓰고, 반환값은 STATUS 봉투만"

디스패치 프롬프트는 이 수준으로 축소된다.

```
Read {SKILL_DIR}/references/red-agent.md — follow it exactly.
Read .tdd-team/context.md and .tdd-team/task-01/task.md.
Write your result to .tdd-team/task-01/red-result.md.
Return only the TDD_STATUS envelope.
```

## 11. 영향 파일

| 파일 | 변경 |
|---|---|
| `skills/tdd-team/SKILL.md` | Setup 0단계 신설, Setup 5~6 재작성, 디스패치 패턴 4곳, Result Block Gate, Cycle Flow, Feedback Cadence, Session End |
| `skills/tdd-team/references/*.md` (6개) | 입력·출력 경로 규약 |
| `codex/skills/tdd-team/` (7개) | 동일 변경, Codex 문법 |
| `docs/tdd-team.md` | 실행 흐름 갱신 |
| `README.md` | `1.10.0` → `2.0.0` |
| `CHANGELOG.md` | 기록 |

`2.0.0`인 이유: 에이전트 반환 계약과 산출물 위치가 바뀌어 기존 진행 중 세션과 호환되지 않는다.

## 12. 비용 영향

총 토큰은 **10~25% 증가**한다. 감소하는 것은 오케스트레이터 누적 컨텍스트(~70%)다.

| | 현재 | 파일 기반 |
|---|---|---|
| 오케스트레이터 누적 / 사이클 | ~2,600 토큰 | ~800 토큰 |
| 서브에이전트 총 토큰 | 기준 | +10~25% (대부분 캐시 히트) |

증가 원인은 파일 읽기로 인한 에이전트 턴 수 증가(턴마다 누적 컨텍스트 재과금)와 결과를 `Write`로 한 번 더 계상하는 것이다. 감소 구간도 있다 — fix 라운드에서 findings가 오케스트레이터를 경유하지 않는다.

**이 변경의 값은 비용 절감이 아니라 긴 세션의 완주와 재개·개입·디버깅 가능성이다.** 태스크 3개 이하 세션에서는 순수 손해이며, 이를 감수하고 항상 적용하기로 결정했다 — 두 경로가 공존하면 스킬 복잡도가 올라가고, 재개 보장이 세션 크기에 따라 달라지기 때문이다.

## 13. 비목표

- `references/*.md`의 역할 지시 내용 자체는 바꾸지 않는다. 입출력 규약만 바꾼다.
- 결과 블록(`RED_RESULT` 등)의 필드 구성은 그대로 둔다.
- 모델 선택, 커버리지 하한, REFACTOR 체크 조건 등 기존 판단 규칙은 손대지 않는다.
- `.tdd-team/`의 자동 정리는 하지 않는다. 디버깅 기록으로 남기는 것이 목적이다.
