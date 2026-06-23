# gpi-tapfree (Swift Package)

본 저장소는 `gpi-tapfree` Tap-Free 측위/통신 코어 라이브러리의 외부 연동을 위한 **배포 전용 릴리즈 저장소(Release Repository)**이다.
사전 컴파일(Pre-compiled)된 `XCFramework` 형태의 바이너리를 SPM(Swift Package Manager) 포맷으로 독립 제공한다.
iOS 실기기(arm64) 및 시뮬레이터(arm64, x86_64) 빌드를 모두 지원하며, `gpi-tapfree.xcframework` 디렉토리 내부의 `VERSION_X.X.X` 파일을 통해 배포 버전을 확인할 수 있다.

> **💡 엔진 코어 역량 요약**
> Edge 서버와 **WebSocket + 자체 Straffic 바이너리 프로토콜** 로 통신하며, BLE Zone 스캔 / 영역 in-out 측위 / Payload 게이트 송수신을 통합한 Tap-Free 클라이언트.
> 내부적으로 `gpi-dltdoa` (UWB DL-TDoA) 및 `GEOSwift` (영역 in/out geometry) 를 transitive 의존성으로 자동 로드한다.

> ⚠️ **빌드 요구사항 (2.0.3 부터)** — 사용 앱은 반드시 **Xcode 27 이상** 으로 빌드해야 link 가 통과한다.
>
> ⓘ **런타임 지원 (2.0.3 부터)** — **iOS 18+ 디바이스에서 동작** (BLE 측위/Zone 추적/Payload 통신). **UWB DL-TDoA 는 iOS 27+ 디바이스 한정** 으로 자동 활성화, iOS 18–26 디바이스에서는 BLE 모드로만 동작.

---

## 프로젝트 연동 및 사용 방법 (Usage)

외부 애플리케이션 타겟 프로젝트에서 본 라이브러리를 종속성으로 연동하고 코어 객체를 제어하는 표준 절차 명세이다.
진입점인 `TapfreePlatform` 클래스는 **싱글톤(Singleton)** 패턴으로 설계되어 있어 앱 전체 수명동안 단일 인스턴스로 동작한다.

### 1. Xcode 외부 패키지(SPM) 연동
가장 먼저 대상이 되는 타겟 App 프로젝트에 본 바이너리 프레임워크를 종속성으로 추가해야 한다.
1. 타겟 앱을 연 상태로 Xcode 상단 메뉴에서 **[File] ➡ [Add Package Dependencies...]** 를 클릭한다.
2. 우측 상단의 검색창(Search or Enter Package URL)에 아래의 SPM 배포 전용 저장소 주소를 입력한다.
   `https://github.com/Geoplan-Mobile/gpi-tapfree`
3. **Dependency Rule**을 필요에 맞게 설정한 뒤, **[Add Package]** 버튼을 클릭하여 연동을 완료한다.

> SPM 이 transitive 로 내부 디펜던시인 `gpi-dltdoa`, `GEOSwift` 까지 자동 fetch 한다.

### 2. TapfreePlatform 초기화 및 콜백 리스너 연결
싱글톤 인스턴스를 획득하고 `PlatformListener` (필수) / `BlePlatformListener` (선택) 를 연결한다.
초기화는 **네트워크 + BLE + GPS** 세 가지 준비가 모두 완료될 때까지 비동기로 보류되며, 준비되면 `onInitialized(isSuccess:)` 가 호출된다.

```swift
import gpi_tapfree

class MyTapfreeService: PlatformListener {
    let platform = TapfreePlatform.getInstance()

    func setup() throws {
        // 1. 초기화 (콜백 리스너 등록)
        try platform.initialize(listener: self)
    }

    // 2. 준비 완료 콜백
    func onInitialized(isSuccess: Bool) {
        guard isSuccess else { return }
        // 초기화 성공 → start 가능
    }

    // … (이하 PlatformListener 의 다른 콜백 구현)
}
```

### 3. 측위 시작 (`start`)
초기화 완료 후 사용자의 mobile ID 와 타이머 주기를 지정해 측위/통신 파이프라인을 가동한다.
Zone 진입이 감지되면 `onStartedTracking(zoneCode:)` 가 호출되고, 영역 in/out 이벤트는 `onLocation(...)` 으로 흘러나온다.

```swift
do {
    // mobileId 는 정확히 16자리 hex 문자열이어야 한다.
    try platform.start(mobileId: "96098E4A538261C3", timerPeriod: 1000)  // 1초 주기
} catch {
    // TapfreeError 처리
}

// 콜백
func onStarted() {
    print("측위 시작 완료")
}

func onStartedTracking(_ zoneCode: String) {
    print("Zone 진입: \(zoneCode)")
}

func onLocation(_ zoneCode: String, _ areaName: String, _ inOut: InOutEvent, _ eventTime: Int64) {
    switch inOut {
    case .IN:  print("영역 진입: \(zoneCode)/\(areaName) @ \(eventTime)")
    case .OUT: print("영역 진출: \(zoneCode)/\(areaName) @ \(eventTime)")
    }
}
```

### 4. Payload 통신 (선택)
Zone 안에서 게이트(`aisle`) 과 추가 데이터 송수신이 필요한 경우 connect → send → receive 흐름을 사용한다.

```swift
// 게이트와 통신 채널 연결
try platform.connectPayload(zoneCode: "ZONE_A", aisleId: "GATE_1")

// 콜백 - 연결 준비 완료
func onConnectedPayload(_ zoneCode: String, _ aisleId: String) {
    let bytes: [UInt8] = [0x01, 0x02, 0x03]
    try? platform.sendPayload(payload: bytes)
}

// 콜백 - 게이트로부터 수신
func onReceivedPayload(_ payload: Data) {
    print("게이트 payload 수신: \(payload.count) bytes")
}

// 통신 종료
try platform.disconnectPayload(zoneCode: "ZONE_A", aisleId: "GATE_1")
```

### 5. 중지 / 해제
플랫폼 수명 종료 시 명시적으로 stop → uninitialize 한다.

```swift
let result = platform.stop()
// result 가 TapfreePlatform.SUCCESS 면 정상, TapfreePlatform.ALREADY_STOP 이면 이미 중지된 상태

try platform.uninitialize()
```

---

## API 레퍼런스 (API Reference)

라이브러리에서 대외적으로 개방(Public)된 핵심 클래스와 프로퍼티/메서드의 기술 명세서이다.

### 클래스: `TapfreePlatform`
엔진의 모든 동작을 주관하는 싱글톤 컨트롤러 객체이다. `@unchecked Sendable` 로 선언되어 멀티스레드 환경에서 사용 가능.

#### 1. 인스턴스 획득
* **`static func getInstance() -> TapfreePlatform`**
  * 싱글톤 인스턴스를 반환한다. 앱 전체 수명 동안 동일 객체.

#### 2. 상태 상수 (Static Constants)
* **`static let SUCCESS: Int = 0`** — `stop()` 호출 성공 시 반환값.
* **`static let ALREADY_STOP: Int = 10`** — `stop()` 호출 시 이미 중지 상태였음을 의미.

#### 3. 초기화 / 해제 (Lifecycle)
* **`func initialize(listener: PlatformListener?) throws`**
  * 가장 기본 형태. 네트워크/BLE/GPS 준비가 모두 완료될 때까지 비동기 대기 후 `onInitialized(isSuccess:)` 호출.
* **`func initialize(listener: PlatformListener?, bleListener: BlePlatformListener?) throws`**
  * 기본 `initialize(listener:)` 의 모든 기능을 포함하며, 추가로 BLE 보드/이탈/RSSI raw 이벤트를 `bleListener` 로 받을 수 있다.
* **`func initialize(write: Bool, listener: PlatformListener?, bleListener: BlePlatformListener?) throws`**
  * 위 두 오버로드의 모든 기능을 포함하며, 추가로 `write` 가 true 면 내부 디버그 로그를 파일로 저장 (기본 false).

> ⓘ **`initialize(...)` 의 응답 모델** — 세 오버로드 모두 동일.
> - **throw** 는 호출자 코드 결함만 (이미 초기화 / listener nil) — `try ... catch` 로 처리.
> - **환경·권한 실패** (Info.plist 키 누락, Location 권한 미부여, BT OFF 등) 는 throw 가 아니라 **`onError(code, msg)` 1회 + `onInitialized(isSuccess: false)` 1회** 가 쌍으로 호출된다.
> - **정상 준비 완료** 시는 `onInitialized(isSuccess: true)` 1회.
> - 즉 호출자는 `try initialize(...)` 가 throw 하지 않았다면 **반드시 `onInitialized` 콜백을 기다려** 성공/실패 분기를 처리해야 한다. (false 분기 미구현 시 실패 케이스가 묵살된다)

* **`func uninitialize() throws`** — 모든 리소스 해제.
* **`func isInitalized() -> Bool`** — 초기화 상태 조회. (오타이지만 외부 호환성 위해 유지)

#### 4. 측위 제어 (Tracking)
* **`func start(mobileId: String, timerPeriod: Int, ddnsDomain: String = "cns-link.net") throws`**
  * Zone 스캔 + 측위 파이프라인 시작.
  * `mobileId` 는 **정확히 16 자리 16 진수(hex) 문자열** 이어야 한다 (대/소문자 무관, 정규식 `^[a-fA-F0-9]{16}$`). 위반 시 `IllegalArgumentException("INVALID ID USED")` throw.
  * `timerPeriod` 는 **마지막 진입 영역(area) 주기 호출 간격 (밀리초)**. `onLocation(...)` 는 두 경로로 호출되며 이 파라미터는 두 번째 경로의 주기를 정한다.
    * **이벤트 시점** — 실제 영역 진입(IN) 발생 시 즉시 1회 (`timerPeriod` 와 무관, 항상 발생). 이때 마지막 진입 영역 정보가 갱신된다.
    * **주기 호출** — 이후 새 진입 이벤트가 들어오기 전까지 `timerPeriod` 간격으로 마지막 진입 영역을 반복 호출.
    * **`50` 이하** 값을 주면 주기 호출은 **비활성** — 진입 이벤트 시점에만 `onLocation` 호출.
  * `ddnsDomain` 은 Edge 접속 호스트 구성에 사용하는 DDNS 도메인. 기본값 `"cns-link.net"` 이라 기존 호출부는 그대로 동작하며, 다른 DDNS 를 쓰는 사이트만 명시 override.
* **`func stop() -> Int`**
  * 측위 중지. `SUCCESS` 또는 `ALREADY_STOP` 반환.
* **`func forceOut()`**
  * 강제로 Zone 이탈 처리.

#### 5. Payload 게이트 통신 (Optional)
* **`func connectPayload(zoneCode: String, aisleId: String) throws`**
  * 특정 게이트와 통신 채널 연결. 성공 시 `onConnectedPayload(_:_:)` 콜백.
* **`func sendPayload(payload: [UInt8]?) throws`**
  * 연결된 게이트로 바이트 배열 송신.
* **`func disconnectPayload(zoneCode: String, aisleId: String) throws`**
  * 게이트와 통신 종료.

#### 6. BLE 신호 보정
* **`func setRssiOffset(offset: Int)`**
  * BLE RSSI 측정값에 가산할 오프셋. (기기 편차 보정용)
* **`func getRssiOffset() -> Int`**
  * 현재 RSSI 오프셋.

#### 7. 메타
* **`func getLibraryVersion() -> String`**
  * 현재 SDK 버전 문자열. 예: `"2.0.3"`.
  * (참고: 2.0.3 부터 prefix 없는 순수 버전 문자열로 변경. 이전 버전은 `"gpi-tapfree:<버전>"` 형식)

---

### 프로토콜: `PlatformListener`
필수 콜백 인터페이스. 모든 메서드 구현 필요.

| 콜백 | 호출 시점 |
|---|---|
| `onInitialized(isSuccess: Bool)` | initialize 완료 (네트워크/BLE/GPS 모두 준비) |
| `onUninitialized()` | uninitialize 완료 |
| `onStarted()` | start 성공 |
| `onStopped()` | stop 성공 |
| `onStartedTracking(_ zoneCode: String)` | Zone 진입 → 측위 시작 |
| `onStoppedTracking(_ zoneCode: String)` | Zone 이탈 → 측위 종료 |
| `onConnectedPayload(_ zoneCode: String, _ aisleId: String)` | 게이트 통신 채널 준비 완료 |
| `onDisconnectedPayload(_ zoneCode: String, _ aisleId: String)` | 게이트 통신 채널 종료 |
| `onLocation(_ zoneCode: String, _ areaName: String, _ inOut: InOutEvent, _ eventTime: Int64)` | 영역 진입/진출 이벤트 |
| `onReceivedPayload(_ payload: Data)` | 게이트로부터 데이터 수신 |
| `onError(_ code: Int, _ msg: String)` | 에러 발생 |

### 프로토콜: `BlePlatformListener` (선택)
BLE 보드/이탈/RSSI 의 raw 이벤트를 추가로 받고 싶을 때.

| 콜백 | 호출 시점 |
|---|---|
| `toBoard(zoneCode: String, aisleId: String, result: Bool)` | BLE 광고 수신마다. `result` = 현재 boarding 구간 안에 있는지 여부 |
| `toExit(zoneCode: String, aisleId: String, result: Bool)` | BLE 광고 수신마다. `result` = 현재 exit 구간 안에 있는지 여부 |
| `onRssi(mac: String, rssi: Int)` | BLE 광고 수신마다. 해당 광고의 raw RSSI 값 |

> ⚠️ **호출 빈도 주의** — 위 3 콜백은 모두 **BLE 광고 수신마다** 호출된다 (보통 초당 10 회 이상). 같은 광고 1 건당 `onRssi` + `toBoard` + `toExit` 가 연속해서 호출된다. 또한 `toBoard` / `toExit` 의 `result` 는 **상태 전이 (false→true) 가 아니라 현재 상태** 이므로, "방금 boarding 진입함" 같은 전이 시점을 잡으려면 호출 측에서 이전 result 와 비교해 판단해야 한다.

### 열거형: `InOutEvent`
`onLocation` 의 `inOut` 인자 타입.

| 값 | 의미 |
|---|---|
| `.IN` (1) | 영역 진입 |
| `.OUT` (0) | 영역 진출 |

> ⚠️ **InOutEvent.OUT 은 호출되지 않는다** — Edge 서버와 라이브러리(UwbZone) 양쪽 모두 명시적으로 IN 이벤트만 모바일에 전달한다 (영역 경계 떨림 노이즈 회피 및 Android/iOS 정책 정렬). 따라서 `onLocation` 의 `inOut` 인자는 사실상 항상 `.IN`. 영역 전이는 "다음 영역의 IN 이벤트" 도래로 추론한다. `InOutEvent.OUT` 분기는 향후 정책 변경 대비 호환성 목적으로만 유지.

### 에러: `TapfreeError`
throws 메서드들이 던지는 에러 타입. `try initialize(...)` / `try start(...)` / `try connectPayload(...)` 등의 메서드 호출 시점에 발생하는 **호출자 코드 결함** (이미 초기화됨, 인자 형식 위반 등) 만 throw 된다.

```swift
public enum TapfreeError: Error {
    case IllegalStateException(_ message: String)
    case IllegalArgumentException(_ message: String)
}
```

### 에러 코드: `onError(_ code: Int, _ msg: String)` 의 `code` 값

환경/권한/런타임 실패는 throw 가 아닌 **비동기 `onError` 콜백** 으로 전달된다. 발생 시점에 따라 추가 콜백이 함께 호출된다:

- **`initialize` 중 발생** — `onError` 와 함께 **`onInitialized(isSuccess: false)`** 가 호출된다.
- **`start` 이후 (payload 연결 중 포함) 발생** — 모든 연결 및 동작이 중지되고 **`onStopped()`** 가 호출된다.

| 코드 | 의미 | 발생 시점 | 함께 호출되는 콜백 |
|---:|---|---|---|
| `1` | `LOST_DATA_NETWORK` | `start 이후` 셀룰러/데이터 네트워크가 끊긴 경우 | `onStopped()` |
| `2` | `FAIL_INITIALIZE` | `initialize 단계` 에서 네트워크 인터페이스 초기화 실패 | `onInitialized(isSuccess: false)` |
| `3` | `FAIL_START_SCAN` | `start 이후` 내부 BLE 스캔 시작 실패 | `onStopped()` |
| `4` | `BLUETOOTH_OFF` | 시스템에서 Bluetooth 가 OFF 상태이거나 `.resetting` / `.unsupported` 로 사용 불가 (권한 거부는 별개 — 코드 8) | `initialize 단계`: `onInitialized(isSuccess: false)`. `start 이후`: `onStopped()` |
| `5` | `GPS_OFF` | 시스템 Location Services 가 OFF 상태이거나 권한 거부/제한된 상태 | `initialize 단계`: `onInitialized(isSuccess: false)`. `start 이후`: `onStopped()` |
| `6` | `DL_TDOA_ERROR` | `start 이후` DL-TDoA(UWB) 세션 오류 (iOS 전용 — Android 에는 대응 코드 없음) | 없음 — `onLocation` 등 후속 콜백 그대로 계속 |
| `7` | `LOCATION_PERMISSION_REQUIRED` | `initialize 단계`, Location 권한 미요청/거부/제한 | `onInitialized(isSuccess: false)` |
| `8` | `BLUETOOTH_PERMISSION_REQUIRED` | Bluetooth 권한 거부/제한 | `initialize 단계`: `onInitialized(isSuccess: false)`. `start 이후`: `onStopped()` |
| `10` | `BT_USAGE_DESCRIPTION_MISSING` | `initialize 단계`, 앱 Info.plist 에 `NSBluetoothAlwaysUsageDescription` 키 누락 (빌드 단계 결함) | `onInitialized(isSuccess: false)` |
| `11` | `SESSION_TAKEN_OVER` | `start 이후`, 같은 `mobileId` 로 다른 디바이스/인스턴스가 Edge 에 새로 접속해 현 세션이 중복 종료된 경우 | `onStopped()` |

> ⚠️ **`mobileId` 중복 정책 (중요)**
> - **`mobileId` 중복은 매우 치명적인 오류**로 간주하여, 감지 즉시 라이브러리가 **무조건 `stop()`** 한다 (자동 재시도 없음). _(gpi-tapfree 2.0.3+)_
> - **최신 연결이 우선시** — 새로 접속한 클라이언트가 세션을 가져가고, **기존에 연결되어 있던 클라이언트가 `stop()`** 된다.
> - 따라서 호출 측은 **`mobileId` 가 디바이스/인스턴스 간 중복되지 않도록 반드시 유의**해야 한다.

