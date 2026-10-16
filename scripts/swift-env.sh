# Source before `swift build` / `swift test` on Windows (toolchain lives on D:, MSVC on C:).
export SDKROOT='D:\tools\swift\Platforms\6.4.1\Windows.platform\Developer\SDKs\Windows.sdk\'
export PATH="/d/tools/swift/Toolchains/6.4.1+Asserts/usr/bin:/d/tools/swift/Runtimes/6.4.1/usr/bin:$PATH"
