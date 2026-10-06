# gpa-tapfree (Android Library)

## 개요

`gpa-tapfree` 는 Tap-Free 측위/통신 코어 라이브러리의 **Android 클라이언트**다.
Edge 서버와 **WebSocket + 자체 Straffic 바이너리 프로토콜** 로 통신하며, BLE Zone 스캔 ·
영역 in/out 측위 · Payload 게이트 송수신을 통합해 제공한다.

Zone 진입을 감지하면 Edge 와 접속해 측위를 시작하고, 영역 진입 이벤트를 통지한다.
Zone 안에서 게이트(aisle) 와 추가 데이터를 주고받는 Payload 통신도 지원한다.

> 동일한 기능의 iOS 라이브러리(`gpi-tapfree`) 문서는 [저장소 루트의 README.md](../README.md) 를 참고한다.
> 라이프사이클 · 리스너 · 에러 코드는 iOS 와 일관되게 유지하지만, **버전 번호는 iOS 와 별개**로 관리한다.

---

## 배포 형태

사내 Nexus 에 `.aar` 아티팩트로 배포한다. 이 저장소에는 Android 용 **문서만** 있다.

| 항목 | 값 |
|---|---|
| groupId | `kr.geoplan.android.lib` |
| artifactId | `gpa-tapfree` |

---

## 요구 사항

| 항목 | 값 |
|---|---|
| Android | `minSdk` **27** 이상 (Android 8.1), `compileSdk` **37** |
| Java | 8 |
| UWB 측위 | Android 17+ 이면서 `android.ranging` 을 지원하는 UWB 탑재 기기 (`isAvailableDlTdoa()` 로 확인) |
| 네트워크 | 필요 (Edge 서버와 WebSocket 접속) |

- Android 8.1 이상 기기에서 BLE 측위 · Zone 추적 · Payload 통신이 동작한다.
- UWB DL-TDoA 는 지원 기기에서만 자동으로 활성화된다.

---

## 1. Gradle 연동

`settings.gradle` 에 사내 Nexus 저장소를 추가한다. **접속 계정·비밀번호는 Geoplan 에 문의**한다.

```gradle
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven {
            credentials {
                username "<발급 계정>"       // Geoplan 문의
                password "<발급 비밀번호>"    // Geoplan 문의
            }
            url "http://geoplan.iptime.org:30005/nexus/content/repositories/geoplan_release"
            allowInsecureProtocol true
        }
    }
}
```

앱 모듈의 `build.gradle` 에 의존성을 추가한다.

```gradle
android {
    compileSdk 37
    defaultConfig {
        minSdk 27
    }
}

dependencies {
    implementation 'kr.geoplan.android.lib:gpa-tapfree:<버전>'
}
```

> `gpa-dltdoa` · `gpa-mioc` 등 내부 의존은 Gradle 이 자동으로 함께 가져오므로 별도로 추가하지 않는다.
> 사용 가능한 버전은 [CHANGELOG.md](CHANGELOG.md) 를 참고한다.

---

## 2. 권한 설정

### AndroidManifest.xml

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.CHANGE_NETWORK_STATE" />

<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />

<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />

<uses-permission android:name="android.permission.RANGING" />
```

### 런타임 권한

- **런타임 권한은 앱이 직접 요청한다.** `ACCESS_FINE_LOCATION`, `BLUETOOTH_*`, `RANGING` 은
  `ActivityCompat.requestPermissions(...)` 로 사용자 승인을 받은 뒤 `initialize()` 를 호출한다.
- **정밀 위치가 필요하다.** UWB(DL-TDoA) 세션은 정밀 위치 권한이 없으면 시작되지 않는다.
- Bluetooth 와 시스템 위치 서비스가 꺼져 있으면 `onErr` 로 알린다. (5. 에러 코드 참고)

---

## 3. 사용 방법

진입점 `TapfreePlatform` 은 **싱글톤** 이다. 앱 전체 수명 동안 하나의 인스턴스로 동작한다.

### 3.1 초기화와 콜백 연결

`PlatformListener` (필수) 와 `BlePlatformListener` (선택) 를 연결한다.
초기화는 **네트워크 + BLE + GPS** 세 가지 준비가 모두 끝날 때까지 비동기로 보류되고, 준비되면
`onInitialized(boolean)` 가 호출된다.

```java
import kr.geoplan.android.lib.tapfree.TapfreePlatform;
import kr.geoplan.android.lib.tapfree.listener.PlatformListener;

public class MyTapfreeService implements PlatformListener {
    private final TapfreePlatform platform = TapfreePlatform.getInstance();

    public void setup(Context context) {
        platform.initialize(context, this);
    }

    @Override
    public void onInitialized(boolean isSuccess) {
        if (!isSuccess) return;
        // 초기화 성공 → start 가능
    }

    // … (이하 PlatformListener 의 다른 콜백 구현)
}
```

`initialize(...)` 가 throw 하지 않았다면 **반드시 `onInitialized` 를 기다려** 성공/실패를 처리한다.
환경 · 권한 실패(Bluetooth OFF, 위치 OFF 등)는 throw 가 아니라 `onErr` 1회 + `onInitialized(false)` 1회로 알린다.

### 3.2 측위 시작 (`start`)

초기화가 끝나면 사용자의 mobile ID 와 타이머 주기를 지정해 측위를 시작한다.
Zone 진입이 감지되면 `onStartedTracking(zoneCode)` 가 호출되고, 영역 진입 이벤트는 `onLocation(...)` 으로 전달된다.

```java
try {
    // mobileId 는 정확히 16자리 hex 문자열이어야 한다.
    platform.start("96098E4A538261C3", 1000);  // 1초 주기
} catch (IllegalStateException | IllegalArgumentException e) {
    // 호출 오류 처리
}

@Override
public void onStarted() {
    Log.i(TAG, "측위 시작 완료");
}

@Override
public void onStartedTracking(String zoneCode) {
    Log.i(TAG, "Zone 진입: " + zoneCode);
}

@Override
public void onLocation(String zoneCode, String areaName, InOutEvent inout, long eventTime) {
    Log.i(TAG, "영역 진입: " + zoneCode + "/" + areaName + " @ " + eventTime);
}
```

> **`mobileId` 는 기기 · 앱 인스턴스 사이에서 중복되면 안 된다.** 같은 `mobileId` 로 다른 기기가 접속하면
> Edge 가 기존 세션을 종료한다. 자세한 동작은 5. 에러 코드 아래 주의 사항을 참고한다.

### 3.3 Payload 통신 (선택)

Zone 안에서 게이트(aisle) 와 데이터를 주고받으려면 connect → send → receive 흐름을 사용한다.

```java
// 게이트와 통신 채널 연결
platform.connectPayload("ZONE_A", "GATE_1");

// 연결 준비 완료
@Override
public void onConnectedPayload(String zoneCode, String aisleId) {
    byte[] bytes = new byte[]{0x01, 0x02, 0x03};
    platform.sendPayload(bytes);
}

// 게이트로부터 수신
@Override
public void onReceivedPayload(byte[] payload) {
    Log.i(TAG, "게이트 payload 수신: " + payload.length + " bytes");
}

// 통신 종료
platform.disconnectPayload("ZONE_A", "GATE_1");
```

`zoneCode` 는 `onStartedTracking` 으로 받은 값을 사용한다. 해당 Zone 에서 이탈하면 연결된 Payload 는
`onDisconnectedPayload` 와 함께 종료된다.

### 3.4 중지 / 해제

```java
int result = platform.stop();
// TapfreePlatform.SUCCESS 면 정상, TapfreePlatform.ALREADY_STOP 이면 이미 중지된 상태

platform.uninitailize();   // 철자는 외부 호환을 위해 유지된다
```

### 3.5 로그 파일

라이브러리는 동작 로그를 앱 전용 외부 저장소에 파일로 남긴다. 별도 권한은 필요하지 않다.

```
/sdcard/Android/data/<앱 패키지명>/files/gpa-tapfree/yyyyMMdd.txt
```

- 날짜별로 한 파일이 만들어지고, 최근 5일 분만 보관한다.
- 문제 분석이 필요하면 이 폴더를 전달한다. (`adb pull /sdcard/Android/data/<앱 패키지명>/files/gpa-tapfree`)
- 로그에는 `mobileId` 와 Edge 와 주고받은 데이터(hex)가 포함될 수 있으니 외부로 전달할 때 유의한다.

---

## 4. API 레퍼런스

### 클래스: `TapfreePlatform`

엔진의 모든 동작을 주관하는 싱글톤 컨트롤러.

#### 인스턴스 획득
- **`static TapfreePlatform getInstance()`** — 싱글톤 인스턴스.
- **`static boolean isAvailableDlTdoa(Context context)`** — 현재 기기에서 DL-TDoA 사용 가능 여부 (UWB 하드웨어 + Android 17+).

#### 상태 상수
- **`SUCCESS = 0`** — `stop()` 성공.
- **`ALREADY_STOP = 10`** — `stop()` 호출 시 이미 중지된 상태.

#### 초기화 / 해제
- **`void initialize(Context context, PlatformListener listener)`** — 기본 형태.
- **`void initialize(Context context, PlatformListener listener, BlePlatformListener bleListener)`** — BLE 보드/이탈/RSSI raw 이벤트를 `bleListener` 로도 받는다.
- **`void initialize(Context context, PlatformListener listener, BlePlatformListener bleListener, boolean forceCellular)`** — `forceCellular` 가 true 면 Wi-Fi 가 가능해도 셀룰러 회선을 우선 사용한다. 기본값 true.
- **`void uninitailize()`** — 모든 리소스 해제.
- **`boolean isInitialized()`** — 초기화 상태 조회.

#### 측위 제어
- **`void start(String mobileId, int timerPeriod)`**
- **`void start(String mobileId, int timerPeriod, String ddnsDomain)`**
  - Zone 스캔과 측위를 시작한다.
  - `mobileId` 는 **정확히 16자리 hex 문자열** (`^[a-fA-F0-9]{16}$`). 위반하면 `IllegalArgumentException`.
  - `timerPeriod` 는 마지막 진입 영역을 주기적으로 `onLocation` 으로 다시 알리는 간격(ms). **50 이하** 이면 주기 호출을 하지 않고 영역 진입 이벤트 시점에만 호출한다.
  - `ddnsDomain` 은 Edge 접속 호스트에 쓰는 DDNS 도메인. 기본값 `"cns-link.net"` 이며 다른 DDNS 를 쓰는 사이트만 지정한다.
- **`int stop()`** — 측위 중지. `SUCCESS` 또는 `ALREADY_STOP`.
- **`void forceOut()`** — 모든 Zone 에서 강제로 OUT 처리한다. Zone 안에서 호출하면 광고가 계속 들어오므로 다시 접속될 수 있다.

#### Payload 게이트 통신 (선택)
- **`void connectPayload(String zoneCode, String aisleId)`** — 게이트와 통신 채널 연결. 성공하면 `onConnectedPayload`.
- **`void sendPayload(byte[] payload)`** — 연결된 게이트로 송신.
- **`void disconnectPayload(String zoneCode, String aisleId)`** — 통신 종료.

동시에 연결할 수 있는 Payload 는 **하나**다.

#### BLE 신호 보정
- **`void setRssiOffset(int offset)`** — BLE RSSI 에 더하는 보정값(기기 편차 보정용).
- **`int getRssiOffset()`** — 현재 보정값.

### 인터페이스: `PlatformListener` (필수)

| 콜백 | 호출 시점 |
|---|---|
| `onInitialized(boolean isSuccess)` | initialize 완료 (네트워크 · BLE · GPS 준비) |
| `onUninitialized()` | uninitailize 완료 |
| `onStarted()` | start 성공 |
| `onStopped()` | stop 성공, 또는 오류로 자동 중지 |
| `onStartedTracking(String zoneCode)` | Zone 진입 → 측위 시작 |
| `onStoppedTracking(String zoneCode)` | Zone 이탈 · 소켓 종료 · stop → 측위 종료 |
| `onConnectedPayload(String zoneCode, String aisleId)` | 게이트 통신 채널 준비 완료 |
| `onDisconnectedPayload(String zoneCode, String aisleId)` | 게이트 통신 채널 종료 |
| `onLocation(String zoneCode, String areaName, InOutEvent inout, long eventTime)` | 영역 진입 이벤트 |
| `onReceivedPayload(byte[] payload)` | 게이트로부터 데이터 수신 |
| `onErr(int code, String msg)` | 에러 발생 |

### 인터페이스: `BlePlatformListener` (선택)

BLE 보드/이탈/RSSI raw 이벤트를 추가로 받고 싶을 때 `initialize(...)` 오버로드로 등록한다.

| 콜백 | 호출 시점 |
|---|---|
| `toBoard(String zoneCode, String aisleId, boolean result)` | BLE 광고 수신마다. `result` = 현재 boarding 구간 안인지 |
| `toExit(String zoneCode, String aisleId, boolean result)` | BLE 광고 수신마다. `result` = 현재 exit 구간 안인지 |
| `onRssi(String mac, int rssi)` | BLE 광고 수신마다. 해당 광고의 raw RSSI |

> **호출 빈도 주의** — 세 콜백은 모두 BLE 광고 수신마다(보통 초당 10회 이상) 호출된다.
> `result` 는 상태 전이가 아니라 **현재 상태**이므로, 전이 시점을 잡으려면 이전 값과 비교해야 한다.

### 열거형: `InOutEvent`

| 값 | 의미 |
|---|---|
| `IN` (1) | 영역 진입 |
| `OUT` (0) | 영역 진출 |

> `onLocation` 의 `inout` 은 사실상 **항상 `IN`** 이다. 영역 전이는 "다음 영역의 IN 이벤트" 도래로 판단한다.

### 예외

`start(...)` · `connectPayload(...)` 등은 **호출자 코드 결함**(이미 초기화됨, 인자 형식 위반 등)만
`IllegalStateException` / `IllegalArgumentException` 으로 throw 한다. 환경 · 권한 · 런타임 실패는 `onErr` 로 전달한다.

---

## 5. 에러 코드

`onErr(int code, String msg)` 로 전달한다. 발생 시점에 따라 다른 콜백이 함께 호출된다.

- **`initialize` 중 발생** — `onErr` 와 함께 `onInitialized(false)`.
- **`start` 이후 발생** — 코드에 따라 `onStopped()` 가 함께 호출된다.

| 코드 | 의미 | 발생 시점 | 함께 호출되는 콜백 |
|---:|---|---|---|
| `1` | `LOST_DATA_NETWORK` | `start` 이후 셀룰러/데이터 네트워크가 끊긴 경우 | `onStopped()` |
| `2` | `FAIL_INITIALIZE` | `initialize` 중 네트워크 인터페이스 초기화 실패 | `onInitialized(false)` |
| `3` | `FAIL_START_SCAN` | `start` 이후 BLE 스캔 시작 실패 (msg 에 OS errorCode) | `onStopped()` |
| `4` | `BLUETOOTH_OFF` | Bluetooth 가 꺼져 있거나 권한이 거부된 경우 | `initialize` 중: `onInitialized(false)` / `start` 이후: `onStopped()` |
| `5` | `GPS_OFF` | 시스템 위치 서비스가 꺼져 있거나 권한이 거부된 경우 | `initialize` 중: `onInitialized(false)` / `start` 이후: `onStopped()` |

> **`mobileId` 중복 시 동작 (현재 버전)**
> - 같은 `mobileId` 로 다른 기기가 Edge 에 접속하면 Edge 는 **최신 접속을 우선**하고 기존 세션을 종료한다.
> - 종료된 기기는 Zone 안에 있으면 다시 접속을 시도하므로, 두 기기가 서로 접속을 밀어낼 수 있다.
> - 따라서 호출 측은 **`mobileId` 가 기기 · 앱 인스턴스 사이에서 중복되지 않도록** 반드시 관리해야 한다.
