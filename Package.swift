// swift-tools-version: 5.9
//
// gpi-tapfree 배포 매니페스트.
// 소스 저장소는 별도로 존재하고, 본 저장소는 미리 빌드된 gpi-tapfree.xcframework 만 배포한다.
// 사용 앱은 본 저장소의 SPM URL 만 의존하면 transitive 로 gpi-dltdoa, GEOSwift 까지 자동 해결.
//

import PackageDescription

let package = Package(
    name: "gpi-tapfree",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        // 두 target 을 한 라이브러리로 묶음.
        // 사용 앱은 .product(name: "gpi-tapfree", ...) 한 줄로 binary + deps 모두 build graph 에 포함.
        .library(
            name: "gpi-tapfree",
            targets: ["gpi-tapfree", "gpi-tapfree-deps"]
        ),
    ],
    dependencies: [
        // DL-TDoA UWB 측위 엔진 (사내 binary SPM).
        .package(
            url: "https://github.com/Geoplan-Mobile/gpi-dltdoa.git",
            from: "1.1.1"
        ),
        // 영역 in/out 판정용 geometry.
        .package(
            url: "https://github.com/GEOSwift/GEOSwift.git",
            from: "11.2.0"
        ),
    ],
    targets: [
        // 실제 라이브러리 (사용자가 import 하는 대상).
        // 모듈 이름은 dash 가 underscore 로 자동 변환되어 사용자는 `import gpi_tapfree` 로 사용.
        .binaryTarget(
            name: "gpi-tapfree",
            path: "gpi-tapfree.xcframework"
        ),
        // deps 캐리어. SPM 의 binaryTarget 이 dependencies 인자를 받지 못하는 제약을 우회하기 위한 placeholder.
        // 사용 앱은 이 모듈의 존재를 인지하지 못하지만 build graph 에 포함되어 transitive 의존성 link 를 끌어옴.
        .target(
            name: "gpi-tapfree-deps",
            dependencies: [
                .product(name: "gpi-dltdoa", package: "gpi-dltdoa"),
                .product(name: "GEOSwift", package: "GEOSwift"),
            ],
            path: "Sources/gpi-tapfree-deps"
        ),
    ]
)
