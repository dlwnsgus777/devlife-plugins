# spec: VIP 등급 추가 (SHOP-101)

## 0. 코드 구조 정비 (Tidy First)

해당 없음 — 지금 구조에 VIP 분기를 하나씩 추가한다. `MembershipDiscount.discount()`에 VIP 분기 1개를 넣는다. `FreeShippingPolicy.isFree()`에 등급별 기준 금액 선택 1개를 넣는다.

**결정 근거**: 등급이 더 늘어날 계획이 요구사항에 없다. 분기 2개 추가는 `Grade`에 할인율·기준 금액을 옮기는 정비보다 단순하다.

---

## 1. 기능 개요

새 등급 VIP를 추가한다. VIP는 할인율과 무료 배송 기준이 다른 등급보다 유리하다. 적립 포인트 계산식은 그대로 둔다.

### 기능 구성

| 기능 | 설명 |
|------|------|
| **VIP 할인** | 주문 금액의 15%를 할인한다. 한 주문의 할인액은 30,000원을 넘지 않는다. |
| **VIP 무료 배송** | 주문 금액이 30,000원 이상이면 배송비가 0원이다. |
| **다른 등급 무료 배송** | 주문 금액이 50,000원 이상이면 배송비가 0원이다. |
| **적립 포인트** | 계산식을 바꾸지 않는다. |

---

## 2. 도메인 문맥 및 불변성

### 도메인 문맥

주문은 등급 `Grade`와 주문 금액 `Order.amount`를 가진다. `Checkout.checkout()`은 등급 할인, 배송비, 결제 금액, 적립 포인트를 차례로 계산해 `Receipt`로 돌려준다. 결제 금액은 `주문 금액 - 할인 + 배송비`다. 무료 배송 여부는 할인 전 주문 금액으로 판단한다.

### 비즈니스 불변성

| 불변성 | 위반 시 영향 | 출처 |
|-------|------------|------|
| VIP 할인액은 주문 금액의 15%다. | VIP 고객에게 약속과 다른 금액을 청구한다. | `[문서]` |
| VIP 할인액은 한 주문에 30,000원을 넘지 않는다. | 200,000원 초과 주문에서 회사가 약속보다 많이 할인한다. | `[문서]` |
| VIP 주문은 주문 금액이 30,000원 이상이면 배송비가 0원이다. | VIP 고객에게 배송비 3,000원을 잘못 청구한다. | `[문서]` |
| VIP가 아닌 주문은 주문 금액이 50,000원 이상이면 배송비가 0원이다. | 정확히 50,000원인 주문에 배송비를 잘못 청구한다. | `[문서]` |
| 적립 포인트는 결제 금액의 1%다. | 이 계산에 의존하는 정산팀 배치의 정산 금액이 틀어진다. | `[문서]` |

---

## 3. 기존 코드의 함정 (답습 금지)

### 3-1. 정확히 50,000원인 주문에 배송비를 받는다

**현재 코드**
- `src/main/java/shop/FreeShippingPolicy.java:9` — `order.amount() > FREE_SHIPPING_THRESHOLD`로 비교한다.

**왜 문제인가**: 주석과 요구사항의 기준은 "5만원 이상"이다. 코드는 초과로 비교해 정확히 50,000원인 주문에 배송비를 받는다.

| 조건 | 현재 결과 | 기대값 |
|------|---------|-------|
| BASIC, 50,000원 | 배송비 3,000원 ❌ | 배송비 0원 |
| VIP, 30,000원을 같은 방식으로 비교 | 배송비 3,000원 ❌ | 배송비 0원 |

**→ 신규는**:
1. VIP 기준 비교에 `>=`를 쓴다.
2. 기존 50,000원 기준 비교도 `>=`로 바꾼다.

**기존 코드**: 이번 티켓에서 함께 고친다. 요구사항이 다른 등급 기준을 "5만원 이상"으로 다시 정의했다.

---

## 5. 비즈니스 로직

### 5-1. VIP 할인

- `MembershipDiscount.discount()`에 `Grade.VIP` 분기를 추가한다.
- 할인액은 `Math.min(order.amount() * 15 / 100, VIP_MAX_DISCOUNT)`다.
- `VIP_MAX_DISCOUNT`는 30,000이다.
- 원 단위 미만은 기존 등급처럼 정수 나눗셈으로 버린다.
- 15% 할인액은 주문 금액 200,000원에서 30,000원 상한에 닿는다.

### 5-2. 무료 배송 기준

- `FreeShippingPolicy.isFree()`는 VIP면 30,000원, 그 밖의 등급이면 50,000원을 기준으로 쓴다.
- 비교는 `order.amount() >= 기준 금액`이다.
- 기준 금액은 할인 전 주문 금액과 비교한다.

### 5-3. 적립 포인트

- `PointCalculator.points()`는 수정하지 않는다.
- VIP 결제 금액이 줄어든 만큼 포인트도 줄어든다. 계산식은 그대로다.

---

## 6. 구현 대상 파일

### shop 패키지

| 파일 | 역할 |
|------|------|
| `Grade` | `VIP` 상수를 추가한다. |
| `MembershipDiscount` | VIP 15% 할인과 30,000원 상한을 계산한다. |
| `FreeShippingPolicy` | 등급별 무료 배송 기준 금액과 `>=`로 비교한다. |
| `FreeShippingPolicyTest` | 신규 테스트 클래스다. |
| `Checkout`, `PointCalculator`, `Order`, `Receipt` | 변경 없음 |

### 코드 스니핏

```java
public enum Grade {
    BASIC, SILVER, GOLD, VIP
}
```

```java
public class MembershipDiscount {

    private static final long VIP_MAX_DISCOUNT = 30_000;

    public long discount(Order order) {
        if (order.grade() == Grade.BASIC) {
            return 0;
        } else if (order.grade() == Grade.SILVER) {
            return order.amount() * 5 / 100;
        } else if (order.grade() == Grade.GOLD) {
            return order.amount() * 10 / 100;
        } else if (order.grade() == Grade.VIP) {
            // VIP 할인액은 한 주문에 30,000원을 넘지 않는다
            return Math.min(order.amount() * 15 / 100, VIP_MAX_DISCOUNT);
        }
        throw new IllegalArgumentException("unknown grade: " + order.grade());
    }
}
```

```java
public class FreeShippingPolicy {

    private static final long FREE_SHIPPING_THRESHOLD = 50_000;
    private static final long VIP_FREE_SHIPPING_THRESHOLD = 30_000;

    // VIP는 3만원 이상, 그 밖의 등급은 5만원 이상이면 무료 배송
    public boolean isFree(Order order) {
        long threshold = order.grade() == Grade.VIP ? VIP_FREE_SHIPPING_THRESHOLD : FREE_SHIPPING_THRESHOLD;
        return order.amount() >= threshold;
    }
}
```

---

## 7. 주요 고려사항 & 질문

1. **50,000원 경계 변경**: 정확히 50,000원인 BASIC·SILVER·GOLD 주문의 배송비가 3,000원에서 0원으로 바뀐다. 이 수정은 `fix` 커밋으로 VIP 기능 커밋과 분리한다.
2. **기존 동작을 따름**: 무료 배송은 할인 전 주문 금액으로 판단한다. 할인액의 원 단위 미만은 버린다.

---

## 8. 구현 순서 (TDD)

### 1단계: 경계 수정

1. [ ] `[NEW]` `FreeShippingPolicyTest` — `"VIP가 아닌 주문은 5만원 이상이면 무료 배송이다"`. 49,999원은 유료, 50,000원은 무료로 검증한다.
2. [ ] `FreeShippingPolicy.isFree()`의 비교를 `>=`로 바꾼다. 커밋: `fix(SHOP-101): 5만원 주문 무료 배송 경계 수정`
3. [ ] `[REGRESSION]` `CheckoutTest` — `"5만원 미만 주문은 배송비 3천원을 낸다"`

### 2단계: 기능 구현

4. [ ] `Grade`에 `VIP`를 추가한다.
5. [ ] `[NEW]` `MembershipDiscountTest` — `"VIP 등급은 15%를 할인한다"`. 10,000원 주문에서 1,500원을 검증한다.
6. [ ] `[NEW]` `MembershipDiscountTest` — `"VIP 할인은 한 주문에 3만원을 넘지 않는다"`. 200,000원과 300,000원 주문에서 30,000원을 검증한다.
7. [ ] `MembershipDiscount.discount()`에 VIP 분기를 추가한다.
8. [ ] `[REGRESSION]` `MembershipDiscountTest` — `"BASIC 등급은 할인하지 않는다"`, `"SILVER 등급은 5%를 할인한다"`, `"GOLD 등급은 10%를 할인한다"`
9. [ ] `[NEW]` `FreeShippingPolicyTest` — `"VIP 주문은 3만원 이상이면 무료 배송이다"`. 29,999원은 유료, 30,000원은 무료로 검증한다.
10. [ ] `FreeShippingPolicy.isFree()`에 VIP 기준 금액 선택을 추가한다.
11. [ ] `[NEW]` `CheckoutTest` — `"VIP 주문은 할인과 배송비가 반영된 결제 금액의 1%를 적립한다"`. 30,000원 주문에서 할인 4,500원, 배송비 0원, 결제 25,500원, 포인트 255점을 검증한다.

커밋: `feat(SHOP-101): VIP 등급 할인과 무료 배송 추가`

---

## 9. 인수 조건 (Acceptance Criteria)

- [ ] VIP 주문은 주문 금액의 15%를 할인받는다.
- [ ] VIP 할인액은 30,000원을 넘지 않는다.
- [ ] VIP 주문은 30,000원 이상이면 배송비가 0원이다.
- [ ] VIP가 아닌 주문은 50,000원 이상이면 배송비가 0원이다.
- [ ] `PointCalculator`는 수정되지 않는다.
