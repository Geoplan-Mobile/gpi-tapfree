# SPM 전환 가이드

기존에 `gpi-tapfree` 의 소스를 앱 프로젝트 내에 **직접 임베드**하여 사용하던 환경을, 본 SPM 저장소(`https://github.com/Geoplan-Mobile/gpi-tapfree`) 의 **의존성 참조 방식** 으로 전환하기 위한 가이드입니다.

---

## 배경

`gpi-tapfree` 라이브러리가 별도 저장소로 분리되어 GitHub SPM 으로 정식 배포 중입니다. 임베드 소스 사용 방식은 더 이상 권장되지 않으며, SPM 의존성 방식으로 전환하시면 다음의 이점을 얻을 수 있습니다.

- 라이브러리 업데이트가 Xcode 의 **Update to Latest Package Versions** 한 번으로 적용됨
- transitive 의존성 (`gpi-dltdoa`, `GEOSwift`, `geos`) 이 자동 해결됨 — 별도 추가 불필요
- 임베드 소스로 인한 빌드 시간 / 디스크 사용 절감

---

## 변경 사항 요약

| # | 항목 | 작업 위치 |
|---|---|---|
| 1 | 임베드 소스 폴더 제거 | Xcode + 디스크 |
| 2 | `Podfile` 의 `pod 'GEOSwift'` 제거 (있다면) | Podfile (1 줄) |
| 3 | 옛 `gpi-dltdoa.xcframework` reference 제거 (있다면) | Xcode TARGETS 설정 |
| 4 | SPM 의존성 추가 (`https://github.com/Geoplan-Mobile/gpi-tapfree`, from `2.0.0`) | Xcode 설정 |
| 5 | 사용 측 Swift 파일에 `import gpi_tapfree` 추가 | 1 줄 |

> Nearby Interaction capability 와 `Info.plist` 의 `NSNearbyInteractionUsageDescription` 키는 **유지**합니다 (iOS API 권한이지 라이브러리 사항이 아님).

---

## 작업 절차

### 1. 기존 임베드 소스 제거

#### 1-1. Xcode 프로젝트 reference 제거

1. 앱 워크스페이스(`.xcworkspace`) 또는 프로젝트(`.xcodeproj`) 열기
2. 좌측 Navigator → 임베드된 `gpi-tapfree` 폴더 우클릭 → **Delete** → **"Move to Trash"**

#### 1-2. 디스크 정리

해당 폴더가 디스크에서 사라졌는지 확인.

---

### 2. 기존 별도 추가된 의존성 제거

옛 통합 안내에 따라 별도로 추가하셨던 다음 항목들은 **제거** 합니다. SPM 이 transitive 로 자동 가져오므로 그대로 두면 중복 link 충돌이 발생합니다.

#### 2-1. Podfile 의 GEOSwift 제거

`Podfile` 에 다음 줄이 있다면 삭제:

```ruby
pod 'GEOSwift', '~> 11.2'   # ← 삭제
```

그 다음:
```bash
pod install
```

#### 2-2. 옛 `gpi-dltdoa.xcframework` reference 제거

1. 프로젝트 → TARGETS → 앱 target → **General** 탭
2. **Frameworks, Libraries, and Embedded Content** 섹션에서 `gpi-dltdoa.xcframework` 항목 찾기
3. 선택 → `-` 버튼으로 제거 (임베드 폴더 제거 시 자동으로 사라졌을 수도 있음)

> **유지할 것** (UWB 사용 시):
> - `Info.plist` 의 `NSNearbyInteractionUsageDescription` 키
> - Signing & Capabilities 의 **Nearby Interaction** + **Nearby Interaction DL-TDoA (development)** 두 capability
>
> 이들은 iOS UWB API 사용에 필요한 entitlement 라 SPM 과 무관하게 유지해야 합니다.

---

### 3. SPM Package 의존성 추가

1. Xcode 메뉴: **File → Add Package Dependencies...**
2. 우측 상단 검색창에 URL 입력:
   ```
   https://github.com/Geoplan-Mobile/gpi-tapfree
   ```
3. **Dependency Rule**: `Up to Next Major Version` → `2.0.0`
4. **Add Package** 버튼 클릭
5. Product 선택 화면:
   - Product `gpi-tapfree` → "Add to Target" 컬럼에서 사용할 앱 target 체크
   - **Add Package**

> ⚠️ 본 저장소가 Private 상태일 경우, 작업자의 GitHub 계정이 `Geoplan-Mobile/gpi-tapfree` repo 의 Collaborator 로 등록되어 있어야 다운로드 인증이 통과됩니다. 권한 미보유 시 별도 요청 부탁드립니다.

---

### 4. Frameworks 설정 확인

1. 프로젝트 → TARGETS → 앱 target → **General** 탭
2. **Frameworks, Libraries, and Embedded Content** 섹션에서 `gpi-tapfree` 항목 확인
3. 우측의 **"Embed"** 옵션이 **"Embed & Sign"** 으로 설정되어 있는지 확인 (dynamic framework 이므로 앱 번들에 동봉 필수)

---

### 5. Swift import 추가

라이브러리를 사용하는 Swift 파일의 import 영역에 한 줄 추가:

```swift
import gpi_tapfree
```

> 모듈 이름이 `gpi-tapfree` 가 아닌 `gpi_tapfree` (underscore) 인 이유: Xcode 가 Swift identifier 제약상 dash 를 underscore 로 자동 변환합니다 (`gpi-dltdoa` 의 `import gpi_dltdoa` 와 동일 패턴).

---

### 6. 빌드 검증

1. **⌘⇧K** (Clean Build Folder)
2. **⌘B** (Build)
3. SPM 이 자동으로 fetch:
   - `gpi-tapfree @ 2.0.0`
   - `gpi-dltdoa @ 1.1.1` (transitive)
   - `GEOSwift @ 11.2.0` (transitive)
   - `geos @ 9.0.0` (GEOSwift 의 deps)
4. 컴파일 통과 확인 → ⌘R 실기기 실행 → 측위 로직 동작 검증

---

## 전환 이후의 운영 모델

본 전환이 완료되는 시점부터 **`gpi-tapfree` 의 모든 업데이트는 SPM 저장소를 통해서만** 진행됩니다.

| 대상 | 향후 운영 방식 |
|---|---|
| `gpi-tapfree` 신규 버전 | `Geoplan-Mobile/gpi-tapfree` 의 새 태그 발급 → 앱은 Xcode 의 "Update to Latest Package Versions" 만 실행 |
| 임베드 소스 (전환 전 사용분) | 더 이상 업데이트되지 않음 (전환 후 폴더 삭제) |
| 옛 통합 안내 문서 | 본 전환 이후 무효 |

라이브러리 변경 이력:
- [CHANGELOG.md](https://github.com/Geoplan-Mobile/gpi-tapfree/blob/main/CHANGELOG.md)
- GitHub Releases 탭

---

## 문제 발생 시

- SPM 의존성 fetch 실패 → 저장소 권한 확인, `~/Library/org.swift.swiftpm/security/fingerprints/` 캐시 점검 ([NOTES.md](https://github.com/Geoplan-Mobile/gpi-tapfree/blob/main/NOTES.md) 참조)
- import 시 모듈 미인식 → 모듈명은 `gpi_tapfree` (underscore) 임을 확인
- 빌드 시 중복 심볼 / link 충돌 → `Podfile` 의 GEOSwift, 옛 `gpi-dltdoa.xcframework` reference 가 남아 있는지 재확인
