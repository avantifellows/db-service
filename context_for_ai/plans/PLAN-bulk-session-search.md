# Plan: Add Bulk Session Search Endpoint

## Problem Statement

The ETL orchestrator's `queue_sessions_to_sync` flow needs to look up session information for hundreds of quiz IDs. Currently, it makes **individual API calls** for each quiz ID:

```
GET /api/session?platform=quiz&platform_id=abc123
GET /api/session?platform=quiz&platform_id=def456
GET /api/session?platform=quiz&platform_id=ghi789
... (227+ requests)
```

This is slow and inefficient. A single flow run with 227 quiz IDs takes ~2-3 seconds just for API calls, with 0.1s delays between chunks.

## Proposed Solution

Add a new bulk search endpoint that accepts multiple `platform_id` values in a single request:

```
POST /api/session/search
{
  "platform": "quiz",
  "platform_ids": ["abc123", "def456", "ghi789", ...],
  "limit": 1000
}
```

This follows the existing pattern used by `/api/session-occurrence/search`.

---

## Implementation Details

### 1. Add Route

**File:** `lib/dbservice_web/router.ex`

Add after line 69 (after the existing session routes):

```elixir
resources("/session", SessionController, only: [:index, :create, :update, :show, :delete])
post("/session/:id/update-groups", SessionController, :update_groups)
post("/session/search", SessionController, :search)  # <-- NEW
```

### 2. Add Controller Action

**File:** `lib/dbservice_web/controllers/session_controller.ex`

Add the swagger definition and search function:

```elixir
swagger_path :search do
  post("/api/session/search")

  parameters do
    body(:body, Schema.ref(:SessionSearch), "Search parameters", required: true)
  end

  response(200, "OK", Schema.ref(:Sessions))
end

def search(conn, params) do
  platform_ids = Map.get(params, "platform_ids", [])
  platform = Map.get(params, "platform")

  query = build_search_query(platform_ids, platform, params)
  sessions = Repo.all(query)

  render(conn, :index, session: sessions)
end

defp build_search_query(platform_ids, platform, params) do
  sort_order = extract_sort_order(params)

  base_query =
    from m in Session,
      order_by: [{^sort_order, m.id}],
      offset: ^params["offset"],
      limit: ^params["limit"]

  # Apply platform_ids filter if provided
  base_query =
    if platform_ids != [] do
      from(s in base_query, where: s.platform_id in ^platform_ids)
    else
      base_query
    end

  # Apply platform filter if provided
  base_query =
    if platform do
      from(s in base_query, where: s.platform == ^platform)
    else
      base_query
    end

  base_query
end
```

### 3. Add Swagger Schema

**File:** `lib/dbservice_web/swagger_schemas/session.ex`

Add the search schema:

```elixir
def session_search do
  %{
    SessionSearch:
      swagger_schema do
        title("SessionSearch")
        description("Parameters for bulk session search")

        properties do
          platform_ids(:array, "List of platform IDs to search for", items: %{type: :string})
          platform(:string, "Platform type filter (e.g., 'quiz')")
          offset(:integer, "Pagination offset")
          limit(:integer, "Pagination limit")
          sort_order(:string, "Sort order: 'asc' or 'desc'")
        end
      end
  }
end
```

Update `swagger_definitions` in the controller to include the new schema.

### 4. Update ETL Flow

**File:** `etl-next/orchestrator/flows/queue_sessions_to_sync.py`

Replace the per-ID lookup with a single bulk request:

```python
def get_sessions_by_platform_ids_bulk(platform_ids: List[str]) -> List[Dict[str, Any]]:
    """
    Get sessions from DB service API by platform IDs (bulk request).
    """
    db_url = settings.af_db_service_url
    db_token = settings.af_db_service_bearer_token

    if not db_url or not db_token:
        raise ValueError("AF_DB_SERVICE_URL and AF_DB_SERVICE_BEARER_TOKEN required")

    headers = {
        "accept": "application/json",
        "Authorization": f"Bearer {db_token}",
        "Content-Type": "application/json"
    }

    payload = {
        "platform": "quiz",
        "platform_ids": platform_ids,
        "limit": 10000
    }

    try:
        response = requests.post(
            f"{db_url}/session/search",
            headers=headers,
            json=payload,
            timeout=60
        )
        response.raise_for_status()
        return response.json() or []
    except requests.exceptions.RequestException as e:
        print(f"[db_api] Error in bulk session search: {e}")
        raise RuntimeError(f"Bulk session search failed: {e}")
```

---

## API Specification

### Request

```http
POST /api/session/search
Content-Type: application/json
Authorization: Bearer <token>

{
  "platform": "quiz",
  "platform_ids": ["68ef710fa0ef79777d2cd951", "694cec5693dc2b52ba0d6ca1"],
  "limit": 1000,
  "offset": 0
}
```

### Response

```json
[
  {
    "id": 123,
    "session_id": "sess_abc123",
    "platform_id": "68ef710fa0ef79777d2cd951",
    "platform": "quiz",
    "name": "Math Quiz Session",
    "start_time": "2025-12-01T10:00:00Z",
    "end_time": "2025-12-27T23:59:00Z",
    ...
  },
  {
    "id": 124,
    "session_id": "sess_def456",
    "platform_id": "694cec5693dc2b52ba0d6ca1",
    "platform": "quiz",
    ...
  }
]
```

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `platform_ids` | array[string] | No | List of platform IDs to search for |
| `platform` | string | No | Filter by platform type (e.g., "quiz") |
| `limit` | integer | No | Max results to return (default: 100) |
| `offset` | integer | No | Pagination offset (default: 0) |
| `sort_order` | string | No | "asc" or "desc" (default: "desc") |

---

## Database Considerations

### Index Check

Ensure there's an index on `platform_id` for efficient lookups:

```sql
-- Check if index exists
SELECT indexname FROM pg_indexes WHERE tablename = 'session' AND indexdef LIKE '%platform_id%';

-- Create if not exists
CREATE INDEX IF NOT EXISTS idx_session_platform_id ON session(platform_id);

-- Composite index for platform + platform_id queries
CREATE INDEX IF NOT EXISTS idx_session_platform_platform_id ON session(platform, platform_id);
```

### Query Performance

With 227 platform_ids, the query will use:
```sql
SELECT * FROM session
WHERE platform_id IN ('id1', 'id2', ..., 'id227')
  AND platform = 'quiz'
ORDER BY id DESC
LIMIT 1000;
```

This should execute in <100ms with proper indexing.

---

## Testing

### Manual Testing

```bash
# Test the endpoint
curl -X POST http://localhost:4000/api/session/search \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "platform": "quiz",
    "platform_ids": ["test-id-1", "test-id-2"],
    "limit": 10
  }'
```

### Unit Tests

**File:** `test/dbservice_web/controllers/session_controller_test.exs`

```elixir
describe "search" do
  test "returns sessions matching platform_ids", %{conn: conn} do
    # Create test sessions
    {:ok, session1} = Sessions.create_session(%{
      name: "Test 1",
      platform: "quiz",
      platform_id: "quiz-001",
      session_id: "sess-001"
    })
    {:ok, session2} = Sessions.create_session(%{
      name: "Test 2",
      platform: "quiz",
      platform_id: "quiz-002",
      session_id: "sess-002"
    })

    # Search for both
    conn = post(conn, ~p"/api/session/search", %{
      "platform" => "quiz",
      "platform_ids" => ["quiz-001", "quiz-002"]
    })

    assert json_response(conn, 200)
    response = json_response(conn, 200)
    assert length(response) == 2
  end

  test "returns empty list for non-matching platform_ids", %{conn: conn} do
    conn = post(conn, ~p"/api/session/search", %{
      "platform_ids" => ["non-existent-id"]
    })

    assert json_response(conn, 200) == []
  end
end
```

---

## Migration Path

1. **Phase 1:** Deploy the new endpoint to db-service (backward compatible)
2. **Phase 2:** Update etl-next flow to use bulk endpoint
3. **Phase 3:** Monitor and verify performance improvement

---

## Performance Comparison

| Metric | Current (per-ID) | Bulk Endpoint |
|--------|------------------|---------------|
| API Calls | 227 | 1 |
| Network Round Trips | 227 | 1 |
| Total Time (estimated) | ~25s | <1s |
| Rate Limit Risk | High | Low |

---

## Files to Modify

### db-service
1. `lib/dbservice_web/router.ex` - Add route
2. `lib/dbservice_web/controllers/session_controller.ex` - Add search action
3. `lib/dbservice_web/swagger_schemas/session.ex` - Add schema (if needed)
4. `test/dbservice_web/controllers/session_controller_test.exs` - Add tests

### etl-next (after db-service is deployed)
1. `orchestrator/flows/queue_sessions_to_sync.py` - Use bulk endpoint

---

## Checklist

- [x] Add `POST /api/session/search` route *(completed 2025-12-27)*
- [x] Implement `search` action in SessionController *(completed 2025-12-27)*
- [x] Add Swagger documentation *(completed 2025-12-27)*
- [ ] Verify/create database index on `platform_id` *(optional, recommended for large datasets)*
- [x] Write unit tests *(completed 2025-12-27 - 6 tests, all passing)*
- [ ] Deploy to staging and test
- [ ] Deploy to production
- [ ] Update etl-next flow to use bulk endpoint
- [ ] Monitor performance improvement

---

## Implementation Notes

**Completed 2025-12-27:**

Files modified:
- `lib/dbservice_web/router.ex:70` - Added route
- `lib/dbservice_web/controllers/session_controller.ex:216-261` - Added search action + Swagger
- `lib/dbservice_web/swagger_schemas/session.ex:72-96` - Added SessionSearch schema
- `test/dbservice_web/controllers/session_controller_test.exs:282-373` - Added 6 test cases

Additional fix:
- `lib/dbservice/application.ex` - Made Google credentials optional in test environment
- `config/test.exs` - Added `environment: :test` config
