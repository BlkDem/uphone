@echo off
set DB_HOST=127.0.0.1
set DB_PORT=3307
set DB_USER=uphone
set DB_PASSWORD=uphone_secret
set SERVER_PORT=8080
set UPLOAD_DIR=C:\projects\uphone\server\uploads
cd /d C:\projects\uphone\server
uphone-server.exe
