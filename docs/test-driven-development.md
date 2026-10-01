# test-driven-development

Java/Spring Boot 환경에서 TDD를 직접 구현할 때의 원칙과 가이드라인입니다.  
`tdd-subagent`이 에이전트 자동화 방식이라면, 이 스킬은 직접 코드를 작성할 때의 TDD 규칙을 명시합니다.

## 핵심 원칙

```
철의 법칙: 실패하는 테스트 없이는 프로덕션 코드를 작성하지 않는다
```

RED → GREEN → REFACTOR 사이클을 엄격히 준수하며,  
각 단계마다 사용자의 명시적 승인을 받아야 다음 단계로 진행합니다.

## RED — 실패하는 테스트 작성

```java
@Test
void retries_failed_operation_three_times() {
    RetryService retryService = new RetryService();
    final int[] attempts = {0};

    String result = retryService.retry(() -> {
        attempts[0]++;
        if (attempts[0] < 3) throw new RuntimeException("fail");
        return "success";
    });

    assertThat(result).isEqualTo("success");
    assertThat(attempts[0]).isEqualTo(3);
}
```

테스트 작성 후 반드시 실행하여 실패를 확인합니다.

## GREEN — 최소 프로덕션 코드

테스트를 통과하는 최소한의 코드만 작성합니다. 그 이상 구현하지 않습니다.

## REFACTOR — 구조 개선

GREEN 이후 다음 중 하나라도 해당하면 리팩토링합니다:

- 중복 로직 존재
- 불명확한 메서드/변수명
- 메서드가 ~10줄 초과
- 도메인 개념이 잘못 모델링됨

스킵 시 반드시 이유를 명시해야 합니다.

## 테스트를 작성하지 않는 경우

| 대상 | 이유 |
|------|------|
| 단순 생성자, 팩토리 메서드 | 동작 없음 |
| trivial getter/setter | 검증 가치 없음 |
| DTO/record | 비즈니스 로직 없음 |

```java
// ❌ 테스트 불필요 — 동작이 없음
@Test
void createOrder() {
    Order order = new Order("id", "userId");
    assertThat(order.getId()).isEqualTo("id");
}

// ✅ 테스트 필요 — 비즈니스 동작 존재
@Test
void order_is_cancelled_when_payment_fails() {
    Order order = new Order("id", "userId");
    order.cancelDueToPaymentFailure();
    assertThat(order.getStatus()).isEqualTo(OrderStatus.CANCELLED);
}
```

## 테스트 데이터 — Fixture 사용 필수

```java
// ❌ 직접 빌더 사용 금지
FittingContract contract = FittingContract.builder()
    .outletNumber("9999991")
    .contractStatus(ContractStatus.ACTIVE)
    .build();

// ✅ Fixture 팩토리 메서드 사용
FittingContract contract = fittingContractRepository.save(
    aFittingContract()
        .contractStatus(ContractStatus.TERMINATED)
        .build()
);
```

## 관련 스킬

- [tdd-subagent](./tdd-subagent.md) — 에이전트가 RED/GREEN/REFACTOR를 자동 실행
