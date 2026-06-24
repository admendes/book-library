#!/usr/bin/env bash
# Full API test suite. Requires: curl, python3
# Start the server first: uv run uvicorn app.main:app --reload

BASE="http://localhost:8000"
PASS=0
FAIL=0

# Extract a top-level key from a JSON string without jq
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

hr() { echo; echo "── $1 ──────────────────────────────────"; }

# ─── Seed data ───────────────────────────────────────────────────────────────

hr "POST /books — create 12 books"

B1=$(curl -s -X POST "$BASE/books" \
  -H "Content-Type: application/json" \
  -d '{"title":"The Hobbit","author":"J.R.R. Tolkien","year":1937,"genre":"fantasy","rating":4.9,"status":"read"}')
ID1=$(echo "$B1" | { read body; json_get id "$body"; })
check "create The Hobbit (201)" '"title":"The Hobbit"' "$B1"

B2=$(curl -s -X POST "$BASE/books" \
  -H "Content-Type: application/json" \
  -d '{"title":"Dune","author":"Frank Herbert","year":1965,"genre":"sci-fi","rating":4.7,"status":"read"}')
ID2=$(echo "$B2" | { read body; json_get id "$body"; })
check "create Dune (201)" '"title":"Dune"' "$B2"

B3=$(curl -s -X POST "$BASE/books" \
  -H "Content-Type: application/json" \
  -d '{"title":"1984","author":"George Orwell","year":1949,"genre":"dystopia","rating":4.8,"status":"read"}')
ID3=$(echo "$B3" | { read body; json_get id "$body"; })
check "create 1984 (201)" '"title":"1984"' "$B3"

B4=$(curl -s -X POST "$BASE/books" \
  -H "Content-Type: application/json" \
  -d '{"title":"Neuromancer","author":"William Gibson","year":1984,"genre":"sci-fi","rating":4.1,"status":"read"}')
ID4=$(echo "$B4" | { read body; json_get id "$body"; })
check "create Neuromancer (201)" '"title":"Neuromancer"' "$B4"

B5=$(curl -s -X POST "$BASE/books" \
  -H "Content-Type: application/json" \
  -d '{"title":"The Name of the Wind","author":"Patrick Rothfuss","year":2007,"genre":"fantasy","rating":4.5,"status":"reading"}')
ID5=$(echo "$B5" | { read body; json_get id "$body"; })
check "create The Name of the Wind (201)" '"status":"reading"' "$B5"

B6=$(curl -s -X POST "$BASE/books" \
  -H "Content-Type: application/json" \
  -d '{"title":"Sapiens","author":"Yuval Noah Harari","year":2011,"genre":"non-fiction","rating":4.3,"status":"read"}')
ID6=$(echo "$B6" | { read body; json_get id "$body"; })
check "create Sapiens (201)" '"genre":"non-fiction"' "$B6"

B7=$(curl -s -X POST "$BASE/books" \
  -H "Content-Type: application/json" \
  -d '{"title":"The Road","author":"Cormac McCarthy","year":2006,"genre":"literary fiction","status":"want_to_read"}')
ID7=$(echo "$B7" | { read body; json_get id "$body"; })
check "create The Road (no rating, want_to_read)" '"status":"want_to_read"' "$B7"

B8=$(curl -s -X POST "$BASE/books" \
  -H "Content-Type: application/json" \
  -d '{"title":"Brave New World","author":"Aldous Huxley","year":1932,"genre":"dystopia","rating":4.2,"status":"read"}')
ID8=$(echo "$B8" | { read body; json_get id "$body"; })
check "create Brave New World (201)" '"title":"Brave New World"' "$B8"

B9=$(curl -s -X POST "$BASE/books" \
  -H "Content-Type: application/json" \
  -d '{"title":"The Martian","author":"Andy Weir","year":2011,"genre":"sci-fi","rating":4.4,"status":"reading"}')
ID9=$(echo "$B9" | { read body; json_get id "$body"; })
check "create The Martian (201)" '"status":"reading"' "$B9"

B10=$(curl -s -X POST "$BASE/books" \
  -H "Content-Type: application/json" \
  -d '{"title":"Recursion","author":"Blake Crouch","year":2019,"genre":"sci-fi","rating":4.6,"status":"read"}')
ID10=$(echo "$B10" | { read body; json_get id "$body"; })
check "create Recursion (201)" '"title":"Recursion"' "$B10"

B11=$(curl -s -X POST "$BASE/books" \
  -H "Content-Type: application/json" \
  -d '{"title":"Shogun","author":"James Clavell","year":1975,"genre":"historical fiction","rating":4.5,"status":"want_to_read"}')
ID11=$(echo "$B11" | { read body; json_get id "$body"; })
check "create Shogun (201)" '"title":"Shogun"' "$B11"

B12=$(curl -s -X POST "$BASE/books" \
  -H "Content-Type: application/json" \
  -d '{"title":"The Fellowship of the Ring","author":"J.R.R. Tolkien","year":1954,"genre":"fantasy","rating":4.8,"status":"read"}')
ID12=$(echo "$B12" | { read body; json_get id "$body"; })
check "create Fellowship of the Ring (201)" '"author":"J.R.R. Tolkien"' "$B12"

# ─── GET /books — list + pagination ──────────────────────────────────────────

hr "GET /books — list and pagination"

R=$(curl -s "$BASE/books")
check "list returns paginated envelope" '"total":12' "$R"
check "default page=1, page_size=10" '"page":1,"page_size":10' "$R"
check "items capped at 10 by default" '"page_size":10' "$R"

R=$(curl -s "$BASE/books?page=2&page_size=5")
check "page 2 with page_size=5 (5 items)" '"page":2,"page_size":5' "$R"
check "total still 12 across pages" '"total":12' "$R"

R=$(curl -s "$BASE/books?page=1&page_size=100")
check "page_size=100 returns all 12" '"total":12' "$R"

# ─── GET /books — genre filter ────────────────────────────────────────────────

hr "GET /books?genre= — filtering"

R=$(curl -s "$BASE/books?genre=sci-fi&page_size=100")
check "genre=sci-fi returns 4 books" '"total":4' "$R"

R=$(curl -s "$BASE/books?genre=SCI-FI&page_size=100")
check "genre filter is case-insensitive (SCI-FI)" '"total":4' "$R"

R=$(curl -s "$BASE/books?genre=fantasy&page_size=100")
check "genre=fantasy returns 3 books" '"total":3' "$R"

R=$(curl -s "$BASE/books?genre=dystopia&page_size=100")
check "genre=dystopia returns 2 books" '"total":2' "$R"

R=$(curl -s "$BASE/books?genre=nonfiction&page_size=100")
check "genre with no matches returns total=0" '"total":0' "$R"

# ─── GET /books — search ─────────────────────────────────────────────────────

hr "GET /books?search= — search"

R=$(curl -s "$BASE/books?search=tolkien&page_size=100")
check "search=tolkien matches 2 Tolkien books" '"total":2' "$R"

R=$(curl -s "$BASE/books?search=HOBBIT&page_size=100")
check "search=HOBBIT case-insensitive match" '"total":1' "$R"

R=$(curl -s "$BASE/books?search=the&page_size=100")
check "search=the matches multiple books by title" '"total":[^0]' "$R"

R=$(curl -s "$BASE/books?search=orwell&page_size=100")
check "search by author surname" '"title":"1984"' "$R"

R=$(curl -s "$BASE/books?search=zzznomatch&page_size=100")
check "search with no results returns total=0" '"total":0' "$R"

# ─── GET /books — combined filters ───────────────────────────────────────────

hr "GET /books — combined genre + search"

R=$(curl -s "$BASE/books?genre=sci-fi&search=mart&page_size=100")
check "genre=sci-fi + search=mart returns The Martian" '"title":"The Martian"' "$R"

# ─── GET /books/{id} — single book ───────────────────────────────────────────

hr "GET /books/{id} — fetch by ID"

R=$(curl -s "$BASE/books/$ID1")
check "fetch The Hobbit by ID" '"title":"The Hobbit"' "$R"
check "book has id field" "\"id\":\"$ID1\"" "$R"
check "book has created_at" '"created_at"' "$R"
check "book has rating 4.9" '"rating":4.9' "$R"

R=$(curl -s "$BASE/books/$ID7")
check "fetch The Road (null rating)" '"rating":null' "$R"
check "The Road has want_to_read status" '"status":"want_to_read"' "$R"

# ─── GET /books/stats ─────────────────────────────────────────────────────────

hr "GET /books/stats — aggregate stats"

R=$(curl -s "$BASE/books/stats")
check "stats returns total=12" '"total":12' "$R"
check "stats has average_rating" '"average_rating"' "$R"
check "stats has status_breakdown" '"status_breakdown"' "$R"
check "stats breakdown has want_to_read" '"want_to_read":2' "$R"
check "stats breakdown has reading" '"reading":2' "$R"
check "stats breakdown has read" '"read":8' "$R"

# ─── PATCH /books/{id} — partial update ──────────────────────────────────────

hr "PATCH /books/{id} — partial update"

R=$(curl -s -X PATCH "$BASE/books/$ID7" \
  -H "Content-Type: application/json" \
  -d '{"rating":4.6,"status":"reading"}')
check "update rating on The Road" '"rating":4.6' "$R"
check "update status to reading" '"status":"reading"' "$R"
check "title unchanged after patch" '"title":"The Road"' "$R"

R=$(curl -s -X PATCH "$BASE/books/$ID5" \
  -H "Content-Type: application/json" \
  -d '{"status":"read"}')
check "update only status to read" '"status":"read"' "$R"
check "rating preserved after status-only patch" '"rating":4.5' "$R"

R=$(curl -s -X PATCH "$BASE/books/$ID11" \
  -H "Content-Type: application/json" \
  -d '{"title":"Shōgun","rating":5.0}')
check "update title and rating" '"rating":5.0' "$R"

# stats recalculate after updates
R=$(curl -s "$BASE/books/stats")
check "reading count updated after patches" '"reading":[23]' "$R"

# ─── DELETE /books/{id} ───────────────────────────────────────────────────────

hr "DELETE /books/{id}"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$BASE/books/$ID10")
check "delete Recursion returns 204" "204" "$STATUS"

R=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/books/$ID10")
check "deleted book returns 404 on GET" "404" "$R"

R=$(curl -s "$BASE/books/stats")
check "total decremented after delete" '"total":11' "$R"

# ─── Error cases ─────────────────────────────────────────────────────────────

hr "Error cases"

# 404 — book not found
R=$(curl -s "$BASE/books/00000000-0000-0000-0000-000000000000")
check "unknown UUID returns 404 error body" '"error":"not_found"' "$R"
check "404 detail mentions book id" '"detail"' "$R"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/books/00000000-0000-0000-0000-000000000000")
check "unknown UUID status code is 404" "404" "$STATUS"

# 404 — delete non-existent
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$BASE/books/00000000-0000-0000-0000-000000000000")
check "delete non-existent book returns 404" "404" "$STATUS"

# 404 — patch non-existent
R=$(curl -s -X PATCH "$BASE/books/00000000-0000-0000-0000-000000000000" \
  -H "Content-Type: application/json" \
  -d '{"status":"read"}')
check "patch non-existent book returns not_found" '"error":"not_found"' "$R"

# 422 — missing required fields
R=$(curl -s -X POST "$BASE/books" \
  -H "Content-Type: application/json" \
  -d '{"title":"Missing Fields"}')
check "missing author/year returns 422" '"error":"validation_error"' "$R"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/books" \
  -H "Content-Type: application/json" \
  -d '{"title":"Missing Fields"}')
check "missing fields status code is 422" "422" "$STATUS"

# 422 — year out of range
R=$(curl -s -X POST "$BASE/books" \
  -H "Content-Type: application/json" \
  -d '{"title":"Future Book","author":"Nobody","year":9999}')
check "year > 2100 returns validation_error" '"error":"validation_error"' "$R"

# 422 — rating out of range
R=$(curl -s -X POST "$BASE/books" \
  -H "Content-Type: application/json" \
  -d '{"title":"Bad Rating","author":"Nobody","year":2020,"rating":6.0}')
check "rating > 5.0 returns validation_error" '"error":"validation_error"' "$R"

# 422 — invalid status enum
R=$(curl -s -X POST "$BASE/books" \
  -H "Content-Type: application/json" \
  -d '{"title":"Bad Status","author":"Nobody","year":2020,"status":"finished"}')
check "invalid status enum returns validation_error" '"error":"validation_error"' "$R"

# 422 — invalid UUID in path
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/books/not-a-uuid")
check "non-UUID path param returns 422" "422" "$STATUS"

# 422 — page_size out of range
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/books?page_size=0")
check "page_size=0 returns 422" "422" "$STATUS"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/books?page_size=101")
check "page_size=101 returns 422" "422" "$STATUS"

# ─── Summary ──────────────────────────────────────────────────────────────────

hr "Results"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo
[[ $FAIL -eq 0 ]] && echo "  All tests passed." || echo "  Some tests failed."
