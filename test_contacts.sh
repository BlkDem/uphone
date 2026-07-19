#!/bin/bash
LOGIN_RESP=$(curl -s -X POST http://192.168.1.18:8080/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"maksim@uphone.local","password":"password"}')
echo "Login: $LOGIN_RESP"
TOKEN=$(echo "$LOGIN_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
echo "Token: $TOKEN"
CREATE_RESP=$(curl -s -X POST http://192.168.1.18:8080/api/v1/contacts \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"display_name":"Test Contact","email":"test@test.com","phone":"+1234567"}')
echo "Create: $CREATE_RESP"
