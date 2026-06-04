# gpi-tapfree (Swift Package)

본 저장소는 `gpi-tapfree` Tap-Free 측위/통신 코어 라이브러리의 외부 연동을 위한 **배포 전용 릴리즈 저장소(Release Repository)**이다.
사전 컴파일(Pre-compiled)된 `XCFramework` 형태의 바이너리를 SPM(Swift Package Manager) 포맷으로 독립 제공한다.
iOS 실기기(arm64) 및 시뮬레이터(arm64, x86_64) 빌드를 모두 지원하며, `gpi-tapfree.xcframework` 디렉토리 내부의 `VERSION_X.X.X` 파일을 통해 배포 버전을 확인할 수 있다.

> **💡 엔진 코어 역량 요약**
> Edge 서버와 **WebSocket + 자체 Straffic 바이너리 프로토콜** 로 통신하며, BLE Zone 스캔 / 영역 in-out 측위 / Payload 게이트 송수신을 통합한 Tap-Free 클라이언트.
> 내부적으로 `gpi-dltdoa` (UWB DL-TDoA) 및 `GEOSwift` (영역 in/out geometry) 를 transitive 의존성으로 자동 로드한다.

---

## 프로젝트 연동 및 사용 방법 (Usage)

외부 애플리케이션 타겟 프로젝트에서 본 라이브러리를 종속성으로 연동하고 코어 객체를 제어하는 표준 절차 명세이다.
진입점인 `TapfreePlatform` 클래스는 **싱글톤(Singleton)** 패턴으로 설계되어 있어 앱 전체 수명동안 단일 인스턴스로 동작한다.

### 1. Xcode 외부 패키지(SPM) 연동
가장 먼저 대상이 되는 타겟 App 프로젝트에 본 바이너리 프레임워크를 종속성으로 추가해야 한다.
1. 타겟 앱을 연 상태로 Xcode 상단 메뉴에서 **[File] ➡ [Add Package Dependencies...]** 를 클릭한다.
2. 우측 상단의 검색창(Search or Enter Package URL)에 아래의 SPM 배포 전용 저장소 주소를 입력한다.
   `https://github.com/Geoplan-Mobile/gpi-tapfree`
   *(주의: 저장소가 Private인 경우 본인의 깃허브 계정이 해당 저장소의 Collaborator로 사전에 등록되어 있어야 인증이 통과된다.)*
3. **Dependency Rule**을 필요에 맞게 설정한 뒤, **[Add Package]** 버튼을 클릭하여 연동을 완료한다.

> SPM 이 transitive 로 `gpi-dltdoa`, `GEOSwift` 까지 자동 fetch 한다. 사용 앱이 별도로 두 패키지를 추가할 필요는 없다.

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
    try platform.start(mobileId: "user-123", timerPeriod: 1000)  // 1초 주기
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
  * BLE 보드/이탈 이벤트도 별도 받고 싶을 때.
* **`func initialize(write: Bool, listener: PlatformListener?, bleListener: BlePlatformListener?) throws`**
  * `write` 가 true 면 내부 디버그 로그를 파일로 저장 (기본 false).
* **`func uninitialize() throws`** — 모든 리소스 해제.
* **`func isInitalized() -> Bool`** — 초기화 상태 조회. (오타이지만 외부 호환성 위해 유지)

#### 4. 측위 제어 (Tracking)
* **`func start(mobileId: String, timerPeriod: Int) throws`**
  * Zone 스캔 + 측위 파이프라인 시작. `timerPeriod` 는 측위 주기 (밀리초).
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
  * 현재 SDK 버전 문자열. 예: `"gpi-tapfree:2.0.0"`.

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
| `toBoard(zoneCode: String, aisleId: String, result: Bool)` | 게이트 보드 신호 검출 |
| `toExit(zoneCode: String, aisleId: String, result: Bool)` | 게이트 이탈 신호 검출 |
| `onRssi(mac: String, rssi: Int)` | BLE RSSI raw 측정값 |

### 열거형: `InOutEvent`
`onLocation` 의 `inOut` 인자 타입.

| 값 | 의미 |
|---|---|
| `.IN` (1) | 영역 진입 |
| `.OUT` (0) | 영역 진출 |

### 에러: `TapfreeError`
throws 메서드들이 던지는 에러 타입.

```swift
public enum TapfreeError: Error {
    case IllegalStateException(_ message: String)
    case IllegalArgumentException(_ message: String)
}
```
