# trends-to-wordpress.n8n.json (v2 — Telegram 승인 + 수동 키워드 + 반복 방지)

## v2.12 — Claude 초안 작성에 Rank Math 기본 SEO 체크리스트 반영 (신규)

`Claude Draft`의 프롬프트에 Rank Math의 "Basic SEO" 체크리스트 항목을 명시적으로 추가했습니다. 이전에는 스타일/톤 지침 위주였고, 키워드 배치나 분량에 대한 명시적 요구가 없었습니다.

- **title에 키워드 포함**: 이 title이 URL 슬러그와 이미지 alt 텍스트(alt 텍스트 노드들이 title을 그대로 재사용)에도 그대로 쓰이기 때문에, title에 키워드를 강제하는 것만으로 SEO 제목/URL/이미지 alt 세 가지 체크리스트 항목이 한 번에 충족됩니다.
- **meta_description에 키워드 포함**을 명시.
- **본문 앞 10% 이내에 키워드 등장**, **본문 전체에서 최소 2~3회 반복**을 명시 — 기존 "도입부 스타일을 매번 다르게" 지침과 충돌하지 않도록, 문체는 자유롭게 하되 키워드 언급 자체는 빠뜨리지 말라고 구분해서 지시했습니다.
- **소제목(`<h2>`) 중 최소 하나에 키워드 포함**을 명시.
- **최소 600단어 분량**(한국어 기준 공백 포함 약 2000자 이상)을 명시 — 기존에는 분량 하한이 전혀 없었습니다.
- 나머지 두 체크리스트 항목(DoFollow 외부 링크 1개 이상, 콘텐츠 내 키워드 포함)은 이미 v2.8에서 처리되어 있어 별도 수정 없음.

## v2.11 — 태그 100개 초과 시 "이미 존재하는 태그" 생성 실패 수정 (신규)

라이브에서 `Create WP Tag`가 `Bad request` ("제공한 이름이 있는 용어는 이미 택소노미에 존재합니다")로 실패하는 문제를 고쳤습니다.

- **원인**: `Get All WP Tags`가 `per_page=100`으로 한 페이지만 가져오는데, 사이트에 태그가 이미 100개를 넘어서면(확인 시점 160개) 100개 밖에 있는 태그를 "없다"고 잘못 판단해 `Create WP Tag`가 새로 만들려다 워드프레스에게 거절당합니다. 태그가 꾸준히 쌓이는 이 워크플로우 특성상 100개는 곧 넘길 수밖에 없는 값이었습니다.
- **수정**: 전체 태그를 다 가져오도록 페이지네이션을 붙이는 대신(태그가 앞으로 계속 늘어나는 한 어차피 다시 한계에 부딪힘), `Create WP Tag`에 `neverError: true`를 켜서 이 "이미 존재함" 응답도 정상 데이터로 받도록 하고, 새 노드 `Normalize Created Tag ID`(Code)를 붙여서 실제로 새로 만들어진 태그면 `id`를, 이미 존재해서 충돌났으면 워드프레스가 에러 응답에 같이 주는 `data.term_id`를 그대로 꺼내 씁니다. 두 경우 다 최종적으로 같은 `{ id }` 모양으로 나오기 때문에 `Aggregate Tag IDs` 이후는 전혀 손댈 필요 없었습니다.
- 워드프레스의 `term_exists` 에러 응답에 항상 `data.term_id`(존재하는 태그의 실제 id)가 포함된다는 걸 실제 API 호출로 직접 확인하고 반영한 수정입니다.

## v2.10 — 업로드 이미지 alt 텍스트 채우기 (신규)

SEO 점검 중 발견: 대표 이미지 + 본문 이미지 2장 모두 실제 `<img alt="">`가 비어있었습니다 (Rank Math가 og:image:alt는 포커스 키워드 등으로 대체 채워주지만, 실제 본문/썸네일 `<img>` 태그의 alt는 미디어 라이브러리 첨부파일 자체의 alt_text 메타데이터가 없으면 비게 됩니다). 이미지 검색 노출과 접근성(스크린리더) 둘 다 놓치고 있던 부분입니다.

- **원인**: `Upload Featured Image to WordPress` / `Upload Body Image 1` / `Upload Body Image 2`가 `/wp-json/wp/v2/media`에 파일 바이트만 raw binary body로 올리고 있어서, 같은 요청에 `alt_text` 같은 텍스트 필드를 같이 못 보냅니다 (binaryData contentType은 순수 바이너리 바디만 가능).
- **수정**: 각 업로드 노드 직후에 병렬 리프 노드(`Set Featured Image Alt Text` / `Set Body Image 1 Alt Text` / `Set Body Image 2 Alt Text`)를 추가했습니다. 업로드된 미디어 id로 `POST /wp/v2/media/{id}`를 한 번 더 호출해서 `alt_text`를 채웁니다. 값은 Claude가 생성한 포스트 제목(`title`)을 그대로 씁니다 — 이미지별 개별 캡션까지는 아직 생성하지 않아서, 제목을 재사용하는 게 가장 안전하고 간단한 선택입니다.
- 기존 발행 체인(`Finalize Featured Media`, `Search Pexels Image B2`, `Insert Body Images`)은 그대로 유지되고, 이 세 노드는 곁가지로만 붙습니다 — alt 텍스트 설정이 실패해도(`onError: continueRegularOutput`) 발행 자체는 절대 막히지 않습니다.
- 기존에 이미 발행된 글의 이미지는 소급 적용되지 않습니다 (새로 업로드되는 이미지부터 적용).

**⚠️ Import 후 필수**: 새로 추가된 노드 3개(`Set Featured Image Alt Text`, `Set Body Image 1 Alt Text`, `Set Body Image 2 Alt Text`) 모두 "Gabia" Basic Auth 크리덴셜을 재선택해야 합니다.

## v2.9 — HTML 엔티티 디코딩 + 수동 `/post`의 id 유실 버그 수정 (신규)

- **`Extract OG Image`**: 뉴스 사이트가 `og:image` 메타태그에 `&amp;` 같은 HTML 엔티티를 이스케이프해서 내려주는 경우가 있는데, 이걸 그대로 다운로드 URL로 쓰면 n8n이 쿼리스트링 파싱에 실패해 "Bad request"가 났습니다 (조선일보 기사에서 실제 재현). 추출 직후 엔티티를 디코딩하도록 고쳤습니다.
- **`Parse & Split Articles`**: 네이버 뉴스 API가 제목에 `<b>` 강조 태그뿐 아니라 `&quot;` 등 엔티티도 그대로 내려주는데, 태그만 제거하고 있어서 텔레그램/Claude 프롬프트에 깨진 텍스트가 노출되던 것도 같이 고쳤습니다.
- **수동 `/post` 흐름의 `id` 유실 버그**: `Keyword Context`가 `Insert Manual Keyword`(Supabase insert)의 응답에서 바로 `id`를 읽고 있었는데, 이 응답에 생성된 행의 `id`가 안 들어있는 경우 `undefined`가 되어 `Mark Handled`에서 `invalid input syntax for type bigint: "undefined"` 에러가 났습니다. 자동 트렌드 흐름이 이미 쓰고 있던 것과 동일한 안전장치(insert 후 재조회해서 키워드+날짜로 매칭)를 수동 흐름에도 적용했습니다 — 새 노드 `Get Manual Keyword Row`(Supabase getAll) → `Find Manual Keyword Row`(Code, 매칭)가 `Insert Manual Keyword`와 `Keyword Context` 사이에 들어갑니다.

## v2.8 — 본문 이미지 스타일링 + Rank Math SEO 필드 실제 채우기

워드프레스 포스팅 목록의 Rank Math 컬럼(Keyword: Not Set, Links: 0/0/0)이 전부 비어있던 문제를 고쳤습니다.

- **본문 이미지 스타일**: `Insert Body Images`가 삽입하는 `<figure>`/`<img>`에 인라인 스타일(`width:100%`, `text-align:center`, `margin:0 auto`)을 추가해서 테마 CSS와 무관하게 항상 너비 100% + 가운데 정렬로 나오도록 고쳤습니다.
- **Rank Math Focus Keyword / Meta Description 실제 전송**: `Publish WordPress`의 요청 본문에 `meta: { rank_math_focus_keyword, rank_math_description }`를 추가했습니다. Focus Keyword는 `Keyword Context`의 실제 키워드를, Meta Description은 Claude가 이미 생성하고 있었지만 지금까지 아무 데도 전송되지 않고 버려지던 `meta_description` 필드를 그대로 씁니다. **VERIFY IN UI**: 테스트 발행 후 Rank Math에 반영이 안 되면, 워드프레스 관리자 → Rank Math → Titles & Meta에서 REST API 메타 노출 설정을 확인해주세요 (플러그인 버전에 따라 기본값이 다를 수 있음).
- **외부 링크(Links 컬럼)가 0으로 잡히던 문제**: 그동안 프롬프트가 "뉴스 출처 링크를 자연스럽게 언급해줘"라고만 되어 있어 Claude가 URL을 실제 `<a href>` 태그가 아니라 평문으로 적었을 가능성이 높습니다. 프롬프트를 "반드시 실제 기사 URL을 href 속성에 넣은 진짜 a 태그를 써야 한다"고 명시적으로 바꿨습니다.
- **참고**: Rank Math의 Schema 컬럼이 "Article (BlogPosting)"으로 고정된 건 정상입니다 — 일반 블로그 글에 맞는 기본 타입이고, "NewsArticle"은 구글 뉴스 등록을 노릴 때만 의미가 있어 지금 단계에서 바꿀 필요는 없습니다.
- **다음 단계로 고려할 만한 것 (아직 미구현)**: 사이트 내 다른 글로 연결되는 내부 링크는 여전히 없습니다. 구현하려면 발행 전에 같은 카테고리/태그의 기존 글을 워드프레스에서 조회해 Claude에게 후보로 제공하는 단계가 추가로 필요합니다 — 원하시면 다음에 추가해드릴 수 있습니다.

## v2.7 — 대표 이미지는 저작권 안전한 Pexels, 본문 이미지 1장만 뉴스 기사에서

저작권 리스크를 줄이기 위해 이미지 소스를 재배치했습니다: **가장 눈에 띄는 대표 이미지(목록/공유 시 노출)는 항상 Pexels 스톡 사진**을 쓰고, **뉴스 기사 원문 사진은 본문 이미지 2장 중 1장에만**, 그것도 실패 시 Pexels로 자연스럽게 대체되도록 배치했습니다.

- **대표 이미지 = 항상 Pexels**: `Search Pexels Image` → `Select Pexels Photo` → `IF Image Found` → `Download Featured Image` → `Upload Featured Image to WordPress` → `Finalize Featured Media`. `Claude Draft`가 생성하는 `body_image_keywords`(정확히 2개짜리 영어 키워드 배열) 중 첫 번째로 검색하며, 뉴스 기사 사진은 이 경로에 전혀 관여하지 않습니다.
- **본문 이미지 1 = 뉴스 기사 사진, 실패 시 Pexels 대체**: `Fetch First Article Page`가 이번 포스팅에 쓰인 첫 뉴스 기사 원문을 가져오고, `Extract OG Image`가 `og:image` 메타태그를 정규식으로 추출합니다. `IF OG Image Found`가 성공하면 그 이미지를 그대로 `Download Body Image 1`로 보내고, 실패(사이트 차단, og:image 없음)하면 `Search Pexels Image B1`(body_image_keywords[0] 재사용)로 자동 대체됩니다.
- **본문 이미지 2 = 항상 Pexels**: `Search Pexels Image B2` → ... → `Upload Body Image 2`, body_image_keywords[1]로 검색.
- **`Insert Body Images`**가 두 이미지의 업로드 결과를 `$('Upload Body Image 1'/'2')`를 try/catch로 조회해서(둘 다, 하나만, 또는 둘 다 없어도 안전하게 동작), `body_html`을 문단(`</p>`) 기준으로 나눠 1/3·2/3 지점에 `<figure><img></figure>`로 삽입합니다. `Publish WordPress`는 `Parse Claude Response`가 아니라 이 노드의 `body_html`을 사용합니다.
- Claude에게는 여전히 본문에 직접 `<img>` 태그나 이미지 자리표시를 넣지 말라고 명시 — 이미지 삽입은 전적으로 워크플로우가 프로그래밍적으로 처리합니다.
- **남은 저작권 참고사항**: 본문 이미지 1장은 여전히 언론사 소유 사진을 재사용합니다. 대표 이미지 슬롯에서는 빠졌지만 완전히 없앤 건 아니므로, 트래픽이 늘거나 AdSense 심사를 받을 시점에는 재검토가 필요합니다.

**⚠️ Import 후 필수**: `Search Pexels Image`(대표 이미지용), `Search Pexels Image B1`(뉴스 사진 실패시 대체용), `Search Pexels Image B2`(본문 이미지 2용) 세 노드 모두 `Authorization` 헤더에 Pexels API 키를 넣어야 합니다. `Upload Featured Image to WordPress`, `Upload Body Image 1`, `Upload Body Image 2` 세 노드 모두 "Gabia" Basic Auth 크리덴셜을 재선택해야 합니다.

## v2.6 — 대표 이미지 자동 첨부, 키워드 연관 검색

`Parse Claude Response`와 `Search WP Category` 사이에 Pexels 무료 스톡 사진 API를 이용한 대표 이미지 체인을 추가했습니다.

- **이미지 검색어는 카테고리가 아니라 Claude가 그 포스팅 내용을 보고 직접 생성한 `image_keywords`**(영어 2~4단어)입니다. `Claude Draft`의 도구 스키마와 프롬프트에 이 필드를 추가해서, 카테고리 수준의 뭉뚱그린 이미지가 아니라 실제 기사 소재/상황과 시각적으로 연관된 이미지가 나오도록 했습니다. 다만 Pexels는 실존 인물명이나 한국 고유명사로는 검색이 안 되므로, 그런 경우 Claude가 그 상황을 묘사하는 일반적인 영어 표현으로 바꿔서 생성하도록 프롬프트에 명시했습니다 (예: "손흥민 부상" → `soccer player injury field`).
- `Search Pexels Image` → `Select Pexels Photo` → `IF Image Found` — 검색 결과가 없어도(`found: false`) 전체 발행 체인이 죽지 않고 대표 이미지 없이 계속 진행됩니다 (이 워크플로우 전체에 적용된 "빈 결과가 다운스트림을 막으면 안 된다" 원칙과 동일).
- 이미지를 찾으면 `Download Pexels Image`(바이너리 다운로드) → `Upload Image to WordPress`(`/wp-json/wp/v2/media`에 업로드) → `Finalize Featured Media`가 업로드된 미디어 ID를, 못 찾으면 `0`을 반환합니다.
- `Publish WordPress`의 요청 본문에 `featured_media` 필드가 추가되어, 초안이 대표 이미지가 지정된 상태로 등록됩니다.

**⚠️ Import 후 필수**: [Pexels API](https://www.pexels.com/api/)에서 무료 API 키를 발급받아 `Search Pexels Image` 노드의 `Authorization` 헤더 값(`REPLACE_WITH_YOUR_PEXELS_API_KEY`)을 교체하세요 (Bearer 접두사 없이 키 값만). `Upload Image to WordPress` 노드도 다른 워드프레스 노드들과 마찬가지로 **"Gabia" Basic Auth 크리덴셜을 다시 선택**해야 합니다.

## v2.5 — 볼륨 게이트 + 수동 포스팅 6개월 윈도우 (신규)

- **자동 트렌드 흐름**: 쿨다운을 통과한 후보 중 **검색 볼륨(`approx_traffic`) 1000 이상**인 것만 선택합니다. 1위가 미달이면 2위, 3위 순으로 내려가며 조건 맞는 걸 찾고, 전부 미달이면 "볼륨 있는 키워드가 선정되지 않았습니다" 메시지를 보내고 종료합니다 (쿨다운으로 후보 자체가 없는 경우와는 다른 메시지).
- **수동 `/post` 흐름**: 뉴스 검색 기간을 48시간이 아니라 **최근 6개월(182일)**로 확장했습니다. 네이버 검색 API는 조회수 데이터를 제공하지 않아 "조회수순" 정렬은 불가능해서, 정렬은 기존과 동일하게 `sort=date`(최신순)를 유지하되 기간만 넓혔습니다. 결과 수도 10개 → 30개로 늘려서 6개월 범위 안에서 더 넓게 후보를 가져옵니다.
- `Keyword Context`가 이제 `source`(`trend`/`manual`)를 계속 들고 다니면서, `Search Naver News`의 `display` 값과 `Parse & Split Articles`의 기간 필터, `Telegram: No Recent News`의 안내 문구가 이 값에 따라 자동으로 갈립니다.

## v2.4 — 전체 무음 실패 지점 점검 (신규)

"정상 종료했지만 아무 알림도 없어서 돌았는지 몰랐던" 지점들을 찾아서 고쳤습니다.

- **`/post@봇이름 키워드` 형식 지원**: 그룹 채팅에서 슬래시 명령어에 봇 이름이 붙는 경우(`/post@MyBot 키워드`) 정규식이 매칭하지 못해 조용히 무시되던 문제를 고쳤습니다.
- **트렌드 키워드가 하나도 안 남았을 때 알림 추가**: 상위 20개 키워드가 전부 최근 14일 내 처리된 상태라 `Pick Next Keyword`가 아무것도 못 찾으면, 이제 `Telegram: No New Keyword` 메시지가 갑니다. (전에는 완전히 무음으로 종료됨)
- **키워드 승인 거절 시 알림 추가**: 뉴스 검토 거절은 원래 알림이 갔지만, 첫 단계인 키워드 승인 거절은 알림이 없었습니다. `Telegram: Keyword Rejected`로 통일했습니다.
- **`$('노드명').item.json` → `.first().json` 전체 전환**: 태그 개수가 바뀌는 `Resolve Tag IDs`를 지나 `Aggregate Tag IDs`로 다시 합치는 구간 이후 `.item`(paired item 추적)을 참조하면 "Paired item data ... unavailable" 에러가 났습니다. 이 워크플로우는 실행당 아이템이 항상 1개뿐이라 `.first()`로 바꿔도 동작은 동일하며, 이 에러 자체가 원천적으로 발생하지 않습니다.

## v2.1 — 텔레그램 승인 무응답 시 재전송 + 자동 승인 (신규)

두 승인 지점(키워드 승인 / 뉴스 검토 승인) 모두 아래 규칙이 적용됩니다.

- 최초 메시지(1/5) 전송 후 **3분** 내 응답이 없으면 2/5 재전송
- 이후 재전송은 **5분 간격**으로 3/5, 4/5, 5/5까지 진행 (각 메시지에 "N/5번째 요청" 표시)
- **5/5까지도 응답이 없으면 자동 승인 처리**되어 다음 단계로 그대로 진행됨
- 버튼 클릭(승인/거절)이 오면 대기 중이던 재전송 사이클은 즉시 멈추고 그 결정대로 진행

**신규 노드**: `Keyword Approval Attempt` / `Evaluate Keyword Approval` / `IF Approval Proceed` / `IF Approval Retry` (키워드 승인), `News Review Attempt` / `Evaluate News Review` / `IF News Proceed` / `IF News Retry` (뉴스 검토 승인). 기존 `IF Keyword Approved`, `IF News Approved` 노드는 제거되었습니다.

**⚠️ Import 후 반드시 확인**: `Wait Keyword Approval`, `Wait News Review` 두 노드를 열어서
1. Resume = "On Webhook Call" 유지
2. **"Limit Wait Time" 토글 ON**
3. Limit Type = "After Time Interval"
4. Amount 필드가 표현식(`{{ }}`) 모드로 들어갔는지 확인 — 숫자 입력창으로 깨져 보이면 필드 옆 fx 아이콘을 눌러 expression 모드로 전환 후 JSON에 있는 식을 그대로 다시 입력

**주의**: 재전송이 한 번이라도 일어나면, 이전 메시지의 승인/거절 버튼은 더 이상 유효하지 않습니다 (그 시점의 대기 인스턴스가 이미 지나갔기 때문). 항상 **가장 최근에 온 메시지**의 버튼을 눌러야 합니다.

## v2.3 — 워드프레스 자동 발행 복구 + 카테고리/태그 실제 연결 (신규)

몇 달간 막혀있던 워드프레스 401(`rest_cannot_create`) 원인이 **User-Agent 헤더**였던 것으로 확인됐습니다. n8n의 기본 User-Agent(`n8n`)가 어딘가(워드프레스 보안 플러그인 등, Gabia 인프라 레벨은 아님)에서 걸러지고 있었고, `curl/8.21.0`처럼 흔한 값으로 바꾸니 정상 통과했습니다. 이제 이메일 임시방편을 걷어내고 실제 워드프레스 Draft 등록으로 복구했습니다.

**새로 추가된 체인** (`Parse Claude Response` → `Publish WordPress` → `Mark Handled` 사이):
- `Search WP Category` → `Normalize Category Search` → `IF Category Found` → (없으면) `Create WP Category` — Claude가 고른 카테고리 문자열을 실제 워드프레스 카테고리 ID로 변환 (없으면 새로 생성)
- `Get All WP Tags` → `Resolve Tag IDs` → `IF Tag Needs Create` → (신규 태그만) `Create WP Tag` → `Aggregate Tag IDs` → `Finalize Tag IDs` — Claude가 만든 태그 배열을 실제 워드프레스 태그 ID 배열로 변환 (신규 태그는 그때그때 생성)
- `Publish WordPress` — `status: "draft"`로 등록 (대표 이미지 등 최종 검토 후 워드프레스 관리자 화면에서 직접 Publish)
- `Mark Handled`가 다시 `wp_post_id`를 실제로 기록 (이메일 시절엔 안 썼던 컬럼)

**⚠️ Import 후 필수**: 새로 추가된 워드프레스 관련 노드 5개(`Search WP Category`, `Create WP Category`, `Get All WP Tags`, `Create WP Tag`, `Publish WordPress`) 전부 **"Gabia" Basic Auth 크리덴셜을 다시 선택**해주세요 (JSON엔 플레이스홀더 ID만 들어있어 자동 연결 안 됨). 이 5개 노드 모두 `User-Agent: curl/8.21.0` 헤더가 그대로 남아있는지도 확인하세요 — **이 헤더가 401을 우회하는 핵심**이라 실수로 지우면 다시 막힙니다.

## v2.2 — 뉴스 검토 승인에 코멘트 추가 (신규)

`Send Telegram News Review` 메시지를 받은 뒤, 버튼 대신 **텍스트로 답장**하면 코멘트를 함께 남길 수 있습니다.

- `승인: 이번엔 좀 더 캐주얼한 톤으로 써줘` / `거절: 뉴스가 너무 오래됐어`
- 코멘트 없이 그냥 `승인` / `거절`만 입력해도 동작 (기존 버튼과 동일하게 처리)
- 남긴 코멘트는 Claude 프롬프트에 `[검토자 코멘트]`로 추가되어 초안 작성 시 반영됩니다
- 기존 ✅/❌ 버튼은 그대로 유지되며, 코멘트 없이 빠르게 승인/거절할 때 계속 쓰시면 됩니다

**동작 원리**: 뉴스 검토 메시지를 보낼 때마다(재전송 포함) 그 시점의 `$execution.resumeUrl`을 `trending_keywords.pending_review_resume_url` 컬럼에 저장해둡니다. 텍스트로 `승인`/`거절`이 오면 `Parse Approval Comment` → `Get Rows For Approval Lookup` → `Find Pending Resume URL` → `Resolve Pending Approval`(그 URL에 GET 요청) → `Clear Pending Resume URL` → `Telegram: Comment Approval Ack` 순서로 처리되어, 버튼을 누른 것과 동일하게 대기 중인 Wait 노드를 재개시킵니다.

**선행 작업**: `db/004_add_pending_review_resume_url.sql`을 Supabase SQL Editor에서 실행해주세요.

**v2.1부터 이 파일은 n8n에서 실제 export한 최종본("Daily Posting")을 베이스로 병합했습니다** — 크리덴셜 ID, 실제 chatId, `Mark Handled`의 filters 방식 등 UI에서 직접 잡으셨던 설정이 그대로 들어 있어 재import 시 크리덴셜을 다시 연결할 필요가 없습니다. 단, 이 저장소가 공개(public)라 `Search Naver News` 노드의 `X-NCP-APIGW-API-KEY-ID`/`X-NCP-APIGW-API-KEY` 값은 플레이스홀더로 바꿔뒀습니다 — **import 후 이 두 값만 실제 키로 다시 입력**해주세요.

## 무엇이 바뀌었나 (v1 대비)

- **3시간마다 실행** (기존 1일 1회 → 매일 8번)
- **반복 방지**: `trending_keywords.posted_at`가 최근 14일 이내인 키워드는 자동 스킵, 남은 것 중 볼륨 1위만 처리
- **키워드 승인**: Telegram으로 "이 키워드로 진행할까요?" 물어보고 승인/거절 대기
- **수동 키워드(Flow B)**: Telegram에서 `/post 키워드` 입력 시 트렌드 승인 없이 바로 처리
- **뉴스 최신성 필터**: 네이버 뉴스를 `sort=date`로 가져와 최근 48시간 이내 기사만 사용, 없으면 스킵 알림
- **수집된 뉴스 검토 승인 (신규)**: 뉴스 수집 직후, 초안 생성 전에 수집된 기사 목록을 텔레그램으로 보여주고 진행/취소 승인 대기 (총 승인 단계 3개: 키워드 선정 → 뉴스 목록 → 최종 발행)
- **발행 전 최종 승인**: 미리보기 링크(`?p={id}&preview=true`)와 함께 발행/삭제 버튼 전송
- **거절 시 처리**: 뉴스 검토 거절 시 초안 생성 자체를 안 함 / 최종 발행 거절 시 이미 만들어진 draft를 영구 삭제 (`force=true`)

## 이번에 같이 고친 버그 2가지

- **Wait 노드 이후 데이터 유실**: 텔레그램 승인 대기(Wait) 후에는 그 이전 데이터가 텔레그램 콜백 값으로 덮어써집니다. 원래 `Keyword Context`가 `$input`으로 받던 걸 `$('Pick Next Keyword')`처럼 노드 이름으로 명시 참조하도록 수정했습니다. `Claude Draft`도 같은 이유로 `$('Build News Summary')`를 명시 참조합니다.
- **선정된 키워드의 DB id 유실**: `Pick Next Keyword`가 원래 DB insert 결과가 아니라 원본 트렌드 목록에서 골라서 `id`가 없었습니다. `Insert Keywords History`를 `Get Recently Posted`보다 먼저 실행되도록 순서를 바꾸고, 그 결과에서 직접 매칭해 id를 가져오도록 수정했습니다.

## 가져오기 전 필수 선행 작업

1. `db/003_add_source_column.sql`을 Supabase SQL Editor에서 실행
2. Telegram 봇 생성 및 크리덴셜 준비 (본 대화의 다음 답변에서 안내)
3. n8n에서 기존 워크플로우가 있다면 **Deactivate** 후 이 파일로 교체 Import

## 크리덴셜 연결 (기존 4개 + Telegram 신규)

| 노드 | 크리덴셜 | 비고 |
|---|---|---|
| Insert Keywords History / Get Recently Posted / Insert Manual Keyword / Insert News / Mark Published | Supabase | 기존과 동일 |
| Search Naver News | Header Parameters 직접 입력 | `X-NCP-APIGW-API-KEY-ID`, `X-NCP-APIGW-API-KEY` |
| Claude Draft | Header Auth (`x-api-key`) | 기존과 동일 |
| Publish WordPress / Publish Status Update / Delete WordPress Draft | Basic Auth | 기존과 동일, URL은 `deohaam.com`으로 이미 반영됨 |
| **Send Telegram Keyword Approval / Send Telegram Final Approval / Telegram Trigger (Manual Keyword) / Telegram: No Recent News** | **Telegram API** | 신규 — Bot Token 하나로 4개 노드 전부 연결 |

## ⚠️ 가져온 뒤 반드시 검증해야 할 것 (버전에 따라 다를 수 있음)

- **Telegram 노드의 `reply_markup` (인라인 버튼)**: 노드 파라미터의 정확한 필드 경로가 n8n 버전마다 다를 수 있습니다. Import 후 버튼이 안 보이면, 노드를 열어 UI의 "Reply Markup → Inline Keyboard" 항목으로 직접 재구성하고, 각 버튼 URL을 `{{ $execution.resumeUrl }}?decision=approve` / `?decision=reject`로 지정하세요.
- **Wait 노드 재개 시 데이터 위치**: `IF Keyword Approved`/`IF Final Approved`의 조건식이 `$json.query.decision`을 읽습니다. 실제로 실행해보고 Wait 노드 재개 시 데이터가 어디에 담기는지 확인 후 필요하면 경로를 수정하세요.
- **IF 노드 조건 UI**: n8n 버전에 따라 조건 빌더 UI가 다를 수 있어, Import 후 조건이 깨져 보이면 그대로 다시 설정해주세요 (의도는: 문자열이 정확히 `approve`인지 비교).

## 테스트 순서 권장

1. `Extract Top 20` ~ `Pick Next Keyword`까지 개별 실행 → 실제로 새 키워드 하나가 선택되는지 확인
2. `Send Telegram Keyword Approval` 단독 실행 → 본인 텔레그램에 메시지+버튼이 오는지 확인
3. 버튼 클릭 후 `Wait Keyword Approval`이 재개되는지, `IF Keyword Approved`가 올바르게 분기하는지 확인
4. 이후 공통 체인은 기존과 동일한 방식으로 단계별 확인
