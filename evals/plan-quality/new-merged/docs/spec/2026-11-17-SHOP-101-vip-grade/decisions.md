# Decisions

### Dec-1. 등급별 규칙을 Grade enum으로 이동
영향도: significant · 출처: ai-suggested

문제 — VIP 할인과 VIP 무료배송 기준을 어떤 구조로 넣을지 정해야 했다.
옵션
  (A) `MembershipDiscount`의 if-else에 VIP 분기를, `FreeShippingPolicy`에 등급 분기를 추가
  (B) 등급별 할인율·할인 상한·무료배송 기준을 `Grade` enum 필드로 옮기고, `MembershipDiscount`·`FreeShippingPolicy`는 `Grade`에 위임
선택 — B
근거 — VIP 추가가 enum 상수 하나로 끝나고, if-else와 도달할 수 없는 `throw`가 사라진다. 사용자 부재로 추천안을 채택했다.
연관 설계 — Dec-2(같은 정비에서 경계 수정) · Dec-6(호출부 유지) · `Grade`, `MembershipDiscount`, `FreeShippingPolicy`

### Dec-2. 무료배송 기준은 "이상"(`>=`)으로 판단
영향도: significant · 출처: ai-suggested

문제 — `FreeShippingPolicy`는 `>`로 비교해 정확히 5만원이면 유료 배송이다. 요구사항과 코드 주석은 "5만원 이상"이라고 한다.
옵션
  (A) 코드대로 초과(`>`) 유지
  (B) 문서대로 이상(`>=`)으로 수정
선택 — B
근거 — 요구사항 문서와 코드 주석이 모두 "이상"이다. 정확히 5만원인 주문의 배송비가 3,000원에서 0원으로 바뀐다. 사용자 부재로 추천안을 채택했다.
연관 설계 — Dec-1(같은 정비 phase에서 반영) · `FreeShippingPolicy`

### Dec-3. 무료배송 판단 금액은 할인 전 주문 금액
영향도: local · 출처: ai-selected

문제 — VIP 3만원 기준을 할인 전 금액과 할인 후 금액 중 무엇에 적용할지 정해야 했다.
옵션
  (A) 할인 전 주문 금액 `order.amount()`
  (B) 할인 후 금액
선택 — A
근거 — 기존 `FreeShippingPolicy`가 `order.amount()`를 쓰고, 요구사항도 "주문 금액"이라고 한다.
연관 설계 — Dec-2 · `FreeShippingPolicy`

### Dec-4. VIP 할인액은 버림 후 30,000원 상한 적용
영향도: local · 출처: ai-selected

문제 — 15% 할인액의 끝전 처리와 상한 적용 순서를 정해야 했다.
옵션
  (A) 기존처럼 정수 나눗셈 버림(`amount * 15 / 100`) 후 `Math.min(할인액, 30_000)`
선택 — A
근거 — 기존 SILVER·GOLD 계산 방식과 같다.
연관 설계 — Dec-1 · `Grade`

### Dec-5. PointCalculator는 수정하지 않음
영향도: local · 출처: ai-selected

문제 — 요구사항은 "적립 포인트 계산은 바꾸지 않는다"이다. 포인트는 결제액에서 계산하므로 VIP 할인이 포인트 값에 영향을 준다.
옵션
  (A) `PointCalculator`를 그대로 두고, 결제액이 바뀌면 포인트 값도 그 결과로 바뀌게 둔다
선택 — A
근거 — 계산식(결제액의 1%)은 정산팀 배치가 의존하므로 손대지 않는다.
연관 설계 — 없음 · `PointCalculator`

### Dec-6. 기존 클래스와 호출부 유지
영향도: local · 출처: ai-selected

문제 — 규칙을 `Grade`로 옮긴 뒤 `MembershipDiscount`·`FreeShippingPolicy`를 없앨지 정해야 했다.
옵션
  (A) 두 클래스를 유지하고 `Grade`에 위임
  (B) 두 클래스를 없애고 `Checkout`이 `Grade`를 직접 호출
선택 — A
근거 — `Checkout`과 기존 테스트가 바뀌지 않아 이번 변경 범위가 가장 작다.
연관 설계 — Dec-1 · `Checkout`, `MembershipDiscount`, `FreeShippingPolicy`
