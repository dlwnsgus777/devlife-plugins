# pdf-to-spec

PDF 파일에서 텍스트를 추출한 뒤 spec-creator 워크플로우를 실행합니다.  
macOS Vision/PDFKit으로 일반 PDF와 스캔본(OCR) 모두 처리합니다.

## 언제 사용하나요?

- 기획 문서, 요구사항 PDF를 바탕으로 Spec 문서를 작성할 때
- 스캔된 이미지 PDF도 한국어/영어 OCR로 처리하고 싶을 때
- PDF 내용을 코드베이스 분석과 연결해 Spec 문서로 만들고 싶을 때

## 트리거 문구

```
"PDF 분석해줘"
"PDF 요구사항 추출해줘"
"PDF 보고 spec 만들어줘"
"이 PDF로 요구사항 정리해줘"
"PDF 파일 분석해서 저장해줘"
```

## 실행 흐름

1. **PDF 경로 확인** — 경로 미제공 시 먼저 물어봄
2. **텍스트 추출** — `scripts/extract_pdf.swift` 실행
   - PDFKit 우선 (텍스트 레이어 있는 일반 PDF)
   - Vision OCR 폴백 (스캔본·이미지 PDF, 한국어+영어 인식)
3. **요약 및 확인** — 전체 텍스트 대신 핵심 내용 요약 후 사용자 확인
4. **spec-creator 실행** — PDF 내용을 배경 컨텍스트로 spec-creator 워크플로우 진행
5. **Spec 문서 저장** — 완성된 파일 경로 안내

> PDF가 요구사항의 주된 출처이므로, 코드베이스 탐색은 보조로만 활용합니다.

## 워크플로우 위치

```
pdf-to-spec  ← 현재 위치
     ↓
spec-creator (기술 명세 + 하위 작업 분해)
     ↓
plan-creator (태스크별 구현 계획)
     ↓
tdd-team (TDD 실행)
```

## 관련 스킬

- [spec-creator](./spec-creator.md) — PDF 내용을 입력으로 실행되는 워크플로우
- [plan-creator](./plan-creator.md) — Spec 완성 후 각 태스크의 구현 계획 작성
