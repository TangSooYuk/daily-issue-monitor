# trends-to-wordpress.n8n.json (v2 — Telegram 승인 + 수동 키워드 + 반복 방지)

## 무엇이 바뀌었나 (v1 대비)

- **3시간마다 실행** (기존 1일 1회 → 매일 8번)
- **반복 방지**: `trending_keywords.posted_at`가 최근 14일 이내인 키워드는 자동 스킵, 남은 것 중 볼륨 1위만 처리
- **키워드 승인**: Telegram으로 "이 키워드로 진행할까요?" 물어보고 승인/거절 대기
- **수동 키워드(Flow B)**: Telegram에서 `/post 키워드` 입력 시 트렌드 승인 없이 바로 처리
- **뉴스 최신성 필터**: 네이버 뉴스를 `sort=date`로 가져와 최근 48시간 이내 기사만 사용, 없으면 스킵 알림
- **발행 전 최종 승인**: 미리보기 링크(`?p={id}&preview=true`)와 함께 발행/삭제 버튼 전송
- **거절 시 처리**: 초안 draft를 영구 삭제 (`force=true`)

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
