#!/usr/bin/env bash
# Builds the Java/Gradle shop project used to compare old and new plan-creator output.
# Usage: fixture.sh <empty target dir>
# Planted on purpose:
#   - pitfall:      FreeShippingPolicy checks "5만원 이상" with ">" (50,000 itself is wrong)
#   - out of scope: PointCalculator must not change
#   - tidy first:   MembershipDiscount branches on grade with if/else; VIP adds a case
set -euo pipefail

TARGET="${1:?usage: fixture.sh <target dir>}"
mkdir -p "$TARGET"
cd "$TARGET"

mkdir -p src/main/java/shop src/test/java/shop

cat > settings.gradle <<'EOF'
rootProject.name = 'shop'
EOF

cat > build.gradle <<'EOF'
plugins { id 'java' }

java { toolchain { languageVersion = JavaLanguageVersion.of(21) } }

repositories { mavenCentral() }

dependencies {
    testImplementation 'org.junit.jupiter:junit-jupiter:5.11.4'
    testRuntimeOnly 'org.junit.platform:junit-platform-launcher:1.11.4'
}

test { useJUnitPlatform() }
EOF

cat > gradlew <<'EOF'
#!/usr/bin/env bash
exec gradle "$@"
EOF
chmod +x gradlew

cat > src/main/java/shop/Grade.java <<'EOF'
package shop;

public enum Grade {
    BASIC, SILVER, GOLD
}
EOF

cat > src/main/java/shop/Order.java <<'EOF'
package shop;

public record Order(Grade grade, long amount) {
}
EOF

cat > src/main/java/shop/MembershipDiscount.java <<'EOF'
package shop;

public class MembershipDiscount {

    public long discount(Order order) {
        if (order.grade() == Grade.BASIC) {
            return 0;
        } else if (order.grade() == Grade.SILVER) {
            return order.amount() * 5 / 100;
        } else if (order.grade() == Grade.GOLD) {
            return order.amount() * 10 / 100;
        }
        throw new IllegalArgumentException("unknown grade: " + order.grade());
    }
}
EOF

cat > src/main/java/shop/FreeShippingPolicy.java <<'EOF'
package shop;

public class FreeShippingPolicy {

    private static final long FREE_SHIPPING_THRESHOLD = 50_000;

    // 주문 금액 5만원 이상이면 무료 배송
    public boolean isFree(Order order) {
        return order.amount() > FREE_SHIPPING_THRESHOLD;
    }
}
EOF

cat > src/main/java/shop/PointCalculator.java <<'EOF'
package shop;

public class PointCalculator {

    // 적립 포인트는 결제 금액의 1%. 정산팀 배치가 이 계산에 의존하므로 바꾸지 않는다.
    public long points(long paidAmount) {
        return paidAmount / 100;
    }
}
EOF

cat > src/main/java/shop/Checkout.java <<'EOF'
package shop;

public class Checkout {

    private static final long SHIPPING_FEE = 3_000;

    private final MembershipDiscount membershipDiscount = new MembershipDiscount();
    private final FreeShippingPolicy freeShippingPolicy = new FreeShippingPolicy();
    private final PointCalculator pointCalculator = new PointCalculator();

    public Receipt checkout(Order order) {
        long discount = membershipDiscount.discount(order);
        long shipping = freeShippingPolicy.isFree(order) ? 0 : SHIPPING_FEE;
        long paid = order.amount() - discount + shipping;
        return new Receipt(discount, shipping, paid, pointCalculator.points(paid));
    }
}
EOF

cat > src/main/java/shop/Receipt.java <<'EOF'
package shop;

public record Receipt(long discount, long shipping, long paid, long points) {
}
EOF

cat > src/test/java/shop/MembershipDiscountTest.java <<'EOF'
package shop;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class MembershipDiscountTest {

    private final MembershipDiscount discount = new MembershipDiscount();

    @Test
    @DisplayName("BASIC 등급은 할인하지 않는다")
    void basic() {
        assertEquals(0, discount.discount(new Order(Grade.BASIC, 10_000)));
    }

    @Test
    @DisplayName("SILVER 등급은 5%를 할인한다")
    void silver() {
        assertEquals(500, discount.discount(new Order(Grade.SILVER, 10_000)));
    }

    @Test
    @DisplayName("GOLD 등급은 10%를 할인한다")
    void gold() {
        assertEquals(1_000, discount.discount(new Order(Grade.GOLD, 10_000)));
    }
}
EOF

cat > src/test/java/shop/CheckoutTest.java <<'EOF'
package shop;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class CheckoutTest {

    private final Checkout checkout = new Checkout();

    @Test
    @DisplayName("5만원 미만 주문은 배송비 3천원을 낸다")
    void shippingFeeUnderThreshold() {
        assertEquals(3_000, checkout.checkout(new Order(Grade.BASIC, 30_000)).shipping());
    }
}
EOF

cat > REQUIREMENTS.md <<'EOF'
# VIP 등급 추가 (SHOP-101)

- 새 등급 VIP를 추가한다. VIP는 주문 금액의 15%를 할인한다.
- VIP 할인은 한 주문에 최대 3만원까지만 적용한다.
- VIP 주문은 주문 금액이 3만원 이상이면 무료 배송이다. 다른 등급은 지금처럼 5만원 이상이면 무료 배송이다.
- 적립 포인트 계산은 바꾸지 않는다.
EOF

git init -q
git -c user.name=eval -c user.email=eval@example.com add -A
git -c user.name=eval -c user.email=eval@example.com commit -qm "initial"
