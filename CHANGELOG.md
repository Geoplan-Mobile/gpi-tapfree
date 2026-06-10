# Changelog

모든 주요 변경 사항은 이 파일에 기록됩니다.

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
