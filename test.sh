#!/usr/bin/env bash
# Full API test suite. Requires: curl, python3
# Start the server first: uv run uvicorn app.main:app --reload

BASE="http://localhost:8000"
PASS=0
FAIL=0

# Unique suffix so re-runs don't collide on the persistent DB
TS=$(date +%s)
USER_A="alice_$TS"
USER_B="bob_$TS"
PASS_A="password123"
PASS_B="password456"

# Extract a top-level JSON key without jq
json_get() { python3 -c "import sys,json; print(json.loads(sys.argv[1]).get('$1',''))" "$2"; }

check() {
  local label="$1" expected="$2" actual="$3"
  if echo "$actual" | grep -q "$expected"; then
    echo "  PASS  $label"
    ((PASS++))
  else
    echo "  FAIL  $label"
    echo "         expected: $expected"
    echo "         got:      $actual"
    ((FAIL++))
  fi
}

check_absent() {
  local label="$1" unexpected="$2" actual="$3"
  if echo "$actual" | grep -q "$unexpected"; then
    echo "  FAIL  $label (unexpected match)"
    echo "         should not contain: $unexpected"
    ((FAIL++))
  else
    echo "  PASS  $label"
    ((PASS++))
  fi
}

hr() { echo; echo "── $1 ──────────────────────────────────"; }

# ─── Auth: register + login ───────────────────────────────────────────────────

hr "POST /auth/register — registration"

R=$(curl -s -X POST "$BASE/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USER_A\",\"password\":\"$PASS_A\"}")
check "register $USER_A (201)" '"username"' "$R"
check "response has user id" '"id"' "$R"

R=$(curl -s -X POST "$BASE/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USER_B\",\"password\":\"$PASS_B\"}")
check "register $USER_B (201)" '"username"' "$R"

# Duplicate username → 409
R=$(curl -s -X POST "$BASE/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USER_A\",\"password\":\"newpass999\"}")
check "duplicate username returns conflict" '"error":"conflict"' "$R"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USER_A\",\"password\":\"newpass999\"}")
check "duplicate username status is 409" "409" "$STATUS"

# Short password → 422
R=$(curl -s -X POST "$BASE/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"username":"newuser","password":"short"}')
check "password < 8 chars returns validation_error" '"error":"validation_error"' "$R"

# Short username → 422
R=$(curl -s -X POST "$BASE/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"username":"ab","password":"validpassword"}')
check "username < 3 chars returns validation_error" '"error":"validation_error"' "$R"

hr "POST /auth/login"

R=$(curl -s -X POST "$BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USER_A\",\"password\":\"$PASS_A\"}")
check "login returns access_token" '"access_token"' "$R"
check "token_type is bearer" '"token_type":"bearer"' "$R"
TOKEN_A=$(json_get access_token "$R")

R=$(curl -s -X POST "$BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USER_B\",\"password\":\"$PASS_B\"}")
TOKEN_B=$(json_get access_token "$R")
check "bob login returns access_token" '"access_token"' "$R"

# Wrong password → 401
R=$(curl -s -X POST "$BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USER_A\",\"password\":\"wrongpassword\"}")
check "wrong password returns unauthorized" '"error":"unauthorized"' "$R"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USER_A\",\"password\":\"wrongpassword\"}")
check "wrong password status is 401" "401" "$STATUS"

# Auth header helpers (bash arrays)
AUTH_A=(-H "Authorization: Bearer $TOKEN_A")
AUTH_B=(-H "Authorization: Bearer $TOKEN_B")

# ─── Auth protection ──────────────────────────────────────────────────────────

hr "Auth protection — unauthenticated requests"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/books")
check "no token → 401" "401" "$STATUS"

R=$(curl -s "$BASE/books")
check "no token returns unauthorized body" '"error":"unauthorized"' "$R"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/books" \
  -H "Authorization: Bearer not.a.valid.jwt")
check "bad token → 401" "401" "$STATUS"

R=$(curl -s "$BASE/books" -H "Authorization: Bearer not.a.valid.jwt")
check "bad token returns unauthorized body" '"error":"unauthorized"' "$R"

# ─── Seed data (as alice) ─────────────────────────────────────────────────────

hr "POST /books — create 12 books as $USER_A"

B1=$(curl -s -X POST "$BASE/books" "${AUTH_A[@]}" \
  -H "Content-Type: application/json" \
  -d '{"title":"The Hobbit","author":"J.R.R. Tolkien","year":1937,"genre":"fantasy","rating":4.9,"status":"read"}')
ID1=$(json_get id "$B1")
check "create The Hobbit" '"title":"The Hobbit"' "$B1"

B2=$(curl -s -X POST "$BASE/books" "${AUTH_A[@]}" \
  -H "Content-Type: application/json" \
  -d '{"title":"Dune","author":"Frank Herbert","year":1965,"genre":"sci-fi","rating":4.7,"status":"read"}')
ID2=$(json_get id "$B2")
check "create Dune" '"title":"Dune"' "$B2"

B3=$(curl -s -X POST "$BASE/books" "${AUTH_A[@]}" \
  -H "Content-Type: application/json" \
  -d '{"title":"1984","author":"George Orwell","year":1949,"genre":"dystopia","rating":4.8,"status":"read"}')
ID3=$(json_get id "$B3")
check "create 1984" '"title":"1984"' "$B3"

B4=$(curl -s -X POST "$BASE/books" "${AUTH_A[@]}" \
  -H "Content-Type: application/json" \
  -d '{"title":"Neuromancer","author":"William Gibson","year":1984,"genre":"sci-fi","rating":4.1,"status":"read"}')
ID4=$(json_get id "$B4")
check "create Neuromancer" '"title":"Neuromancer"' "$B4"

B5=$(curl -s -X POST "$BASE/books" "${AUTH_A[@]}" \
  -H "Content-Type: application/json" \
  -d '{"title":"The Name of the Wind","author":"Patrick Rothfuss","year":2007,"genre":"fantasy","rating":4.5,"status":"reading"}')
ID5=$(json_get id "$B5")
check "create The Name of the Wind (status=reading)" '"status":"reading"' "$B5"

B6=$(curl -s -X POST "$BASE/books" "${AUTH_A[@]}" \
  -H "Content-Type: application/json" \
  -d '{"title":"Sapiens","author":"Yuval Noah Harari","year":2011,"genre":"non-fiction","rating":4.3,"status":"read"}')
ID6=$(json_get id "$B6")
check "create Sapiens" '"genre":"non-fiction"' "$B6"

B7=$(curl -s -X POST "$BASE/books" "${AUTH_A[@]}" \
  -H "Content-Type: application/json" \
  -d '{"title":"The Road","author":"Cormac McCarthy","year":2006,"genre":"literary fiction","status":"want_to_read"}')
ID7=$(json_get id "$B7")
check "create The Road (no rating, want_to_read)" '"status":"want_to_read"' "$B7"

B8=$(curl -s -X POST "$BASE/books" "${AUTH_A[@]}" \
  -H "Content-Type: application/json" \
  -d '{"title":"Brave New World","author":"Aldous Huxley","year":1932,"genre":"dystopia","rating":4.2,"status":"read"}')
ID8=$(json_get id "$B8")
check "create Brave New World" '"title":"Brave New World"' "$B8"

B9=$(curl -s -X POST "$BASE/books" "${AUTH_A[@]}" \
  -H "Content-Type: application/json" \
  -d '{"title":"The Martian","author":"Andy Weir","year":2011,"genre":"sci-fi","rating":4.4,"status":"reading"}')
ID9=$(json_get id "$B9")
check "create The Martian (status=reading)" '"status":"reading"' "$B9"

B10=$(curl -s -X POST "$BASE/books" "${AUTH_A[@]}" \
  -H "Content-Type: application/json" \
  -d '{"title":"Recursion","author":"Blake Crouch","year":2019,"genre":"sci-fi","rating":4.6,"status":"read"}')
ID10=$(json_get id "$B10")
check "create Recursion" '"title":"Recursion"' "$B10"

B11=$(curl -s -X POST "$BASE/books" "${AUTH_A[@]}" \
  -H "Content-Type: application/json" \
  -d '{"title":"Shogun","author":"James Clavell","year":1975,"genre":"historical fiction","rating":4.5,"status":"want_to_read"}')
ID11=$(json_get id "$B11")
check "create Shogun" '"title":"Shogun"' "$B11"

B12=$(curl -s -X POST "$BASE/books" "${AUTH_A[@]}" \
  -H "Content-Type: application/json" \
  -d '{"title":"The Fellowship of the Ring","author":"J.R.R. Tolkien","year":1954,"genre":"fantasy","rating":4.8,"status":"read"}')
ID12=$(json_get id "$B12")
check "create Fellowship of the Ring" '"author":"J.R.R. Tolkien"' "$B12"

# ─── User isolation ───────────────────────────────────────────────────────────

hr "User isolation — $USER_B cannot see $USER_A's books"

B_BOB=$(curl -s -X POST "$BASE/books" "${AUTH_B[@]}" \
  -H "Content-Type: application/json" \
  -d '{"title":"Bob Only Book","author":"Bob Author","year":2020}')
ID_BOB=$(json_get id "$B_BOB")
check "bob creates his own book" '"title":"Bob Only Book"' "$B_BOB"

R=$(curl -s "${AUTH_A[@]}" "$BASE/books?page_size=100")
check_absent "alice list does not contain bob's book" '"Bob Only Book"' "$R"
check "alice still sees her 12 books" '"total":12' "$R"

R=$(curl -s "${AUTH_B[@]}" "$BASE/books?page_size=100")
check_absent "bob list does not contain alice's books" '"The Hobbit"' "$R"
check "bob sees only his 1 book" '"total":1' "$R"

# Alice cannot fetch bob's book by ID
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${AUTH_A[@]}" "$BASE/books/$ID_BOB")
check "alice cannot fetch bob's book (404)" "404" "$STATUS"

# Alice cannot delete bob's book
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "${AUTH_A[@]}" "$BASE/books/$ID_BOB")
check "alice cannot delete bob's book (404)" "404" "$STATUS"

# ─── GET /books — list and pagination ────────────────────────────────────────

hr "GET /books — list and pagination"

R=$(curl -s "${AUTH_A[@]}" "$BASE/books")
check "list returns paginated envelope" '"total":12' "$R"
check "default page=1, page_size=10" '"page":1,"page_size":10' "$R"

R=$(curl -s "${AUTH_A[@]}" "$BASE/books?page=2&page_size=5")
check "page 2, page_size=5" '"page":2,"page_size":5' "$R"
check "total still 12" '"total":12' "$R"

R=$(curl -s "${AUTH_A[@]}" "$BASE/books?page=1&page_size=100")
check "page_size=100 returns all 12" '"total":12' "$R"

# ─── GET /books — genre filter ────────────────────────────────────────────────

hr "GET /books?genre= — filtering"

R=$(curl -s "${AUTH_A[@]}" "$BASE/books?genre=sci-fi&page_size=100")
check "genre=sci-fi returns 4 books" '"total":4' "$R"

R=$(curl -s "${AUTH_A[@]}" "$BASE/books?genre=SCI-FI&page_size=100")
check "genre filter is case-insensitive" '"total":4' "$R"

R=$(curl -s "${AUTH_A[@]}" "$BASE/books?genre=fantasy&page_size=100")
check "genre=fantasy returns 3 books" '"total":3' "$R"

R=$(curl -s "${AUTH_A[@]}" "$BASE/books?genre=dystopia&page_size=100")
check "genre=dystopia returns 2 books" '"total":2' "$R"

R=$(curl -s "${AUTH_A[@]}" "$BASE/books?genre=nonfiction&page_size=100")
check "genre with no match returns total=0" '"total":0' "$R"

# ─── GET /books — search ─────────────────────────────────────────────────────

hr "GET /books?search= — search"

R=$(curl -s "${AUTH_A[@]}" "$BASE/books?search=tolkien&page_size=100")
check "search=tolkien matches 2 books" '"total":2' "$R"

R=$(curl -s "${AUTH_A[@]}" "$BASE/books?search=HOBBIT&page_size=100")
check "search=HOBBIT is case-insensitive" '"total":1' "$R"

R=$(curl -s "${AUTH_A[@]}" "$BASE/books?search=the&page_size=100")
check "search=the matches multiple books" '"total":[^0]' "$R"

R=$(curl -s "${AUTH_A[@]}" "$BASE/books?search=orwell&page_size=100")
check "search by author surname" '"title":"1984"' "$R"

R=$(curl -s "${AUTH_A[@]}" "$BASE/books?search=zzznomatch&page_size=100")
check "search with no results returns total=0" '"total":0' "$R"

# ─── GET /books — combined filters ───────────────────────────────────────────

hr "GET /books — combined genre + search"

R=$(curl -s "${AUTH_A[@]}" "$BASE/books?genre=sci-fi&search=mart&page_size=100")
check "genre=sci-fi + search=mart → The Martian" '"title":"The Martian"' "$R"

# ─── GET /books/{id} ─────────────────────────────────────────────────────────

hr "GET /books/{id} — fetch by ID"

R=$(curl -s "${AUTH_A[@]}" "$BASE/books/$ID1")
check "fetch The Hobbit by ID" '"title":"The Hobbit"' "$R"
check "response has id field" "\"id\":\"$ID1\"" "$R"
check "response has created_at" '"created_at"' "$R"
check "rating is 4.9" '"rating":4.9' "$R"

R=$(curl -s "${AUTH_A[@]}" "$BASE/books/$ID7")
check "The Road has null rating" '"rating":null' "$R"
check "The Road has want_to_read status" '"status":"want_to_read"' "$R"

# ─── GET /books/stats ────────────────────────────────────────────────────────

hr "GET /books/stats — aggregate stats"

R=$(curl -s "${AUTH_A[@]}" "$BASE/books/stats")
check "stats total=12" '"total":12' "$R"
check "stats has average_rating" '"average_rating"' "$R"
check "stats has status_breakdown" '"status_breakdown"' "$R"
check "breakdown want_to_read=2" '"want_to_read":2' "$R"
check "breakdown reading=2" '"reading":2' "$R"
check "breakdown read=8" '"read":8' "$R"

R=$(curl -s "${AUTH_B[@]}" "$BASE/books/stats")
check "bob's stats total=1" '"total":1' "$R"

# ─── PATCH /books/{id} ───────────────────────────────────────────────────────

hr "PATCH /books/{id} — partial update"

R=$(curl -s -X PATCH "${AUTH_A[@]}" "$BASE/books/$ID7" \
  -H "Content-Type: application/json" \
  -d '{"rating":4.6,"status":"reading"}')
check "patch rating + status on The Road" '"rating":4.6' "$R"
check "status updated to reading" '"status":"reading"' "$R"
check "title unchanged after patch" '"title":"The Road"' "$R"

R=$(curl -s -X PATCH "${AUTH_A[@]}" "$BASE/books/$ID5" \
  -H "Content-Type: application/json" \
  -d '{"status":"read"}')
check "status-only patch to read" '"status":"read"' "$R"
check "rating preserved after status-only patch" '"rating":4.5' "$R"

R=$(curl -s -X PATCH "${AUTH_A[@]}" "$BASE/books/$ID11" \
  -H "Content-Type: application/json" \
  -d '{"title":"Shogun (Updated)","rating":5.0}')
check "title + rating patch" '"rating":5.0' "$R"
check "updated title reflected" '"Shogun (Updated)"' "$R"

R=$(curl -s "${AUTH_A[@]}" "$BASE/books/stats")
check "stats reading count updated after patches" '"reading":[23]' "$R"

# ─── DELETE /books/{id} ──────────────────────────────────────────────────────

hr "DELETE /books/{id}"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "${AUTH_A[@]}" "$BASE/books/$ID10")
check "delete Recursion returns 204" "204" "$STATUS"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${AUTH_A[@]}" "$BASE/books/$ID10")
check "deleted book returns 404 on GET" "404" "$STATUS"

R=$(curl -s "${AUTH_A[@]}" "$BASE/books/stats")
check "total decremented to 11 after delete" '"total":11' "$R"

# ─── Error cases ─────────────────────────────────────────────────────────────

hr "Error cases — 404"

R=$(curl -s "${AUTH_A[@]}" "$BASE/books/00000000-0000-0000-0000-000000000000")
check "unknown UUID returns not_found" '"error":"not_found"' "$R"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${AUTH_A[@]}" \
  "$BASE/books/00000000-0000-0000-0000-000000000000")
check "unknown UUID status is 404" "404" "$STATUS"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "${AUTH_A[@]}" \
  "$BASE/books/00000000-0000-0000-0000-000000000000")
check "delete non-existent returns 404" "404" "$STATUS"

R=$(curl -s -X PATCH "${AUTH_A[@]}" "$BASE/books/00000000-0000-0000-0000-000000000000" \
  -H "Content-Type: application/json" \
  -d '{"status":"read"}')
check "patch non-existent returns not_found" '"error":"not_found"' "$R"

hr "Error cases — 422 validation"

R=$(curl -s -X POST "${AUTH_A[@]}" "$BASE/books" \
  -H "Content-Type: application/json" \
  -d '{"title":"Missing Fields"}')
check "missing author/year returns validation_error" '"error":"validation_error"' "$R"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${AUTH_A[@]}" "$BASE/books" \
  -H "Content-Type: application/json" \
  -d '{"title":"Missing Fields"}')
check "missing fields status is 422" "422" "$STATUS"

R=$(curl -s -X POST "${AUTH_A[@]}" "$BASE/books" \
  -H "Content-Type: application/json" \
  -d '{"title":"Future Book","author":"Nobody","year":9999}')
check "year > 2100 returns validation_error" '"error":"validation_error"' "$R"

R=$(curl -s -X POST "${AUTH_A[@]}" "$BASE/books" \
  -H "Content-Type: application/json" \
  -d '{"title":"Bad Rating","author":"Nobody","year":2020,"rating":6.0}')
check "rating > 5.0 returns validation_error" '"error":"validation_error"' "$R"

R=$(curl -s -X POST "${AUTH_A[@]}" "$BASE/books" \
  -H "Content-Type: application/json" \
  -d '{"title":"Bad Status","author":"Nobody","year":2020,"status":"finished"}')
check "invalid status enum returns validation_error" '"error":"validation_error"' "$R"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${AUTH_A[@]}" "$BASE/books/not-a-uuid")
check "non-UUID path param returns 422" "422" "$STATUS"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${AUTH_A[@]}" "$BASE/books?page_size=0")
check "page_size=0 returns 422" "422" "$STATUS"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${AUTH_A[@]}" "$BASE/books?page_size=101")
check "page_size=101 returns 422" "422" "$STATUS"

# ─── Summary ──────────────────────────────────────────────────────────────────

hr "Results"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo
[[ $FAIL -eq 0 ]] && echo "  All tests passed." || echo "  Some tests failed."
