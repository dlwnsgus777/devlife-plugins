---
name: spec-workflow
description: Spec 작성 완료 후 Jira 티켓 생성 → Git 브랜치 생성까지 전체 플로우를 오케스트레이션합니다.
  Trigger on "jira 티켓 만들어줘", "지라 티켓 생성해줘", "spec으로 티켓 만들어", "티켓 올려줘", "jira에 올려줘",
  "이 spec 지라로", "브랜치 만들어줘", "브랜치 생성해줘", "branch 만들어줘", "RB-XXXX 브랜치",
  "티켓이랑 브랜치 만들어줘", "spec-workflow", "/spec-workflow" —
  또는 Spec(PRD)을 언급하면서 Jira 티켓이나 브랜치 생성을 요청할 때.
---

# Spec Workflow (오케스트레이터)

## 플로우 개요

```
[Phase 1] Spec → Jira 티켓 생성   ← 항상 실행
    ↓ 사용자 확인
[Phase 2] Jira 티켓 → Git 브랜치  ← 확인 후 로드
```

---

## Phase 1: Spec → Jira 티켓 생성

### 1-1. Spec 내용 확인

다음 우선순위로 Spec 내용을 결정한다:
1. 이번 대화에서 Spec을 작성했거나 검토한 경우 → 해당 내용을 그대로 사용
2. args 또는 메시지에 파일 경로가 명시된 경우 → 그 파일을 읽는다
3. 위 두 경우 모두 아닌 경우 → 사용자에게 Spec 파일 경로를 물어본다

파일을 읽었다면 어떤 파일을 사용했는지 사용자에게 알린다.

### 1-2. Spec 파싱

| 추출 항목 | Jira 필드 | 추출 위치 |
|-----------|-----------|-----------|
| 제목 | Summary | `# Spec: ...` 또는 첫 번째 H1 |
| 배경 + 목표 + 전체 본문 | Description | Spec 전문 (마크다운 그대로) |
| 인수 조건 | Description 하단 | `## 인수 조건` 섹션 |

### 1-3. 사용자 확인 (AskUserQuestion)

**질문 1 — 이슈 유형**: Epic / Story / Task / Sub-task

**질문 2 — 상위 티켓** (Sub-task 선택 시에만): 부모 티켓 키 입력 (예: RB-2200)

### 1-4. 이슈 타입 ID 조회

프로젝트는 **`RB` (heyratel.atlassian.net)** 고정.
`mcp__claude_ai_Atlassian__getJiraProjectIssueTypesMetadata`로 RB 프로젝트의 이슈 타입 ID를 조회한다.

### 1-5. 티켓 생성 전 최종 확인

```
[생성 예정 티켓]
- 프로젝트: RB (heyratel.atlassian.net)
- 이슈 유형: Story
- 제목: 정기 배송 기능 수정
- 부모 티켓: RB-2200 (해당하는 경우만)
- Description: Spec 전문 포함

생성할까요?
```

### 1-6. 티켓 생성

`mcp__claude_ai_Atlassian__createJiraIssue`로 티켓을 생성한다.

```json
{
  "project": { "key": "RB" },
  "summary": "<Spec 제목>",
  "issuetype": { "id": "<조회한 이슈 타입 ID>" },
  "description": {
    "type": "doc",
    "version": 1,
    "content": [{ "type": "paragraph", "content": [{ "type": "text", "text": "<Spec 전문>" }] }]
  },
  "parent": { "key": "<부모 티켓 키>" }
}
```

### 1-7. Phase 1 결과 출력 + Phase 2 진입 여부 확인

```
✅ Jira 티켓 생성 완료

티켓: RB-2300
제목: 정기 배송 기능 수정
유형: Story
URL: https://heyratel.atlassian.net/browse/RB-2300
```

출력 후 사용자에게 묻는다:
> "브랜치도 바로 생성할까요?"

- **예** → Phase 2 진입: `skills/jira-to-branch/SKILL.md`를 읽고 해당 프로세스를 따른다.
  Phase 1에서 생성된 티켓 키를 Step 1의 티켓 키로 바로 사용한다 (별도 입력 불필요).
- **아니오** → 플로우 종료.

---

## 주의사항

- Spec 체크리스트 항목별로 여러 티켓을 만들지 않는다. **Spec 한 장 = 티켓 하나**.
- Phase 1 실패 시 Phase 2로 넘어가지 않는다.
- Description은 Spec 원문 마크다운을 가능한 그대로 담는다. ADF 요구 시 plain text 변환 허용.
- 이슈 타입 ID는 반드시 `getJiraProjectIssueTypesMetadata`로 조회 후 사용한다.
