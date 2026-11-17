# VIP 등급 추가 설계 (SHOP-101)

> 같은 폴더의 `plan.md`가 무엇을 하는지, `decisions.md`가 왜 그렇게 했는지를 담는다. 이 문서는 어떻게 만드는지를 담는다.

---

## 1. 코드 구조 정비 (Tidy First)

**결정**: Dec-1

| 목표 구조 | 기존 코드 정비 (기법) | 영향 범위 (호출부·안전망 테스트) | 본 작업에서 추가할 것 |
|---------|-------------------|----------------------------|-------------------|
| 등급별 할인을 `Grade`에 대한 switch expression 하나가 계산한다. | `MembershipDiscount.discount()`의 if-else 체인과 마지막 `throw`를 switch expression으로 바꾼다. 기법은 Replace Nested Conditional with Switch다. | `MembershipDiscount`, 호출부 `Checkout` / `MembershipDiscountTest` 3건 | `case VIP` 한 줄 |

**커밋 순서**: `refactor: MembershipDiscount 등급 분기를 switch expression으로 정비` → `feat(SHOP-101): VIP 등급 할인과 무료 배송 기준 추가`

---

## 2. 기존 코드의 함정 (답습 금지)

### 2-1. 무료 배송 기준 금액 정각 주문에 배송비가 붙는다

**현재 코드**
- `src/main/java/shop/FreeShippingPolicy.java:9` — `order.amount() > FREE_SHIPPING_THRESHOLD`로 비교한다.

**왜 문제인가**: 요구사항과 같은 줄 주석은 "5만원 이상"인데 코드는 초과로 비교한다.

| 조건 | 현재 결과 | 기대값 |
|------|---------|-------|
| BASIC, 50,000원 | 유료 ❌ | 무료 |
| VIP, 30,000원, `>` 답습 시 | 유료 ❌ | 무료 |

**→ 신규는**: VIP 기준을 포함한 모든 기준 비교를 `>=`로 쓴다.

**기존 코드**: 이번 티켓에서 함께 고친다. 같은 메서드에서 등급마다 경계 비교가 달라지면 안 된다(Dec-2).

---

## 4. 비즈니스 로직

### 4-1. VIP 할인액

- `MembershipDiscount.discount(Order)`의 `case VIP`에서 `Math.min(order.amount() * 15 / 100, VIP_DISCOUNT_CAP)`를 반환한다(Dec-3).
- `VIP_DISCOUNT_CAP`은 30,000이다. 주문 금액 200,000원부터 한도가 적용된다.
- 원 미만은 기존 등급과 같이 정수 나눗셈으로 버린다.

### 4-2. 무료 배송 판단

- `FreeShippingPolicy.isFree(Order)`는 등급이 VIP면 30,000원, 아니면 50,000원을 기준으로 고른다(Dec-6).
- 비교 대상은 할인 전 `order.amount()`다(Dec-4).
- 비교는 `>=`다(2-1).

### 4-3. 결제와 포인트

- `Checkout.checkout()`과 `PointCalculator`는 바꾸지 않는다(Dec-5).
- VIP 결제 금액은 `amount - discount + shipping`이다. 포인트는 그 금액의 1%다.

---

## 5. 구현 대상 파일

### shop 패키지

| 파일 | 역할 |
|------|------|
| `Grade` | `VIP` 상수 추가 |
| `MembershipDiscount` | switch expression 정비(Phase 1), `case VIP` 추가(Phase 2) |
| `FreeShippingPolicy` | VIP 기준 3만원 추가, 비교를 `>=`로 수정(Phase 3) |
| `MembershipDiscountTest` | VIP 테스트 2건 추가 |
| `FreeShippingPolicyTest` | 신규. 등급별 무료 배송 경계 테스트 |
| `CheckoutTest` | VIP 영수증 테스트 1건 추가 |

- `Checkout`, `PointCalculator`, `Order`, `Receipt` — 변경 없음

### 코드 스니핏

```java
public enum Grade {
    BASIC, SILVER, GOLD, VIP
}
```

```java
public class MembershipDiscount {

    private static final long VIP_DISCOUNT_CAP = 30_000;

    public long discount(Order order) {
        return switch (order.grade()) {
            case BASIC -> 0;
            case SILVER -> order.amount() * 5 / 100;
            case GOLD -> order.amount() * 10 / 100;
            // VIP 할인은 15%이고 한 주문에 3만원을 넘지 않는다
            case VIP -> Math.min(order.amount() * 15 / 100, VIP_DISCOUNT_CAP);
        };
    }
}
```

```java
public class FreeShippingPolicy {

    private static final long FREE_SHIPPING_THRESHOLD = 50_000;
    private static final long VIP_FREE_SHIPPING_THRESHOLD = 30_000;

    // 주문 금액이 기준 이상이면 무료 배송. VIP는 3만원, 그 외 등급은 5만원
    public boolean isFree(Order order) {
        long threshold = order.grade() == Grade.VIP ? VIP_FREE_SHIPPING_THRESHOLD : FREE_SHIPPING_THRESHOLD;
        return order.amount() >= threshold;
    }
}
```
