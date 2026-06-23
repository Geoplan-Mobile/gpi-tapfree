# Changelog

모든 주요 변경 사항은 이 파일에 기록됩니다.

## [2.0.3] - 2026-06-23

### Breaking

- **`getLibraryVersion()` 반환 형식 변경**  
  - 기존 `"gpi-tapfree:<버전>"` → **순수 버전 문자열 `"<버전>"`**   
  (예: `"gpi-tapfree:2.0.3"` → `"2.0.3"`).
- **iOS 27 SDK 필수** — **Xcode 27 이상** 으로 빌드해야 link 가능.
- **런타임 지원 OS 명시** — **iOS 18+ 디바이스 지원** (BLE 측위). **UWB DL-TDoA 는 iOS 27+ 디바이스 한정** 으로 자동 활성화. iOS 18–26 디바이스는 BLE 모드로만 동작.

### Added

- **`onError` 신규 코드 `SESSION_TAKEN_OVER = 11` + 동작 변경**  
같은 `mobileId` 로 다른 디바이스가 Edge 에 새로 접속시 라이브러리가 stop()되며 통지.

  **기존 (2.0.2 이하)**:  
  라이브러리 stop되지 않으며 동일 zone 으로 즉시 재접속 시도  
  → 그 재접속이 다시 상대 클라이언트의 세션을 Close  
  → 상대도 같은 방식으로 재접속  
  → **두 클라이언트가 서로의 세션을 끝없이 Close** (외부 stop 전엔 종료되지 않음).

  **변경 (2.0.3)**:  
  중복으로 인한 종료 감지 시 **재시도 없이 `stop()` + `onError(11, ...)`** 호출.  
  재개가 필요하면 호출 측이 명시적으로 `start()` 다시 호출.

  > ⚠️ **정책 요약** — `mobileId` 중복은 치명적 오류로 간주, 무조건 `stop()`.  
   **최신 연결이 우선시**되어 기존 클라이언트가 stop 됨.  
  호출 측은 `mobileId` 가 디바이스/인스턴스 간 중복되지 않도록 반드시 유의해야 한다.

### Changed

- **DL-TDoA 좌표 도출 로직 변경**  
더 이상 캘리브레이션을 통한 offset 도출 과정이 필요 없으며, 서버에서 수신되는 앵커별 offset 값은 내부적으로 무시된다. (iPhone 캘리브레이션 단계 생략 가능)

> ⚠️ **주의** — **Edge 와의 통신 프로토콜이 변경된 것은 아니므로** Edge 서버 측 설정에는 **offset 항목 자체는 반드시 작성** 되어 있어야 한다 (값은 임의 — `0.0` 등 무엇이든 무방).

### Migration

기존 2.0.2 에서 업그레이드 시 호출 측에서 해야 할 일:

1. 사용 앱의 빌드 환경을 **Xcode 27 (또는 정식 출시 후 정식판)** 으로 전환.
2. `getLibraryVersion()` 반환값 사용처 점검 

## [2.0.2] - 2026-06-12

### Breaking

- **iOS 27.0+ 에서만 DL-TDoA 동작** — iOS 27 이하 디바이스는 무조건 자동으로 BLE 측위로 동작.
- **Location 권한 필수** — `initialize()`에서 로케이션 권한 체크 및 에러처리. 
 
### Added

- ** `onError()`로 전달되는 `TapfreeErrorType` 신규 코드**
  - `LOCATION_PERMISSION_REQUIRED = 7` — Location 권한 미요청/거부/제한
  - `BLUETOOTH_PERMISSION_REQUIRED = 8` — BT 권한 거부/제한
  - `BT_USAGE_DESCRIPTION_MISSING = 10` — Info.plist 의 `NSBluetoothAlwaysUsageDescription` 누락

### Changed

- **`NSNearbyInteractionUsageDescription` Info.plist 키 불필요** — iOS 27 DL-TDoA 정책 변화로 라이브러리가 더 이상 이 키를 사전 검증하지 않음. 키가 있어도 무방.
- **dltdoa entitlement 폐지** — Apple Developer Portal 의 `Nearby Interaction DL-TDoA (development)` capability 와 앱 `.entitlements` 항목 불필요.


## [2.0.1] - 2026-06-10

### Added

- **`TapfreePlatform.start()` 에 `ddnsDomain` 파라미터 추가** — Edge 접속 호스트 구성에 사용하는 DDNS 도메인을 호출 측에서 override 할 수 있다. 기본값 `"cns-link.net"` 이라 기존 호출부는 그대로 동작 (= `ddnsDomain: "cns-link.net"` 을 명시한 것과 동일).
  ```swift
  // 기존 호출부 — ddnsDomain 미지정 시 "cns-link.net" 으로 동작
  try platform.start(mobileId: id, timerPeriod: 1000)
  // 신규 — 다른 DDNS 도메인을 사용하는 사이트
  try platform.start(mobileId: id, timerPeriod: 1000, ddnsDomain: "example.net")
  ```
- **`MIGRATION-GUIDE.md` 추가** — 임베드 소스 → SPM 의존성 전환 가이드. 메인 앱 / 타사 앱 모두 본 가이드로 마이그레이션 가능.

### Changed

- **버전 식별 파일**: `VERSION_2.0.0` → `VERSION_2.0.1`.

## [2.0.0] - 2026-06-05

### 초기 SPM 배포

- **xcframework 기반 SPM 배포**: `gpi-tapfree.xcframework` (iOS arm64 + arm64/x86_64-simulator) 를 SPM 의 binaryTarget 으로 제공.
- **transitive 의존성 자동 해결**: 내부 deps carrier target (`gpi-tapfree-deps`) 이 `gpi-dltdoa`, `GEOSwift` 를 transitive 로 끌어와 사용 앱이 별도 선언 불필요.
- **버전 식별 파일**: `gpi-tapfree.xcframework/VERSION_2.0.0` 으로 배포 버전 식별 가능.
- **dSYM 동봉**: xcframework 내부에 `dSYMs/` 포함 — 크래시 발생 시 SDK 코드 위치 symbolication 가능.
