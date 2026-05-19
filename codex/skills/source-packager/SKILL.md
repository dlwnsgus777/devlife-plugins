---
name: source-packager
description: |
  Spring MVC / Java 프로젝트를 외부 공유용으로 패키징하는 스킬.
  README.md 자동 생성 → 민감정보 마스킹 → ZIP 압축 세 단계를 자동으로 처리한다.

  다음 키워드나 상황에서 반드시 이 스킬을 사용한다:
  - "공유용 zip", "소스 패키징", "분석 자료 zip", "외부 공유 zip"
  - "source zip 만들어", "zip으로 패키징", "소스 압축", "외부에 보낼 zip"
  - 프로젝트를 외부 협력사나 분석 팀에 전달해야 하는 상황
  - 민감정보를 제거하고 코드베이스를 압축해야 할 때
---

# Source Packager

프로젝트를 외부에 안전하게 공유할 수 있도록 패키징하는 스킬이다.
원본 파일은 절대 수정하지 않고 임시 복사본에서 작업한 뒤 ZIP으로 묶는다.

## 실행 순서

### 1단계: 프로젝트 구조 파악

먼저 다음 정보를 탐색한다:

```bash
# 프로젝트 루트 확인
ls <프로젝트루트>

# JSP 뷰 폴더 목록
find <프로젝트루트> -path "*/WEB-INF/view" -type d

# JSP 뷰 하위 폴더
find <WEB-INF/view 경로> -type d

# pom.xml 의존성 (기술스택 파악)
grep -E "<groupId>|<artifactId>|<version>" <pom.xml 경로> | head -60

# mapper XML 테이블명 추출
find <프로젝트루트> -path "*/mapper/*.xml" | xargs grep -h "FROM\|INTO\|UPDATE" | grep -oE "[A-Z_]{4,}" | sort -u | grep -vE "^(FROM|INTO|WHERE|SELECT|UPDATE|AND|JOIN|LEFT|INNER|ORDER|GROUP|INSERT|DELETE|SET|ON|BY|WITH|NOLOCK|AS|OR|NOT|NULL|IN|LIKE|BETWEEN|EXISTS|WHEN|THEN|ELSE|END|CASE|DESC|ASC|TOP|MAX|MIN|SUM|COUNT|AVG|DISTINCT|ALL|IS|FOR)$"

# prop*.properties 파일 위치
find <프로젝트루트> -name "prop*.properties"
```

### 2단계: README.md 작성

프로젝트 루트에 `README.md`를 작성한다. 기존 README.md가 있어도 **덮어쓰지 말고** 분석용 내용을 추가하거나, 없으면 새로 생성한다.

포함할 섹션:

```markdown
# {프로젝트명} — 소스코드 분석 자료

## 1. 기준 시점
- 소스코드 기준일: {오늘 날짜}
- 형상 관리: Git ({현재 브랜치} 브랜치 기준)
- 최근 주요 커밋: {git log --oneline -5 결과}

## 2. 민감 정보 제외 안내
| 항목 | 조치 |
...

## 3. 폴더 구조
(Java 패키지 구조, webapp 구조)

## 4. JSP 뷰 폴더 매핑
WEB-INF/view/ 하위 폴더별로 어떤 화면인지 설명
폴더명과 JSP 파일명을 기반으로 기능을 추론해서 설명한다

## 5. 기술 스택
pom.xml 분석 결과를 Backend / Frontend / 인프라로 나눠 정리

## 6. DB 관련 정보
- DB 종류, 연결 방식
- 주요 테이블 목록 (mapper XML에서 추출)
- MyBatis 매퍼 구조 설명
- 분석 참고 사항 (도메인별 특이사항)
```

JSP 폴더 설명은 폴더명과 파일명을 보고 해당 도메인의 기능을 추론해서 작성한다.
예: `dx/dxOrder/` → 브랜드별 체험렌즈 주문 폼, `coupon/couponManage/` → 쿠폰 한도 배분 관리

### 3단계: 임시 복사본 생성 및 민감정보 마스킹

```bash
# 임시 디렉토리 생성
TMPDIR=$(mktemp -d)
WORKDIR="$TMPDIR/{프로젝트명}"
mkdir -p "$WORKDIR"

# rsync로 복사 (민감한 폴더 제외)
rsync -a \
  --exclude='.git' \
  --exclude='.idea' \
  --exclude='.omc' \
  --exclude='.claude' \
  --exclude='target/' \
  --exclude='*.class' \
  --exclude='.well-known' \
  --exclude='*_log/' \
  --exclude='logs/' \
  {프로젝트루트}/ "$WORKDIR/"

# README.md 복사 (방금 작성한 것)
cp {프로젝트루트}/README.md "$WORKDIR/README.md"
```

**민감정보 마스킹** (복사본에서만 처리):

```bash
for f in $(find "$WORKDIR" -name "prop*.properties"); do
  # DB URL (IP 포함)
  sed -i '' 's|jdbc\.url=jdbc:sqlserver://[^;]*;|jdbc.url=jdbc:sqlserver://***REMOVED***;|g' "$f"
  sed -i '' 's|#jdbc\.url=jdbc:sqlserver://[^;]*;|#jdbc.url=jdbc:sqlserver://***REMOVED***;|g' "$f"
  # DB 계정/비밀번호
  sed -i '' 's|jdbc\.username=.*|jdbc.username=***REMOVED***|g' "$f"
  sed -i '' 's|jdbc\.password=.*|jdbc.password=***REMOVED***|g' "$f"
  sed -i '' 's|#jdbc\.username=.*|#jdbc.username=***REMOVED***|g' "$f"
  sed -i '' 's|#jdbc\.password=.*|#jdbc.password=***REMOVED***|g' "$f"
  # AWS 자격증명
  sed -i '' 's|aws\.ses\.smtp\.username=.*|aws.ses.smtp.username=***REMOVED***|g' "$f"
  sed -i '' 's|aws\.ses\.smtp\.password=.*|aws.ses.smtp.password=***REMOVED***|g' "$f"
  # 기타 secret/token/key 패턴 (있을 경우)
  sed -i '' 's|\.secret=.*|.secret=***REMOVED***|g' "$f"
  sed -i '' 's|\.token=.*|.token=***REMOVED***|g' "$f"
  sed -i '' 's|api\.key=.*|api.key=***REMOVED***|g' "$f"
done
```

마스킹 후 반드시 결과를 검증한다:
```bash
grep -r "password\|username\|secret\|token\|key" "$WORKDIR" \
  --include="*.properties" | grep -v "REMOVED\|#\|driverClass\|lockTimeout"
```
위 명령에서 실제 값이 보이면 추가 마스킹이 필요하다.

**추가 확인**: 다른 설정 파일(`application.yml`, `application.properties`, `*.xml`, `*.json` 등)에도 민감정보가 있을 수 있다. 다음으로 확인한다:
```bash
grep -rn "password\|secret\|token\|api.key" "$WORKDIR" \
  --include="*.yml" --include="*.yaml" --include="*.json" | grep -v "REMOVED\|#"
```

### 4단계: ZIP 생성

```bash
DATE=$(date +%Y%m%d)
OUTPUT="{프로젝트루트}/{프로젝트명}-source-${DATE}.zip"

cd "$TMPDIR" && zip -r "$OUTPUT" {프로젝트명}/ \
  -x "*.DS_Store" \
  -x "*.class" \
  -x "*_log/*" \
  -x "*/logs/*"

echo "생성 완료: $OUTPUT"
ls -lh "$OUTPUT"
```

### 5단계: 최종 검증

```bash
# ZIP 내 민감정보 검증
unzip -p "$OUTPUT" "*/prop.properties" 2>/dev/null | grep -E "password|username|aws|secret"
# 모든 값이 ***REMOVED***여야 한다

# ZIP 내 제외 대상 폴더 없는지 확인
unzip -l "$OUTPUT" | grep -E "\.git/|\.idea/|\.well-known/"
# 아무것도 출력되지 않아야 한다

# 파일 수 및 크기 확인
unzip -l "$OUTPUT" | tail -1
```

검증 완료 후 사용자에게 ZIP 경로와 크기를 알린다.

## 주의사항

- **원본 파일은 절대 수정하지 않는다.** 마스킹은 항상 임시 복사본에서만 수행한다.
- `.env`, `.env.*`, `*secret*`, `*credential*` 파일도 제외 대상에 포함시킨다.
- ZIP 파일 자체는 프로젝트 루트 바로 아래에 생성한다 (서브폴더 안에 넣지 않는다).
- macOS에서 `sed -i ''`, Linux에서 `sed -i`를 사용한다. 환경에 맞게 조정한다.
- 대용량 리소스 폴더(이미지, 폰트 등)가 있으면 사용자에게 포함 여부를 물어본다.
