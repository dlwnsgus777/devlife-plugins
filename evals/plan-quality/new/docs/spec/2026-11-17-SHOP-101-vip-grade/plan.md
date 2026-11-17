# VIP 등급 추가 (SHOP-101)

base: master

> 새 등급 VIP에 15% 할인과 3만원 이상 무료 배송을 적용한다.

---

## 1. Context

### 배경

회원 등급(`Grade`)에 따라 주문 할인액과 무료 배송 여부가 정해진다. 결제(`Checkout`)는 할인액과 배송비로 결제 금액을 정한다. 적립 포인트는 결제 금액으로 계산한다. 이번 작업은 BASIC·SILVER·GOLD에 VIP 등급을 더한다.

### 외부 제약

- 적립 포인트 계산(`PointCalculator`)은 바꾸지 않는다. 정산팀 배치가 이 계산에 의존한다.

### 도메인 불변성

| 불변성 | 위반 시 영향 | 출처 |
|-------|------------|------|
| VIP 주문은 주문 금액의 15%를 할인한다. | 결제 금액이 요구사항과 달라진다. | `[문서]` |
| VIP 할인은 한 주문에 3만원을 넘지 않는다. | 20만원 초과 주문에서 과다 할인이 생긴다. | `[문서]` |
| VIP 주문은 주문 금액이 3만원 이상이면 배송비가 0원이다. | VIP에게 배송비가 잘못 청구된다. | `[문서]` |
| VIP가 아닌 등급의 주문은 주문 금액이 5만원 이상이면 배송비가 0원이다. | 5만원 정각 주문에 배송비 3,000원이 청구된다. | `[문서]` |
| 적립 포인트는 결제 금액의 1%다. | 정산팀 배치의 포인트 집계가 실제 적립과 어긋난다. | `[코드추론]` |

### 기존 패턴

- 등급별 할인은 `MembershipDiscount.discount(Order)`가 계산한다. 원 미만은 정수 나눗셈으로 버린다. — `src/main/java/shop/MembershipDiscount.java`
- 무료 배송 판단은 `FreeShippingPolicy.isFree(Order)`가 할인 전 `order.amount()`로 한다. — `src/main/java/shop/FreeShippingPolicy.java`
- 정책 클래스는 모두 `shop` 패키지에 있다. `Checkout`이 필드로 직접 생성한다.

---

## 2. Scope

- **In**: `Grade.VIP` 추가, VIP 할인율 15%와 한도 3만원, VIP 무료 배송 기준 3만원, 무료 배송 경계를 "이상"으로 수정(Dec-2)
- **Out**: 할인·배송 기준을 `Grade` enum 필드로 옮기는 구조 변경. VIP 외 등급이 기준을 따로 갖게 될 때 다시 판단한다. → 7-1
- **Out**: VIP 등급 부여·승급 규칙. 요구사항에 없다. → 7-2

---

## 3. Plan

| Phase | 목표 | 완료 기준 | 상태 |
|-------|-----|---------|-----|
| 1 | `MembershipDiscount`의 if-else를 `Grade` switch expression으로 정비 (Tidy First, Dec-1) | 4-1 통과, 동작 변경 없음 | todo |
| 2 | VIP 할인 15%와 한도 3만원 | 4-2 통과 | todo |
| 3 | 무료 배송 경계 "이상" 수정과 VIP 기준 3만원 | 4-3 통과 | todo |
| 4 | VIP 결제 영수증 확인 | 4-4 통과 | todo |

> 상태는 `todo` / `doing` / `done` 중 하나다.

---

## 4. Verification

### 4-1. Phase 1

1. [ ] `[REGRESSION]` `MembershipDiscountTest` — `"BASIC 등급은 할인하지 않는다"`, `"SILVER 등급은 5%를 할인한다"`, `"GOLD 등급은 10%를 할인한다"`

### 4-2. Phase 2

2. [ ] `[NEW]` `MembershipDiscountTest` — `"VIP 등급은 15%를 할인한다"` (100,000원 → 15,000원)
3. [ ] `[NEW]` `MembershipDiscountTest` — `"VIP 할인은 한 주문에 3만원을 넘지 않는다"` (200,000원 → 30,000원, 300,000원 → 30,000원)

### 4-3. Phase 3

4. [ ] `[NEW]` `FreeShippingPolicyTest` — `"VIP 주문은 3만원 이상이면 무료 배송이다"` (29,999원 → 유료, 30,000원 → 무료)
5. [ ] `[NEW]` `FreeShippingPolicyTest` — `"VIP가 아닌 등급의 주문은 5만원 이상이면 무료 배송이다"` (BASIC·SILVER·GOLD 각각 49,999원 → 유료, 50,000원 → 무료)
6. [ ] `[REGRESSION]` `CheckoutTest` — `"5만원 미만 주문은 배송비 3천원을 낸다"`

### 4-4. Phase 4

7. [ ] `[NEW]` `CheckoutTest` — `"VIP 주문의 적립 포인트는 할인을 반영한 결제 금액의 1%다"` (100,000원 → 할인 15,000원, 배송비 0원, 결제 85,000원, 포인트 850)

### 수동 확인

- [ ] 5만원 정각 주문의 배송비가 3,000원에서 0원으로 바뀌는 것을 기획·CS 담당자와 공유했다.

---

## 5. Prerequisites

- JDK 21 (`build.gradle` toolchain)

### 배포 전 작업

없음

---

## 6. Glossary

| 용어 | 뜻 | 코드 이름 |
|-----|----|---------|
| 주문 금액 | 할인과 배송비를 반영하기 전 금액 | `Order.amount()` |
| 결제 금액 | 주문 금액 − 할인액 + 배송비 | `Receipt.paid()` |
| 할인 한도 | VIP 할인액의 주문당 상한 30,000원 | `MembershipDiscount.VIP_DISCOUNT_CAP` |

---

## 7. Backlog

- [ ] 7-1. 할인율·한도·무료 배송 기준을 `Grade` enum 필드로 옮길지 판단한다. 등급별 기준이 VIP 외에도 생기면 다시 본다. — 출처: Scope Out, Dec-1 옵션 C
- [ ] 7-2. VIP 등급은 누가 어떤 조건으로 부여하는가? — 출처: Scope Out
- [ ] 7-3. Dec-1(Tidy First 구조)과 Dec-2(5만원 정각 무료 배송 전환)는 사용자 부재로 AI가 골랐다. 사용자 확인이 필요하다. — 출처: 명확화 질문
