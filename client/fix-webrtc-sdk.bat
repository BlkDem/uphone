@echo off
REM Run this after `flutter pub get` to fix flutter_webrtc compileSdk for AGP 9.x
REM flutter_webrtc 0.12.x ships compileSdk 31, but AGP 9.x requires >= 36

set PUB_CACHE=%LOCALAPPDATA%\Pub\Cache
set WEBRTC_BUILD=%PUB_CACHE%\hosted\pub.dev\flutter_webrtc-0.12.12+hotfix.1\android\build.gradle

if exist "%WEBRTC_BUILD%" (
    powershell -Command "(Get-Content '%WEBRTC_BUILD%') -replace 'compileSdkVersion 31', 'compileSdkVersion 36' | Set-Content '%WEBRTC_BUILD%'"
    echo Patched flutter_webrtc compileSdkVersion to 36
) else (
    echo flutter_webrtc not found in pub cache - skipping
)
