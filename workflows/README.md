# trends-to-wordpress.n8n.json (v2 — Telegram 승인 + 수동 키워드 + 반복 방지)

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
