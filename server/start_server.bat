@echo off
set DB_HOST=127.0.0.1
set DB_PORT=3307
set DB_USER=uphone
set DB_PASSWORD=uphone_secret
set SERVER_PORT=8080
set GOOGLE_CLIENT_ID=108866653372-0dnm0th7a65s6bugimg9ab0up9kva925.apps.googleusercontent.com
cd /d C:\projects\uphone\server
uphone-server.exe
