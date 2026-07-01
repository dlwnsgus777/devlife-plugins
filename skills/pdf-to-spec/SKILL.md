---
name: pdf-to-spec
description: PDF 파일을 받아 macOS Vision/PDFKit으로 텍스트를 추출한 뒤, spec-creator 워크플로우로 요구사항을 분석하고 Spec 문서로 저장한다.
  Use when the user uploads or provides a PDF file path and wants requirements extracted, analyzed, or documented.
  Trigger on "PDF 분석해줘", "PDF 요구사항 추출해줘", "PDF 올릴게", "PDF 보고 spec 만들어줘",
  "이 PDF로 요구사항 정리해줘", "PDF 파일 분석해서 저장해줘",
  or whenever a user provides a .pdf file path with any intent to extract, analyze, or document its content.
  Also trigger when the user pastes or mentions a PDF path and says 분석, 정리, spec, PRD, 요구사항, 기획.
---

# PDF → Spec 변환 스킬

PDF에서 텍스트를 추출(macOS Vision / PDFKit)한 뒤,
`spec-creator` 워크플로우를 통해 요구사항을 분석하고 Spec 문서를 생성한다.

---

## Step 1: PDF 경로 확인

사용자가 PDF 경로를 명시하지 않았다면 **먼저 경로를 물어본다.**

```
어떤 PDF 파일을 분석할까요? 전체 경로를 알려주세요.
예: /Users/finn/Downloads/requirements.pdf
```

경로가 있으면 파일이 실제 존재하는지 Bash로 확인한다.

---

## Step 2: macOS API로 텍스트 추출

이 스킬의 Swift 스크립트를 사용한다.
스크립트 경로: 이 SKILL.md와 같은 디렉토리의 `scripts/extract_pdf.swift`

```bash
swift <SKILL_DIR>/scripts/extract_pdf.swift "<pdf_path>"
```

- `<SKILL_DIR>`은 이 SKILL.md가 위치한 디렉토리 절대경로
- 내부 동작:
  - **PDFKit** 우선 — 텍스트 레이어가 있는 일반 PDF
  - **Vision OCR** 폴백 — 스캔본·이미지 PDF (한국어+영어 인식)

추출 결과를 변수로 보관한다. 페이지별로 구분된 전체 텍스트가 반환된다.

---

## Step 3: 추출 내용 요약 및 사용자 확인

추출된 텍스트 전체를 바로 보여주지 말고, **핵심 내용을 요약**해서 먼저 보여준다.

```
[PDF 분석 완료] requirements.pdf
- 총 N페이지
- 주요 내용: [2-3문장 요약]
- 발견된 핵심 요구사항 섹션: [목록]

이 내용을 바탕으로 Spec을 작성할까요?
```

사용자가 확인하면 Step 4로 진행한다.

---

## Step 4: spec-creator 워크플로우 실행

추출된 PDF 내용을 **배경 문맥(context)으로 삼아** `spec-creator` 스킬의 프로세스를 그대로 따른다.

**중요 차이점**: spec-creator는 보통 코드베이스를 먼저 탐색하지만,
이 스킬은 PDF가 요구사항의 주된 출처이므로 **PDF 내용을 우선**하고
코드베이스 탐색은 보조로만 활용한다.

`spec-creator` 워크플로우를 시작하기 위해 Skill 도구로 `spec-creator`를 호출한다.
이때 PDF에서 추출된 텍스트를 충분한 배경 컨텍스트로 제공한다.

---

## Step 5: Spec 문서 저장

`spec-creator` 워크플로우가 완료되면 생성된 Spec 파일 경로를 사용자에게 알린다.

```
Spec 문서가 저장되었습니다: spec-[기능명].md
다음 단계: 각 Task를 시작할 때 "plan-creator"로 상세 계획을 작성하세요.
```
