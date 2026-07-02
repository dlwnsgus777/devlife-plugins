# devlife-brainstorming

막연한 아이디어를 구체적인 설계 결정으로 전환합니다.  
What/Why에 집중하고, How(구현 방법)는 spec-creator와 plan-creator에 위임합니다.

## 언제 사용하나요?

- 아이디어는 있지만 무엇을 어떻게 만들어야 할지 불명확할 때
- 기능의 범위, 대상 사용자, 성공 기준을 먼저 정리하고 싶을 때
- spec-creator로 넘어가기 전에 방향을 잡고 싶을 때

## 트리거 문구

```
"브레인스토밍"
"아이디어 정리"
"기능 구상"
"뭘 만들지 정리해줘"
"아이디어 탐색"
"기획 정리"
```

## 실행 흐름

1. **프로젝트 컨텍스트 스캔** — 최근 커밋, 기존 spec/plan 문서 파악 (사용자에게 보고하지 않음)
2. **대화형 탐색** — 핵심 문제, 대상 사용자, 성공 기준, 범위, 설계 결정, 제약사항을 **한 번에 하나씩** 질문
3. **방향 선택지 제시** — 2-3가지 설계 방향과 트레이드오프 제시, 추천 방향 안내
4. **Brainstorming 문서 작성** — `brainstorming-{topic}.md` 생성 (프로젝트 루트)
5. **자체 검토 및 피드백** — 빈 섹션, 모순, 과도한 범위 확인 후 사용자 피드백 수집

## 생성 문서 구조

```
brainstorming-{topic}.md
├── Core Problem        ← 이 기능이 해결하는 문제 (2-3문장)
├── Target Users        ← 누가, 어떤 상황에서 사용하는가
├── Success Criteria    ← 잘 만들었다는 것을 어떻게 판단하는가
├── Scope               ← In / Out 명시
├── Key Design Decisions ← 선택한 방향과 트레이드오프
└── Constraints         ← 기술/일정/비즈니스 제약 (해당 시)
```

## 핵심 원칙

- **What/Why만** — 구현 방법(How)은 spec-creator와 plan-creator의 영역
- **한 번에 하나씩** — 여러 질문을 한 메시지에 묶지 않음
- **추측하지 않음** — 불명확하면 묻고, 빈칸을 채우지 않음
- **YAGNI** — 사용자가 언급하지 않은 범위는 추가하지 않음

## 워크플로우 위치

```
devlife-brainstorming  ← 현재 위치
        ↓
  spec-creator (기술 명세 + 하위 작업 분해)
        ↓
  plan-creator (태스크별 구현 계획)
        ↓
    tdd-team (TDD 실행)
```

## 관련 스킬

- [spec-creator](./spec-creator.md) — brainstorming 문서를 입력으로 받아 기술 명세 작성
- [grill-me](./grill-me.md) — 정해진 방향을 검증하고 싶을 때
