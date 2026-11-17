# Decisions

### Dec-1. 등급별 할인 구조 — if-else를 switch expression으로 정비한 뒤 VIP 추가
영향도: significant · 출처: ai-selected

문제 — VIP 할인을 `MembershipDiscount.discount()`에 어떤 구조로 넣을지 정해야 했다.
옵션
  (A) 지금 구조 유지 — if-else 체인에 VIP 분기를 추가한다.
  (B) if-else 체인을 `Grade` switch expression으로 바꾼 뒤 VIP case를 추가한다.
  (C) 할인율·할인 한도·무료 배송 기준을 `Grade` enum 필드로 옮긴다.
선택 — B
근거 — 등급을 빠뜨리면 컴파일 오류가 나서 런타임 `IllegalArgumentException` 분기가 사라지고, VIP에만 있는 한도를 모든 등급의 필드로 만들 필요가 없다.
연관 설계 — Dec-3(VIP case 본문) · `MembershipDiscount`
비고 — 사용자 부재로 AI가 추천안을 대신 골랐다. 사용자 검토가 필요하다.

### Dec-2. 무료 배송 경계를 "이상"(`>=`)으로 고친다
영향도: significant · 출처: ai-selected

문제 — `FreeShippingPolicy.isFree()`는 `amount > 50_000`이지만 요구사항과 코드 주석은 "5만원 이상"이다.
옵션
  (A) 이번 티켓에서 `>=`로 고친다.
  (B) 기존 동작(`>`)을 유지하고 VIP만 `>=`로 만든다.
  (C) 후속 티켓으로 분리한다.
선택 — A
근거 — 요구사항 문서·주석이 모두 "이상"이고, 같은 메서드에서 등급마다 경계 비교가 달라지면 안 된다.
연관 설계 — Dec-6(같은 메서드 수정) · `FreeShippingPolicy`
비고 — 5만원 정각 주문의 배송비가 3,000원에서 0원으로 바뀐다. 사용자 검토가 필요하다.

### Dec-3. VIP 할인액 = min(주문 금액 × 15 / 100, 30,000)
영향도: local · 출처: ai-selected

문제 — VIP 할인율과 한도를 어떻게 계산할지 정해야 했다.
옵션
  (A) `Math.min(amount * 15 / 100, 30_000)` — 원 미만은 기존 등급처럼 정수 나눗셈으로 버린다.
  (B) 반올림 후 한도 적용.
선택 — A
근거 — 기존 SILVER·GOLD와 같은 버림 방식을 따른다.
연관 설계 — Dec-1(VIP case 위치) · `MembershipDiscount`

### Dec-4. 무료 배송 판단 금액은 할인 전 주문 금액
영향도: local · 출처: ai-selected

문제 — VIP 무료 배송 기준 3만원을 할인 전과 할인 후 중 어느 금액으로 비교할지 정해야 했다.
옵션
  (A) 할인 전 `order.amount()`
  (B) 할인 후 금액
선택 — A
근거 — 요구사항이 "주문 금액"이라고 하고 기존 `FreeShippingPolicy`도 `order.amount()`를 쓴다.
연관 설계 — Dec-6 · `FreeShippingPolicy`

### Dec-5. 적립 포인트는 `PointCalculator`를 그대로 쓴다
영향도: local · 출처: ai-selected

문제 — "적립 포인트 계산은 바꾸지 않는다"가 VIP 주문에 어떻게 적용되는지 정해야 했다.
옵션
  (A) `PointCalculator`(결제 금액의 1%)를 그대로 두고, VIP는 할인 후 결제 금액 기준으로 적립한다.
  (B) VIP는 할인 전 금액 기준으로 적립한다.
선택 — A
근거 — 정산팀 배치가 이 계산에 의존한다는 주석이 있고, B는 계산 방식 변경이다.
연관 설계 — 없음 · `PointCalculator`, `Checkout`

### Dec-6. 등급별 무료 배송 기준은 `FreeShippingPolicy` 안에 둔다
영향도: local · 출처: ai-selected

문제 — VIP 무료 배송 기준 3만원을 어디에 둘지 정해야 했다.
옵션
  (A) `FreeShippingPolicy`에 VIP 기준 상수를 추가하고 등급에 따라 기준을 고른다.
  (B) `Grade` enum에 기준 금액 필드를 둔다.
선택 — A
근거 — 무료 배송 규칙이 이미 이 클래스에 모여 있고, 등급별로 다른 값은 VIP 하나뿐이다.
연관 설계 — Dec-2, Dec-4 · `FreeShippingPolicy`
