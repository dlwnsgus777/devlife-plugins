# plan-creator 1.x vs 2.0 — tdd-agent-team 품질 비교

같은 프로젝트와 같은 요구사항에 이전 계획(파일 1개)과 새 계획(작업 폴더)을 넣고 tdd-agent-team을 돌려 비교한다.

## 준비

1. 계획 만들기 — 각각 새 세션에서 한 번씩 만들고 아래에 고정 저장한다. 확인 질문에는 추천안으로 답한다.
   - 이전: `bash fixture.sh {scratch}/plan-old` → 그 폴더에서 설치된 플러그인(plan-creator 1.14.1)으로 "REQUIREMENTS.md로 계획 작성해줘" → 결과를 `old/`에 복사
   - 새: `bash fixture.sh {scratch}/plan-new` → 그 폴더에서 `claude --plugin-dir <이 레포>`(plan-creator 2.0.0)로 같은 요청 → `docs/spec/...` 폴더를 `new/`에 복사
2. 실행 프로젝트 — 회차마다 새로 만든다: `bash fixture.sh {scratch}/run-old-1`, `{scratch}/run-new-1`, 2회차는 `-2`.
3. 고정한 계획을 실행 프로젝트에 같은 위치로 복사한다.

## 실행

- 각 실행 프로젝트에서 새 세션을 열고 tdd-agent-team에 계획 경로를 넘긴다.
- 확인 질문은 항상 추천안으로 답한다. 커밋 질문은 "커밋하지 않고 진행"으로 답한다.
- 끝나면 같은 세션에서 `tdd-retro`로 시간·토큰을 잰다.

## 채점

픽스처에 일부러 넣은 것:
- 함정: `FreeShippingPolicy`가 "5만원 이상"을 `>`로 비교한다. 5만원 주문이 유료 배송이 된다.
- 범위 밖: `PointCalculator`는 바꾸면 안 된다.
- 정비 대상: `MembershipDiscount`의 등급별 if/else에 VIP 케이스가 추가된다.

| # | 항목 | PASS 조건 | old-1 | old-2 | new-1 | new-2 |
|---|------|----------|-------|-------|-------|-------|
| 1 | 불변성 커버리지 | VIP 15%, 할인 상한 3만원(경계 200,000원 전후), VIP 무료 배송 3만원(경계 30,000원), 다른 등급 5만원 유지 — 각 규칙의 경계 테스트가 있다 | | | | |
| 2 | 함정 답습 없음 | VIP 무료 배송이 `>=`로 30,000원을 포함한다. 5만원 기준을 고쳤다면 이유가 계획에 있다 | | | | |
| 3 | 범위 지킴 | `git diff`에 `PointCalculator.java`가 없다 | | | | |
| 4 | 테스트 통과 | `./gradlew test --offline`이 성공한다 | | | | |
| 5 | 시간 | `tdd-retro` 총 소요 시간 | | | | |
| 6 | 토큰 | `tdd-retro` 총 토큰 | | | | |

## 결과

`result.md`에 표를 옮기고, 차이가 난 항목마다 원인이 된 계획 문서의 위치를 한 줄로 적는다.
