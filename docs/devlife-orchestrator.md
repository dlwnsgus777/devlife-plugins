# devlife-orchestrator

> **실험적 스킬**입니다. GPT가 지휘하는 멀티 모델 구성을 직접 돌려 보기 위한 것으로, 일반 TDD 작업에는 [tdd-team](./tdd-team.md)을 권장합니다.

Codex(GPT)가 [tdd-team](./tdd-team.md)을 지휘하고, tdd-team의 단계 에이전트는 cmux 탭의 Claude Code(Opus) 워커 3개(RED·GREEN·REFACTOR)가 역할별로 수행하는 하네스입니다.  
TDD 규칙(불변성, 태스크 분해, 커버리지 하한, 사이클 흐름, 수정 예산, 서킷 브레이커, 최종 리뷰, 재개)은 **tdd-team을 그대로** 따릅니다. 이 스킬이 바꾸는 것은 두 가지뿐입니다.

| tdd-team 원래 동작 | 이 하네스에서 |
|---|---|
| 단계 에이전트를 Codex 서브에이전트로 실행 | 역할별 **Claude 워커 탭**(RED·GREEN·REFACTOR)에 프롬프트 파일을 보내 실행. FIX는 지적 대상에 따라 RED(테스트) 또는 GREEN(생산 코드) |
| 1번 사이클 후 진행 방식 질문 | 묻지 않고 자동 진행 (수정 예산 소진·서킷 브레이커는 그대로 멈춤) |

사이클 리뷰어와 최종 리뷰어는 tdd-team 그대로 **Codex 서브에이전트**입니다. 리뷰하는 모델(GPT)과 코드를 쓴 모델(Claude)이 다르고, 리뷰 내용이 오케스트레이터의 맥락을 키우지 않습니다.

**Codex 전용 스킬**입니다. 워커는 Claude 플러그인의 `devlife-worker` 에이전트입니다. tdd-team 스킬 파일은 수정하지 않습니다.

## 언제 사용하나요?

- 작업을 나누고 판정하는 모델(GPT)과 작업하는 모델(Claude)을 **분리한 tdd-team**을 실험할 때

## 트리거 문구

```
"개발인생 오케스트레이터"
"오케스트레이터 시작"
"하네스로 개발해줘"
"claude 워커한테 시켜"
```

## 사전 요구사항

- Codex 플러그인 `devlife-plugins`와 Claude 플러그인 `devlife`가 모두 설치되어 있어야 합니다.
- cmux 터미널에서 평소처럼 `codex`를 실행하고 `$devlife-orchestrator <계획 문서 경로>`로 호출합니다. 특별한 실행 옵션은 필요 없습니다.

**입력: 계획 문서** — 이 스킬은 계획을 쓰지 않습니다. tdd-team과 같은 입력을 받으며, `plan-creator` 문서(불변성 `INV-xxx`와 `[NEW]`/`[REGRESSION]` 구현 순서 포함)가 가장 잘 맞습니다. 문서가 없으면 tdd-team Setup이 요구사항을 묻습니다.

```
1. $plan-creator <요청>                              → docs/plan/task-xxx.md  (필요할 때만)
2. $devlife-orchestrator docs/plan/task-xxx.md      → TDD 실행
```

**처음 한 번만 하는 승인**

| 언제 | 무엇을 | 이유 |
|---|---|---|
| 처음 쓸 때 (전체 1회) | cmux 승인 창에서 **"don't ask again for commands that start with `cmux`"** 선택 | Codex 기본 샌드박스가 cmux 소켓을 막습니다. 이 규칙은 `~/.codex/rules/default.rules`에 저장되어 이후 모든 세션에 적용됩니다 |
| 프로젝트마다 처음 | RED·GREEN·REFACTOR 탭에서 **"Yes, I trust this folder"** | Claude Code 자체의 폴더 신뢰 확인입니다 |
| Gradle 등 작업 폴더 밖에 쓰는 테스트일 때 | 테스트 명령 승인 창에서 "don't ask again" 선택 | 샌드박스가 `~/.gradle` 같은 경로 쓰기를 막습니다 |

## 실행 흐름

```
0. 자기 위치 찾기: 화면에 표시(DL-xxxx)를 출력하고 cmux surface들을 읽어 자기 pane과 workspace 확인
1. tdd-team Setup 그대로: 재개 확인, 테스트 명령 감지, 불변성 표, 태스크 목록 확인(사람)
2. 워커 실행: pane 1개 = Watchdog 탭 + RED·GREEN·REFACTOR 탭 (테스트 명령만 허용, GREEN·REFACTOR는 테스트 파일 편집 거부)
3. tdd-team 사이클 그대로, 단 단계 에이전트 실행만 바꿈:
   {phase}-prompt.md 작성 → /clear → 워치독 갱신 → 워커에 한 줄 지시
   → 워커가 tdd-team reference대로 수행, result·status 파일 작성 후 codex queue 신호
   → Codex가 status를 envelope로 읽고 tdd-team 분기대로 진행, 사이클 리뷰는 tdd-team대로 Codex 서브에이전트
4. tdd-team Final Review(Codex 서브에이전트) + Session End → cmux 알림, 결과 보고 (커밋 없음)
```

## 워커별 권한

| 워커 | 편집 권한 | 이유 |
|---|---|---|
| RED | 전체 | 테스트와 컴파일용 스텁(`UnsupportedOperationException`)을 함께 작성 |
| GREEN, REFACTOR | 전체, 단 **테스트 파일 거부**(`--disallowedTools 'Edit(<테스트 경로>)'`) | 테스트를 고쳐서 통과시키는 편법을 권한으로 차단 |

테스트 경로는 tdd-team Setup이 감지한 `TEST_DIR`, 소스와 섞여 있으면 `**/test_*.py` 같은 파일 이름 패턴으로 지정합니다.

## 결과 파일 위치

tdd-team의 `.tdd-team/`을 그대로 씁니다. 하네스 전용 파일은 `.tdd-team/harness/`에 둡니다.

```
{프로젝트루트}/.tdd-team/
├── context.md, session.md          tdd-team 그대로
├── task-01/
│   ├── task.md, diff.md, review.md  tdd-team 그대로 (review.md는 Codex 리뷰어 서브에이전트가 작성)
│   ├── red-prompt.md                워커에게 보낸 프롬프트
│   ├── red-result.md, red-status.md 워커의 결과와 envelope
│   └── green-result.attempt1.md     재지시 전 결과 (덮어쓰지 않고 보존)
└── harness/  harness.md, watchdog.sh, current
```

Codex의 리뷰가 무엇을 잡아냈는지는 `review.md`와 `*.attemptN.md`에 남습니다.

## 알아둘 점

- 오케스트레이터는 `cmux new-split`/`new-surface --command`로 샌드박스 밖 명령을 실행할 수 있습니다(워치독 탭이 이 방식). 그래서 샌드박스는 결정적인 경계가 아니고, 정책에서 cmux 사용 범위를 하네스 용도로 제한합니다.
- tdd-team의 특정 섹션(단계 에이전트 실행, 피드백 주기)을 이름으로 짚어 대체합니다. tdd-team의 해당 부분 구조가 크게 바뀌면 이 스킬도 맞춰야 합니다.

## 관련 스킬

- [tdd-team](./tdd-team.md) — TDD 규칙의 원본
- [plan-creator](./plan-creator.md), [spec-creator](./spec-creator.md) — 입력 계획 문서 작성 (이 스킬 실행 전에 따로)
- [cmux](./cmux.md) — pane 제어 기반
