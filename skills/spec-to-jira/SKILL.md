---
name: spec-to-jira
description: Spec 마크다운 문서를 읽어 Jira 티켓 하나를 생성하는 내부 스킬. spec-workflow 오케스트레이터 또는 /spec-to-jira 명시적 호출로만 사용한다. 자연어 트리거 없음.
disable-model-invocation: true
---

# Spec → Jira 티켓 생성

## 목적

Spec 문서 한 장을 Jira 티켓 **하나**로 만든다.
체크리스트 항목별로 나누지 않는다. Spec 전체가 한 티켓의 내용이 된다.

---

## 프로세스

### Step 1: Spec 내용 확인

다음 우선순위로 Spec 내용을 결정한다:

1. **이번 대화에서 Spec을 작성했거나 검토한 경우** → 해당 내용을 그대로 사용한다. 파일을 별도로 읽지 않는다.
2. **args 또는 메시지에 파일 경로가 명시된 경우** → 그 파일을 읽는다.
3. **위 두 경우 모두 아닌 경우** → 사용자에게 Spec 파일 경로를 물어본다. 자동 탐색하지 않는다.

파일을 읽었다면 **어떤 파일을 사용했는지 사용자에게 알린다**.

### Step 2: Spec 파싱

Spec에서 다음을 추출한다:

| 추출 항목 | Jira 필드 | 추출 위치 |
|-----------|-----------|-----------|
| 제목 | Summary (티켓 제목) | `# Spec: ...` 또는 첫 번째 H1 |
| 배경 + 목표 + 전체 본문 | Description | Spec 전문 (마크다운 그대로) |
| 인수 조건 | Description 하단 추가 | `## 인수 조건` 또는 `## 전체 인수 조건` 섹션 |

### Step 3: 사용자 확인 (AskUserQuestion)

다음 세 가지를 한 번에 물어본다.

**질문 1 — 이슈 유형**
- Epic
- Story
- Task
- Sub-task (하위 작업)

**질문 2 — 상위 티켓 (선택)**
이슈 유형이 Sub-task이거나, 사용자가 "하위 작업"임을 명시한 경우에만 물어본다.
예: "부모 티켓 키를 입력해 주세요 (예: RB-2200)"

### Step 4: 이슈 타입 ID 조회

프로젝트는 항상 **`RB` (heyratel.atlassian.net)** 로 고정된다. 사용자에게 프로젝트를 묻지 않는다.

`mcp__claude_ai_Atlassian__getJiraProjectIssueTypesMetadata`로 `RB` 프로젝트의 실제 이슈 타입 ID를 가져온다.
사용자가 선택한 유형 이름(Epic/Story/Task/Sub-task)과 매칭해서 ID를 확인한다.

### Step 5: 티켓 생성 전 최종 확인

생성 전에 다음을 텍스트로 요약해 보여주고 확인을 받는다:

```
[생성 예정 티켓]
- 프로젝트: RB (heyratel.atlassian.net)
- 이슈 유형: Story
- 제목: 정기 배송 기능 수정
- 부모 티켓: RB-2200 (해당하는 경우만)
- Description: Spec 전문 포함

생성할까요?
```

### Step 6: 티켓 생성

`mcp__claude_ai_Atlassian__createJiraIssue`로 티켓을 생성한다.

필드 매핑:
```json
{
  "project": { "key": "<선택한 프로젝트 키>" },
  "summary": "<Spec 제목>",
  "issuetype": { "id": "<조회한 이슈 타입 ID>" },
  "description": {
    "type": "doc",
    "version": 1,
    "content": [{ "type": "paragraph", "content": [{ "type": "text", "text": "<Spec 전문>" }] }]
  },
  "parent": { "key": "<부모 티켓 키>" }  // Sub-task인 경우만
}
```

### Step 7: 결과 출력

생성된 티켓 정보를 출력한다:

```
✅ Jira 티켓 생성 완료

티켓: RB-2300
제목: 정기 배송 기능 수정
유형: Story
URL: https://...atlassian.net/browse/RB-2300
부모: RB-2200 (해당하는 경우만)
```

---

## 주의사항

- Spec 체크리스트 항목별로 여러 티켓을 만들지 않는다. **Spec 한 장 = 티켓 하나**.
- Spec이 너무 커서 여러 작업으로 나눠야 한다면, 사용자가 직접 "하위 작업"이라고 말할 때만 Sub-task로 처리한다.
- Description은 Spec 원문 마크다운을 가능한 그대로 담는다. Jira가 ADF(Atlassian Document Format)를 요구하면 plain text로 변환해도 무방하다.
- 이슈 타입 ID는 프로젝트마다 다르므로 반드시 `getJiraProjectIssueTypesMetadata`로 조회 후 사용한다.
