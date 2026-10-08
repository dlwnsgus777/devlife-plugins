# test-writing

테스트 코드를 **어떻게 쓰는지**에 대한 규칙 모음입니다.  
언어와 무관한 원칙에 Java(JUnit 5 + AssertJ) 예시를 붙였고, Python·TypeScript 대응표가 끝에 있습니다. 단독으로 호출할 수도 있고, `tdd-agent-team`의 `tdd-red`·`tdd-refactor` 팀원과 `review-test` 리뷰어가 이 파일을 직접 읽어 같은 규칙을 씁니다.

## 언제 사용하나요?

- 새 테스트를 작성하거나, 기존 코드에 테스트를 추가하거나, 테스트 코드를 수정할 때
- 테스트 이름·구조·Fixture 사용을 프로젝트 전체에서 같은 기준으로 맞추고 싶을 때

> 기능을 구현하기 **전에** 테스트부터 쓰는 과정 전체는 `test-driven-development`가 맡습니다. 이 스킬은 테스트 한 건의 모양만 다룹니다 — 언제 실행하고 어떤 순서로 진행하는지는 호출한 쪽(사용자 요청 또는 에이전트 정의)이 정합니다.

## 트리거 문구

```
"테스트 작성해줘"
"테스트 추가해줘"
"테스트 코드 수정해줘"
"테스트 짜줘"
"write tests"
"add a test"
```

## 실행 흐름

1. **프로젝트 컨벤션 확인** — 테스트 대상 옆의 기존 테스트에서 assertion 라이브러리·Fixture 이름·이름 규칙·주석 스타일을 확인합니다. 아래 예시와 다르면 프로젝트 규칙이 우선하고, 기존 테스트가 없으면 이 가이드를 따릅니다
2. **무엇을 테스트할지 정하기** — 시나리오를 먼저 모두 나열하고 하나씩 테스트로 만듭니다. 비즈니스 규칙마다 경계(어기는 경우·가장 가까운 지키는 경우·규칙이 말하는 모든 상태)를 다루고, 동작 없는 생성자·접근자·DTO는 테스트하지 않습니다
3. **테스트 작성**
   - 한 테스트에 한 동작
   - 같은 규칙은 한 테스트로 합치고(파라미터화), 다른 규칙은 나눔
   - 이름은 도메인 규칙 문장(`@DisplayName`)
   - arrange · act · assert 구조
   - 프로젝트 Fixture 사용
   - 계층별 전략 — Domain: 순수 단위 / Application: 저장소 mock / Infrastructure: 통합(Testcontainer) / Presentation: API 테스트(MockMvc)
4. **기존 테스트는 삭제하지 않습니다** — 명시적 허락이 있을 때만

## 관련 스킬

- [test-driven-development](./test-driven-development.md) — 구현 전 테스트 우선 과정
- [tdd-agent-team](./tdd-agent-team.md) — RED 팀원·`tdd-refactor`·`review-test`가 이 규칙을 읽음
