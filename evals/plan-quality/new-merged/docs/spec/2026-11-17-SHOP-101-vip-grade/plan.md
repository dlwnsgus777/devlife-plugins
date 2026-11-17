# VIP 등급 추가 (SHOP-101)

base: origin/main

> VIP 등급을 추가한다. VIP는 15%를 할인한다. 할인은 주문당 최대 3만원이다. VIP 주문은 3만원 이상이면 무료 배송이다.

---

## 1. Context

### 배경

회원 등급은 `Grade` enum의 BASIC·SILVER·GOLD 세 가지다.
결제 계산은 `Checkout.checkout(Order)`가 등급 할인, 배송비, 적립 포인트 순서로 수행해 `Receipt`를 만든다.
이번 작업은 네 번째 등급 VIP를 추가한다.
VIP는 할인율과 할인 상한, 무료 배송 기준이 다른 등급과 다르다.

### 외부 제약

- 적립 포인트 계산식 `PointCalculator.points()`는 바꾸지 않는다. 정산팀 배치가 이 계산에 의존한다.

### 도메인 불변성

| 불변성 | 위반 시 영향 | 출처 |
|-------|------------|------|
| VIP 할인액은 주문 금액의 15%다. | 요구사항과 다른 금액이 결제된다. | `[문서]` |
| VIP 할인액은 한 주문에 30,000원을 넘지 않는다. | 상한을 넘는 할인이 결제 금액에서 빠진다. | `[문서]` |
| VIP 주문은 주문 금액이 30,000원 이상이면 배송비가 0원이다. | 요구사항과 다른 배송비가 결제된다. | `[문서]` |
| VIP가 아닌 주문은 주문 금액이 50,000원 이상이면 배송비가 0원이다. | 정확히 50,000원인 주문에 배송비 3,000원이 붙는다. | `[문서]` |
| 무료 배송 여부는 할인 전 주문 금액(`order.amount()`)으로 판단한다. | 같은 주문의 무료 배송 여부가 할인액에 따라 달라진다. | `[코드추론]` |
| 적립 포인트는 결제 금액의 1%다. | 정산팀 배치의 계산 결과와 어긋난다. | `[문서]` |

### 기존 패턴

- 등급 할인은 `MembershipDiscount.discount(Order)`가 계산한다 — `src/main/java/shop/MembershipDiscount.java`
- 무료 배송 여부는 `FreeShippingPolicy.isFree(Order)`가 판단한다 — `src/main/java/shop/FreeShippingPolicy.java`
- 할인 금액은 정수 나눗셈으로 버림한다(`amount * 율 / 100`) — `MembershipDiscount.java:9`
- 배송비는 `Checkout.SHIPPING_FEE`(3,000원) 하나다 — `src/main/java/shop/Checkout.java:5`

### 기존 코드의 함정

#### 함정 1. 정확히 5만원인 주문이 유료 배송이 된다

**현재 코드**
- `src/main/java/shop/FreeShippingPolicy.java:9` — `order.amount() > FREE_SHIPPING_THRESHOLD`로 초과 비교한다.

**왜 문제인가**: 주석과 요구사항은 "5만원 이상"인데 코드는 5만원 초과일 때만 무료 배송이다.

| 조건 | 현재 결과 | 기대값 |
|------|---------|-------|
| BASIC, 50,000원 | 배송비 3,000원 ❌ | 배송비 0원 |

**→ 신규는**: 무료 배송 기준 비교는 `>=`로 한다. VIP의 30,000원 기준도 같은 비교를 쓴다.

**기존 코드**: 이번 티켓에서 함께 고친다. 요구사항이 "지금처럼 5만원 이상"을 명시하므로 같은 비교식을 VIP와 공유한다. [Dec-2]

#### 함정 2. 등급 분기 끝의 도달할 수 없는 예외

**현재 코드**
- `src/main/java/shop/MembershipDiscount.java:6-13` — 등급마다 if-else 분기를 두고 마지막에 `IllegalArgumentException`을 던진다.

**왜 문제인가**: 새 등급을 enum에만 추가하고 분기를 빠뜨려도 컴파일이 통과한다. 그 등급의 결제는 실행 시점에 예외로 실패한다.

**→ 신규는**: 등급별 값은 `Grade` enum 생성자 인자로 둔다. 새 등급은 생성자 인자 없이 선언할 수 없다.

**기존 코드**: Phase 1에서 분기를 `Grade`로 옮기면서 없앤다. [Dec-1]

---

## 2. Scope

- **In**: `Grade`에 VIP 추가, VIP 할인율 15%와 상한 30,000원, VIP 무료 배송 기준 30,000원, 무료 배송 경계를 `>=`로 수정
- **Out**: `MembershipDiscount`·`FreeShippingPolicy` 제거. 호출부 변경 없이 이번 범위를 작게 유지한다(Dec-6). → 7-1
- **Out**: 회원에게 VIP 등급을 부여하는 방식. 요구사항에 없다. → 7-2

---

## 3. Plan

| Phase | 목표 | 완료 기준 | 상태 |
|-------|-----|---------|-----|
| 1 | 등급별 할인율·무료 배송 기준을 `Grade`로 이동 (Tidy First) | 4-1 통과, 동작 변경 없음 | todo |
| 2 | 무료 배송 경계를 "이상"으로 수정 | 4-2 통과 | todo |
| 3 | VIP 등급 추가 | 4-3 통과 | todo |

### Phase 1. 코드 구조 정비 (Tidy First)

**결정**: Dec-1, Dec-6

| 목표 구조 | 기존 코드 정비 (기법) | 영향 범위 (호출부·안전망 테스트) | 본 작업에서 추가할 것 |
|---------|-------------------|----------------------------|-------------------|
| 등급별 할인율과 무료 배송 기준을 `Grade` enum 필드가 가진다. | `MembershipDiscount`의 if-else와 `FreeShippingPolicy`의 기준 금액을 `Grade.discount()`·`Grade.isFreeShipping()`로 옮긴다 — Move Method, Replace Conditional with Polymorphism | `MembershipDiscount`, `FreeShippingPolicy`, 호출부 `Checkout` / `MembershipDiscountTest`, `CheckoutTest`, 신규 `FreeShippingPolicyTest`(4-1의 3번) | `Grade.VIP` 상수와 `maxDiscount` 필드 |

`FreeShippingPolicy`에는 5만원 초과 쪽을 확인하는 테스트가 없다. 정비 전에 특성 테스트(4-1의 3번)를 먼저 쓴다.
Phase 1의 비교식은 기존대로 `>`를 유지한다. 경계 수정은 Phase 2에서 동작 변경으로 분리한다.

**커밋 순서**: `test: FreeShippingPolicy 특성 테스트` → `refactor: 등급별 할인율·무료 배송 기준을 Grade로 이동` → `fix(SHOP-101): 무료 배송 기준을 5만원 이상으로 수정` → `feat(SHOP-101): VIP 등급 추가`

**코드 스니핏**

```java
public enum Grade {
    BASIC(0, 50_000),
    SILVER(5, 50_000),
    GOLD(10, 50_000);

    private final int discountPercent;
    private final long freeShippingThreshold;

    Grade(int discountPercent, long freeShippingThreshold) {
        this.discountPercent = discountPercent;
        this.freeShippingThreshold = freeShippingThreshold;
    }

    public long discount(long amount) {
        return amount * discountPercent / 100;
    }

    public boolean isFreeShipping(long amount) {
        return amount > freeShippingThreshold;
    }
}
```

```java
public class MembershipDiscount {

    public long discount(Order order) {
        return order.grade().discount(order.amount());
    }
}
```

```java
public class FreeShippingPolicy {

    public boolean isFree(Order order) {
        return order.grade().isFreeShipping(order.amount());
    }
}
```

### Phase 2. 무료 배송 경계 수정

**구현 대상 파일**

| 파일 | 역할 |
|------|------|
| `Grade` | `isFreeShipping()`의 비교를 `>=`로 바꾼다. |

**비즈니스 로직**

- 주문 금액이 등급의 `freeShippingThreshold` 이상이면 무료 배송이다. (Dec-2)
- 비교 대상은 할인 전 주문 금액 `order.amount()`다. (Dec-3)

**코드 스니핏**

```java
    // 주문 금액이 기준 금액 이상이면 무료 배송
    public boolean isFreeShipping(long amount) {
        return amount >= freeShippingThreshold;
    }
```

### Phase 3. VIP 등급 추가

**구현 대상 파일**

| 파일 | 역할 |
|------|------|
| `Grade` | `VIP` 상수와 할인 상한 `maxDiscount` 필드를 추가한다. |

**비즈니스 로직**

- VIP 할인액은 `order.amount() * 15 / 100`을 버림한 값이다. (Dec-4)
- 그 값이 30,000원을 넘으면 30,000원을 할인한다. (Dec-4)
- BASIC·SILVER·GOLD는 상한이 없다. 이 등급의 `maxDiscount`는 `Long.MAX_VALUE`다.
- VIP 무료 배송 기준은 30,000원이다. 비교식은 Phase 2의 `isFreeShipping()`을 그대로 쓴다.
- `Checkout`과 `PointCalculator`는 수정하지 않는다. 포인트는 VIP 할인이 반영된 결제 금액의 1%다. (Dec-5)

**코드 스니핏**

```java
public enum Grade {
    BASIC(0, Long.MAX_VALUE, 50_000),
    SILVER(5, Long.MAX_VALUE, 50_000),
    GOLD(10, Long.MAX_VALUE, 50_000),
    VIP(15, 30_000, 30_000);

    private final int discountPercent;
    private final long maxDiscount;
    private final long freeShippingThreshold;

    Grade(int discountPercent, long maxDiscount, long freeShippingThreshold) {
        this.discountPercent = discountPercent;
        this.maxDiscount = maxDiscount;
        this.freeShippingThreshold = freeShippingThreshold;
    }

    // 할인액은 주문 금액에 할인율을 곱해 버림하고, 등급의 상한을 넘지 않는다
    public long discount(long amount) {
        return Math.min(amount * discountPercent / 100, maxDiscount);
    }

    public boolean isFreeShipping(long amount) {
        return amount >= freeShippingThreshold;
    }
}
```

---

## 4. Verification

### 4-1. Phase 1

1. [ ] `[REGRESSION]` `MembershipDiscountTest` — `"BASIC 등급은 할인하지 않는다"`, `"SILVER 등급은 5%를 할인한다"`, `"GOLD 등급은 10%를 할인한다"`
2. [ ] `[REGRESSION]` `CheckoutTest` — `"5만원 미만 주문은 배송비 3천원을 낸다"`
3. [ ] `[NEW]` `FreeShippingPolicyTest` — `"5만원을 넘는 주문은 무료 배송이다"`: BASIC 50,001원 → 무료

### 4-2. Phase 2

4. [ ] `[NEW]` `FreeShippingPolicyTest` — `"VIP가 아닌 등급은 주문 금액이 5만원 이상이면 무료 배송이다"`: BASIC·SILVER·GOLD 각각 49,999원 → 유료, 50,000원 → 무료

### 4-3. Phase 3

5. [ ] `[NEW]` `MembershipDiscountTest` — `"VIP 등급은 주문 금액의 15%를 할인한다"`: 10,000원 → 1,500원
6. [ ] `[NEW]` `MembershipDiscountTest` — `"VIP 할인은 한 주문에 최대 3만원이다"`: 199,999원 → 29,999원, 200,000원 → 30,000원, 200,001원 → 30,000원
7. [ ] `[NEW]` `FreeShippingPolicyTest` — `"VIP 등급은 할인 전 주문 금액이 3만원 이상이면 무료 배송이다"`: 29,999원 → 유료, 30,000원 → 무료. 30,000원 주문은 할인 후 25,500원이어도 무료다.
8. [ ] `[NEW]` `CheckoutTest` — `"VIP 주문의 적립 포인트는 결제 금액의 1%다"`: VIP 200,000원 → 할인 30,000원, 배송비 0원, 결제 170,000원, 포인트 1,700점

### 수동 확인

- [ ] 정확히 50,000원인 기존 등급 주문의 배송비가 3,000원에서 0원으로 바뀐 것을 운영 측에 공유했는지 확인한다.

---

## 5. Prerequisites

- Java 21, JUnit 5.11
- 빌드는 `./gradlew --offline`으로 실행한다.

### 배포 전 작업

- [ ] 5만원 경계 변경(Dec-2)을 정산·CS 담당자에게 공유한다.

---

## 6. Glossary

| 용어 | 뜻 | 코드 이름 |
|-----|----|---------|
| 주문 금액 | 할인과 배송비를 반영하기 전 금액 | `Order.amount()` |
| 결제 금액 | 주문 금액 − 할인액 + 배송비 | `Receipt.paid()` |
| 할인 상한 | 한 주문에 적용되는 등급 할인액의 최댓값 | `Grade.maxDiscount` |
| 무료 배송 기준 | 이 금액 이상이면 배송비가 0원인 주문 금액 | `Grade.freeShippingThreshold` |

---

## 7. Backlog

- [ ] 7-1. `MembershipDiscount`·`FreeShippingPolicy`를 없애고 `Checkout`이 `Grade`를 직접 호출하도록 정리할지 검토 — 출처: Scope Out
- [ ] 7-2. 회원에게 VIP 등급을 부여하는 조건과 방식 — 출처: Scope Out
- [ ] 7-3. 5만원 경계를 "이상"으로 바꾼 결정(Dec-2)을 사용자가 확인 — 출처: 명확화 질문(사용자 부재로 추천안 채택)
- [ ] 7-4. 무료 배송을 할인 전 금액으로 판단하는 이유(Dec-3)를 사용자가 확인 — 출처: 자체 검증(`[코드추론]` 불변성)
