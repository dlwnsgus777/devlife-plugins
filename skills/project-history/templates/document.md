# {{TICKET_KEY}}: {{TITLE}}

**기간:** {{PERIOD}}
**상태:** {{STATUS}}
**역할:** {{ROLE}}
**Jira:** {{JIRA_URL}}

---

## 기능 개요

{{FEATURE_OVERVIEW}}

---

## 도메인 모델 설계

### 핵심 엔티티

{{ENTITIES}}

### 값 객체 (VO)

| VO | 설명 |
|----|------|
{{VO_TABLE}}

{{#if MIGRATION_OBJECTS}}
### 마이그레이션 / 기타 도메인 객체

| 클래스 | 설명 |
|--------|------|
{{MIGRATION_TABLE}}
{{/if}}

---

## 아키텍처

### 계층 구조

```
{{LAYER_STRUCTURE}}
```

### 주요 패턴

{{PATTERNS}}

---

## 티켓별 구현 내용

{{TICKET_DETAILS}}

---

## 기술적 도전 포인트

{{TECHNICAL_CHALLENGES}}

---

## 이력서 작성 포인트

### 한 줄 요약
> {{ONE_LINE_SUMMARY}}

*용도: 경력 기술서의 '주요 프로젝트' 또는 자기소개서 한 줄 설명*

### 주요 업무 bullet points

{{RESUME_BULLETS}}

*용도: 경력 기술서의 '담당 업무' 항목에 그대로 붙여넣기*

### 사용 기술

`{{TECH_STACK}}`

### 면접 대비 포인트

{{INTERVIEW_POINTS}}

### 주의할 점

{{CAUTIONS}}

---

## 변경 규모

| 모듈 | 변경 파일 수 |
|------|------------|
{{CHANGE_SCALE_TABLE}}

관련 브랜치: {{BRANCH_COUNT}}개 이상 / 총 커밋: {{COMMIT_COUNT}}개 이상
