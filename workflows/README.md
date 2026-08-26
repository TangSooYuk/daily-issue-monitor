# trends-to-wordpress.n8n.json

전체 흐름: Google Trends RSS(어제자 Top 20) → Supabase 저장 → 키워드별 네이버 뉴스 검색 → Claude로 블로그 초안 생성 → 워드프레스 발행(draft) → Supabase에 발행 결과 기록.

## 가져오기 (Import)

1. n8n 좌측 상단 메뉴 → **Import from File** → 이 폴더의 `trends-to-wordpress.n8n.json` 선택
2. 가져온 직후에는 아무 크리덴셜도 연결되어 있지 않습니다 (JSON에 실제 비밀값을 넣지 않았습니다 — GitHub에 올려도 안전하도록 일부러 플레이스홀더로 남겨뒀습니다). 아래 순서로 노드를 열어 하나씩 연결하세요.

## 크리덴셜 연결이 필요한 노드

| 노드 | 방식 | 채울 값 |
|---|---|---|
| Insert Keyword / Insert News / Mark Published | Supabase 크리덴셜 선택 | Project URL + service_role 키 |
| Search Naver News | 노드 안 Header Parameters에 직접 입력 | `X-Naver-Client-Id`, `X-Naver-Client-Secret` — **커밋 전에 반드시 실제 값으로 채운 뒤 다시 export하지 말고, n8n UI에서만 채우세요** |
| Claude Draft | Header Auth 크리덴셜 선택 (name: `x-api-key`) | Anthropic API 키 |
| Publish WordPress | Basic Auth 크리덴셜 선택 | 워드프레스 계정 + Application Password |

또한 `Publish WordPress` 노드의 URL을 실제 워드프레스 도메인(`https://yourdomain.com/wp-json/wp/v2/posts`)으로 바꿔주세요.

## DB 선행 작업

`db/002_add_publish_columns.sql`을 Supabase SQL Editor에서 먼저 실행해야 `Mark Published` 노드가 정상 동작합니다 (`trending_keywords`에 `wp_post_id`, `posted_at` 컬럼 추가).

## 가져온 뒤 반드시 확인할 것 (자동 생성 JSON 특성상 검증 필요)

- **XML to JSON → Extract Top 20**: `ht:approx_traffic` 같은 네임스페이스 필드 키 이름이 n8n 버전에 따라 다르게 나올 수 있습니다. 실행해보고 `approx_traffic`이 계속 `null`이면, Fetch Trends RSS 노드 출력을 직접 열어 실제 키 이름을 확인 후 Code 노드를 고치세요.
- **Loop Keywords 출력 방향**: Split In Batches(Loop Over Items)의 출력 0/1이 n8n 버전에 따라 "loop"/"done" 순서가 바뀐 적이 있습니다. 저장된 연결은 출력 0 = loop로 가정했습니다. 실행해서 루프가 한 번만 돌고 끝나면 두 출력의 연결을 서로 바꿔보세요.
- **autoMapInputData**: Supabase 노드들이 입력 필드명을 테이블 컬럼명과 자동 매칭합니다. Code 노드가 만드는 필드명(keyword, rank, trend_link 등)이 테이블 컬럼명과 정확히 일치하는지 확인하세요.
- 각 HTTP Request/Code 노드를 처음엔 하나씩 "Execute step"으로 개별 실행하며 데이터 모양을 확인한 뒤, 전체 워크플로우를 Activate 하세요.
