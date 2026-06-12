# Changelog

모든 주요 변경 사항은 이 파일에 기록됩니다.

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
