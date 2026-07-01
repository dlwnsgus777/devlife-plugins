# Code Review Checklist

4-dimension evaluation criteria for PR code review.

---

## A — 코드 컨벤션 (25%)

- **Domain prefix naming**: 각 API 모듈의 클래스는 prefix로 시작해야 함
  - `acuvue-api-ecp` → `Ecp` prefix
  - `acuvue-api-app` → `App` prefix
  - `acuvue-api-admin` → `Admin` prefix
  - `acuvue-api-fitting` → `Fitting` prefix
  - `acuvue-api-web` → `Web` prefix
  - 대상: Controller, Executor, Request/Response DTO, 모델 패키지 내 모든 클래스
- **DTO 네이밍**: `{Domain}{Feature}RequestV{N}` / `{Domain}{Feature}ResponseV{N}` 형식 필수
- **Record 사용**: DTO는 class 대신 record 우선, 복잡한 경우 static factory method 추가
- **DI 방식**: `@RequiredArgsConstructor` + `private final` — `@Autowired` 필드 주입 금지
- **Lambda 스타일**: 메서드 레퍼런스 우선, 단일 파라미터 람다는 `it ->` 사용
- **포맷**: 라인 150자 이하, 4-space indent, public → private 순서
- **타입 선언**: `var` 사용 금지 — 항상 명시적 타입 선언
- **파라미터 수**: 메서드 4개 이상 파라미터 → 객체로 묶기, 생성자 다수 파라미터 → `@Builder`

---

## B — 테스트 품질 (30%)

- **모듈 제한**: 테스트는 `acuvue-application` 모듈에만 위치해야 함
- **패키지 경로**: 테스트 패키지 경로가 소스 경로를 정확히 미러링해야 함
- **AAA 패턴**: `// arrange` / `// act` / `// assert` 주석 필수
- **SUT 네이밍**: 테스트 대상 객체는 `sut`로 명명
- **`@DisplayName`**: 한국어로 작성
- **`@Nested`**: 관련 테스트 10개 이상 시 중첩 클래스로 그룹화
- **assertion 의도**: `isEmpty()` vs `doesNotContain()` — 의도에 맞는 메서드 선택
- **Mock 사용 원칙**: `clients/` 패키지 외부 서비스 호출에만 mock, 내부 로직은 직접 사용
- **비즈니스 규칙**: 핵심 비즈니스 케이스(성공/실패/경계값) 모두 커버

---

## C — 도메인 로직 (30%)

- **비즈니스 규칙 완전성**: 분기 조건이 정확하고 누락이 없는지
- **트랜잭션 설계**: `@Transactional` propagation이 적절한지, catch와 충돌하지 않는지
- **예외 처리**: 예외 타입의 적절성, 비즈니스 예외 vs 시스템 예외 구분
- **`@Nationalized`**: NVARCHAR 컬럼에 해당하는 string 필드에 어노테이션 적용 여부
- **외부 통신**: 외부 서비스 호출 시 Feign 클라이언트 사용
- **도메인 로직 캡슐화**: enum 메서드, 도메인 객체 내 로직 배치
- **Null/Empty 처리**: 경계값, null, 빈 컬렉션 처리 누락 여부

---

## D — 설계 품질 (15%)

### 아키텍처 / 레이어 원칙 (Clean Architecture)
- Controller가 DB 직접 접근하지 않는지
- Entity가 API response로 사용되지 않는지 (DTO 변환 필수)
- 비즈니스 로직이 Controller에 없는지
- Domain이 Infrastructure에 의존하지 않는지
- 인터페이스 구현체가 1개뿐인 추상 클래스 없는지

### 유지보수성
- 메서드 ~30줄 초과 → 책임 분리 의심
- 중첩 3단계 초과 또는 높은 분기 복잡도 → early return / 메서드 추출 권장
- 이름만으로 의도가 드러나는지, dead code / hidden side effect 없는지

### 코드 스멜
- **Duplicate code** → 누락된 추상화
- **Large class** → 책임 분리 필요
- **Data clumps** → 반복되는 필드/파라미터 그룹 → 클래스 추출
- **Feature envy** → 다른 클래스의 데이터를 많이 쓰는 메서드 → 이동 고려
- **Message chains** `a.b().c().do()` → Law of Demeter 위반
- **Speculative generality** → 사용하지 않는 추상화 제거 (YAGNI)
- **Switch/if-else on type** → 다형성 또는 전략 패턴으로 대체 고려
- **Shotgun surgery** → 한 변경이 관련 없는 여러 파일에 흩어지는 경우

### 기존 코드 재사용
CLAUDE.md(루트 및 모듈 레벨)를 참고하여 공유 모듈에 이미 존재하는 로직을 새로 구현했는지 확인.
