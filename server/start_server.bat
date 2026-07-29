@echo off
rem UPhone local dev server — copy to start_local.bat and fill in credentials
set DB_HOST=127.0.0.1
set DB_PORT=3307
set DB_USER=uphone
set DB_PASSWORD=CHANGE_ME
set SERVER_PORT=8080
rem set GOOGLE_CLIENT_ID=your-google-client-id
cd /d C:\projects\uphone\server
uphone-server.exe
