@echo off
cd /d C:\projects\uphone\client\build\web
C:\Python312\python.exe -m http.server 3000 --bind 0.0.0.0 > C:\projects\uphone\webserver.log 2>&1
