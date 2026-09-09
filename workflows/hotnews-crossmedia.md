# hotnews-crossmedia.n8n.json

**완전히 독립된 워크플로우입니다.** `trends-to-wordpress.n8n.json`("Daily Posting", 워드프레스 자동 발행)이나 `blogspot-monetization.n8n.json`과 노드/워크플로우 파일을 전혀 공유하지 않고, DB 테이블도 별도로 새로 만든 3개만 씁니다. 발행 대상 사이트(deohaam.com)와 Claude/Pexels/네이버 API 크리덴셜 계정만 재사용합니다 — 이건 워크플로우를 합치는 것과는 다른, 계정 단위 인증 정보 재사용입니다.

## 왜 별도 워크플로우인가

이 기능은 원래 "Daily Posting" 워크플로우 안에 노드를 계속 추가하는 식으로 만들어졌다가, "기존 작업과 절대 합치지 말라"는 요청에 따라 여기로 완전히 분리했습니다. 분리하면서:

- **워크플로우 파일**: 이 파일 하나로 완결 — 후보 수집부터 워드프레스 발행까지 전 과정이 여기 안에서 끝납니다. "Daily Posting"을 실행 중에 호출하지 않습니다(Execute Workflow로 다른 워크플로우를 부르는 방식도 고려했지만, 그러면 여전히 그 워크플로우의 존재와 특정 노드 이름에 의존하게 되어 완전한 분리가 아니라고 판단했습니다).
- **DB 테이블**: `hotnews_candidates`, `hotnews_broadcast`, `hotnews_trend_history` 3개, 전부 이 워크플로우 전용 신규 테이블 (`db/007_add_hotnews_tables.sql`). `trending_keywords`/`keyword_news`(Daily Posting), `blogspot_topics`/`blogspot_posts`(Blogspot) 중 어느 것도 읽거나 쓰지 않습니다.
- **Claude 초안 → 이미지 → 카테고리/태그 → 워드프레스 발행 체인**은 Daily Posting에 있던 것과 로직이 동일하지만, 이 파일 안에 독립적으로 복제해 넣었습니다. 두 워크플로우 중 한쪽만 나중에 수정해도 다른 쪽엔 영향이 없습니다(반대로 같은 버그를 두 곳에서 각각 고쳐야 할 수도 있다는 뜻이기도 합니다).
- **텔레그램 봇**: 이 워크플로우 전용 4번째 봇이 필요합니다 (봇 토큰 하나당 웹훅 하나뿐이라, "Daily Posting"/Tistory/Blogspot이 이미 각자 자기 봇을 씁니다). `Telegram Trigger (Hotnews Bot)`을 비롯해 이 파일의 모든 Telegram 노드에서 새로 만든 봇으로 재연결해야 합니다.

## 전체 흐름

### 1. 후보 수집 (두 개의 독립 경로, 둘 다 `hotnews_candidates`로 모임)

**경로 A — 자동 수집 (1시간마다, 언론사 RSS 교차 보도 기반)**: 검증된 언론사 21곳 RSS를 동시에 조회 → 최근 2시간 내 기사만 추출 → 전체 제목을 Claude에게 보내 같은 사건끼리 클러스터링 → 언론사 2곳 이상 겹치는 클러스터만, 겹친 수 많은 순 Top 10 저장(`outlet_count`).

**경로 B — `/hotcollect YYYY-MM-DD` (과거 특정 날짜 백필, 수동)**: 이 워크플로우 전용으로 3시간마다 독립적으로 구글 트렌드 RSS를 수집해두는 `hotnews_trend_history`에서 그 날짜의 키워드를 찾아, 네이버 뉴스를 검색해 기사를 저장(`rank`/`approx_traffic` 채워짐). RSS도 네이버 랭킹뉴스도 과거 날짜 조회가 안 되기 때문에 이 경로만 키워드 기반입니다.

### 2. 방송 (3시간마다 자동, 또는 `/hotnews` 수동 요청)

`posted_at IS NULL`인 후보를 모아 번호 매겨 텔레그램 전송 (정렬: 날짜 최신순 → `outlet_count` 우선 → `rank`). **5분 간격 최대 3회 재전송, 3회째까지 무응답이면 조용히 취소**(자동 승인 없음, 아무 글도 안 씀).

### 3. 선택 (숫자 답장)

`1,3,7` 답장이 오면 가장 최근 방송의 대기 중인 실행을 찾아 재개, 선택된 항목만 다음 단계로.

### 4. 항목별 처리 (선택된 기사마다, **순차 처리**)

> **왜 순차인가**: 뉴스 검토 승인 단계가 텔레그램 인라인 버튼 클릭 방식이라 동시 처리 자체는 기술적으로 안전하지만, 여러 항목이 동시에 승인 대기 중이면 사람이 헷갈리기 쉽고(어떤 메시지가 어떤 항목 건지), 알림이 뒤섞여서 순서를 따라가기 어렵습니다. 한 번에 한 항목씩 확실하게 처리하는 쪽을 택했습니다. `Trigger Item Processing`(Execute Workflow, 이 워크플로우 자기 자신을 재호출)의 "Wait For Sub-Workflow Completion"이 켜져 있어서, 앞 항목이 워드프레스 등록까지 끝나야 다음 항목이 시작됩니다.

각 항목마다:
1. **관련 기사 재조사**: 해당 기사의 **발행일 기준 ±14일** 범위로 네이버 뉴스 재검색 (`sort=sim` — 오래된 기사는 `sort=date`로 아예 검색 결과에 안 걸릴 수 있어서). 재검색 결과가 없어도 원본 기사 자체는 항상 최소 1건으로 보장.
2. **뉴스 검토 승인** (텔레그램 인라인 버튼, 최대 5회 재전송 후 자동 승인).
3. **Claude 초안 작성** (여러 기사 종합, SEO 체크리스트 포함).
4. **이미지(Pexels 대표+본문, 기사 원본 og:image 폴백) → 카테고리/태그 자동 매칭 → 워드프레스 draft 등록**.

### 5. 완료 기록

`hotnews_candidates`에 `posted_at`/`wp_post_id` 기록, 텔레그램으로 완료(편집/미리보기 링크) 또는 오류 알림.

## 가져오기 전 필수 선행 작업

1. `db/007_add_hotnews_tables.sql`을 Supabase SQL Editor에서 실행 (`hotnews_candidates`, `hotnews_broadcast`, `hotnews_trend_history`).
2. @BotFather에서 새 텔레그램 봇 생성.
3. 아래 크리덴셜 표를 참고해 재연결.

## 크리덴셜 연결

| 노드 | 크리덴셜 | 비고 |
|---|---|---|
| `Telegram Trigger (Hotnews Bot)` 외 모든 Telegram 노드 | Telegram API | **신규** — 방금 만든 봇 |
| `Upsert Hotnews Candidates`, `Insert Hotnews Trend History`, `*Broadcast*` Supabase 노드 전체 | Supabase | 기존 "Supabase account 2" 재사용 (같은 프로젝트, 신규 테이블만 사용) |
| `Search Naver News (Hotnews Collector)`, `Search Naver News` | Header Parameters 직접 입력 | `X-NCP-APIGW-API-KEY-ID`/`X-NCP-APIGW-API-KEY`, 기존 값 재입력 |
| `Claude Cluster Hot News`, `Claude Draft` | Header Auth (`x-api-key`) | 기존 "Header Auth account" 재사용 |
| `Search Pexels Image*` (3곳) | Header 직접 입력 | 기존 Pexels API 키 재입력 |
| 워드프레스 관련 노드 전체 (`Publish WordPress`, `Search WP Category`, 이미지 업로드 등) | Basic Auth | 기존 "Gabia" 재사용 (같은 사이트 deohaam.com에 발행하는 게 원래 목적) |

## ⚠️ Import 후 반드시 확인

- **`Extract Recent RSS Articles`**, **`Parse Hotnews Collector Articles`**: Code 노드 Mode가 "Run Once for Each Item"인지 확인.
- **`Trigger Item Processing`**: Execute Workflow 노드 — (1) 대상이 **이 워크플로우 자신**을 가리키는지(`{{ $workflow.id }}` 표현식이 안 먹으면 워크플로우 선택기에서 직접 선택), (2) Mode = "Run Once for Each Item", (3) **"Wait For Sub-Workflow Completion" 켜짐**(순차 처리의 핵심 — 꺼지면 여러 항목이 동시에 처리되어 뉴스 검토 승인 알림이 뒤섞입니다).
- **`Wait Broadcast Reply`**, **`Wait News Review`**: 다른 Wait 노드들과 마찬가지로 "Limit Wait Time" 토글과 Amount 필드의 expression 모드 확인.
- **워드프레스 관련 노드들의 `User-Agent: curl/8.21.0` 헤더**: 401 우회에 필수 — 실수로 지우지 마세요.
- **RSS URL 21개**: `RSS Feed List` 노드 안에 하드코딩. 언론사가 주소를 바꾸면 그 언론사만 조용히 스킵되니 가끔 점검 필요.
