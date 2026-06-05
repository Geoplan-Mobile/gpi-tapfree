# Changelog

모든 주요 변경 사항은 이 파일에 기록됩니다.

## [2.0.0] - 2026-06-05

### 초기 SPM 배포

- **xcframework 기반 SPM 배포**: `gpi-tapfree.xcframework` (iOS arm64 + arm64/x86_64-simulator) 를 SPM 의 binaryTarget 으로 제공.
- **transitive 의존성 자동 해결**: 내부 deps carrier target (`gpi-tapfree-deps`) 이 `gpi-dltdoa`, `GEOSwift` 를 transitive 로 끌어와 사용 앱이 별도 선언 불필요.
- **버전 식별 파일**: `gpi-tapfree.xcframework/VERSION_2.0.0` 으로 배포 버전 식별 가능.
- **dSYM 동봉**: xcframework 내부에 `dSYMs/` 포함 — 크래시 발생 시 SDK 코드 위치 symbolication 가능.
