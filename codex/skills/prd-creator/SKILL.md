---
name: prd-creator
description: Writes a PRD (Product Requirements Document) for large-scale features or initiatives,
  breaking them down into sub-tasks that can each be planned with plan-creator.
  Use when the user needs to plan a large feature with multiple sub-tasks, wants to define
  the overall scope and direction before diving into individual task plans, or wants a
  structured breakdown of work that spans multiple development sessions.
  Trigger on "PRD 작성해줘", "전체 계획 세워줘", "기능 전체 계획", "에픽 계획",
  "큰 기능 계획", "prd 만들어줘", "작업 목록 정리해줘",
  or any Korean sentence combining a large feature description with planning intent
  ("전체", "에픽", "큰 작업", "여러 단계") and a writing verb
  ("작성", "정리", "만들어", "세워줘").
---

# PRD Creator

## 목적

큰 규모의 기능이나 이니셔티브를 위한 PRD 문서를 작성합니다.
PRD는 `plan-creator`의 상위 레이어로, 전체 배경·목표·범위를 정의하고
각 하위 작업(sub-task)을 목록화합니다.

**워크플로우**:
```
prd-creator (전체 계획) → plan-creator (각 task 상세 계획) → 구현
```

---

## Process

### Step 1: 코드베이스 탐색

관련 모듈의 기존 코드를 먼저 스캔합니다.
- 영향받을 도메인, 서비스, 컨트롤러 파악
- 기존 패턴과 아키텍처 스타일 파악
- 현재 상태와 목표 상태의 GAP 파악

이를 통해 질문을 구체적이고 의미있게 만듭니다.

### Step 2: 정보 수집 질문

**질문 전에 코드 탐색을 완료하세요.** `AskUserQuestion`으로 **한 번에** 4-6개 질문을 합니다.
모든 질문은 한국어로 작성합니다.

필수 질문 항목:
- **배경 및 목표**: 이 작업이 왜 필요한가? 어떤 문제를 해결하는가?
- **도메인 문맥**: 이 기능이 속한 도메인의 핵심 개념, 전제, 제약사항은? (예: 상태 머신 구조, 멀티테넌시 요구사항, 외부 시스템 의존성)
- **비즈니스 불변성**: 구현 전 과정에서 절대 깨져서는 안 되는 규칙이 있는가? (예: "결제 완료 후 금액 변경 불가", "사용자당 활성 구독 하나")
- **범위**: 이번에 다룰 것과 다루지 않을 것
- **하위 작업 분해**: 어떻게 쪼갤 수 있는가? 의존 관계는?
- **기술 방향**: 특정 접근 방식이나 제약사항이 있는가?
- **우선순위**: 가장 먼저 시작해야 하는 작업은?
- **성공 기준**: 전체 작업이 완료됐다고 볼 수 있는 조건은?

답변을 받기 전까지 문서를 작성하지 마세요.

### Step 3: PRD 문서 작성

**파일 명명 규칙**:
- 사용자가 파일명을 지정한 경우: 그 이름 사용
- 지정하지 않은 경우: `prd-{feature}.md` 형식 (예: `prd-payment-refund.md`, `prd-user-auth.md`)

**파일 위치**: 프로젝트 루트 (현재 작업 디렉토리)에 저장.
별도 경로를 지정하지 않는 한 서브디렉토리 생성 금지.

`assets/prd-template.md` 템플릿을 읽고 모든 섹션을 채웁니다.

#### 도메인 문맥 및 불변성

**도메인 문맥**은 **산문 문장**으로 작성해야 합니다 (불릿 포인트 금지).
이 도메인을 처음 접하는 독자가 이 문장만으로 기능의 배경을 이해할 수 있어야 합니다.

**비즈니스 불변성**은 **완성된 선언 문장**으로 작성해야 합니다:
"X이면 Y는 반드시 성립해야 한다" / "W인 경우 Z는 절대 허용되지 않는다".
가능하면 불변성이 깨졌을 때 어떤 문제가 발생하는지도 명시합니다.

> 나쁜 예: `결제 후 금액 변경 불가`
> 좋은 예: `결제 완료 상태로 전환된 주문의 금액은 어떠한 경우에도 변경될 수 없다. 이를 허용하면 정산 불일치와 회계 감사 실패로 이어진다.`

코드베이스 탐색 중 발견한 도메인 규칙(enum 값, 유효성 검사 로직, 주석)도 불변성으로 포착합니다.

#### 하위 작업 분해 원칙

각 sub-task는 다음 기준을 만족해야 합니다:
- **독립성**: 가능한 한 다른 task와 독립적으로 구현 가능
- **명확성**: `plan-creator`가 바로 상세 계획을 작성할 수 있을 만큼 구체적
- **적정 크기**: 하나의 개발 세션(반나절~하루)에서 완료 가능한 규모
- **검증 가능**: 완료 기준이 명확함

#### 복잡도 기준

| 복잡도 | 기준 |
|--------|------|
| S (Small) | 단일 파일 수정, 3시간 이내 |
| M (Medium) | 2-5개 파일, 반나절~하루 |
| L (Large) | 여러 모듈, 하루 이상 |

L 크기 task는 더 작은 단위로 분해를 검토하세요.

### Step 4: 피드백 요청 (필수)

문서 작성 후 반드시 `AskUserQuestion`으로 확인합니다:

> "PRD 문서를 작성했습니다. 수정하거나 보완할 부분이 있으신가요?
> 특히 [하위 작업 분해 방식 / 범위 정의 / 우선순위]에 대한 의견을 주시면 반영하겠습니다."

명시적 승인 없이 구현 단계로 진행하지 마세요.

### Step 5: 다음 단계 안내

피드백을 반영하고 승인이 나면, 다음 사용 방법을 안내합니다:

```
PRD가 완성되었습니다. 이제 각 task를 시작할 때:

1. "[T1 작업명] 계획 작성해줘" → plan-creator가 상세 계획 생성
2. 계획 검토 후 구현 시작
3. 완료 후 PRD의 "작업 진행 현황" 테이블 업데이트

현재 권장 시작 task: T1 - [작업명]
```
