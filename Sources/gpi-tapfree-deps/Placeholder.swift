// SPM 의 "Swift target 은 최소 1개의 .swift 파일이 필요" 라는 요구를 충족하기 위한 빈 파일.
//
// 이 target (gpi-tapfree-deps) 의 실질 역할은 Package.swift 의 dependencies 인자로
// gpi-dltdoa, GEOSwift 를 짊어지는 것 — binaryTarget 이 직접 deps 를 선언할 수 없는
// SPM 제약을 우회하기 위함. 사용자 코드는 이 모듈을 import 하지 않으며 존재 자체를 인지하지 않는다.
