# Confluence REST API 빠른 참조

인증 정보: `.env.local` (`JIRA_EMAIL`, `JIRA_API_TOKEN`)

```bash
source ./agent-common-workflow/.env.local
AUTH="$JIRA_EMAIL:$JIRA_API_TOKEN"
BASE="https://kurubehind.atlassian.net/wiki/rest/api"

# 스페이스 목록
curl -s -u "$AUTH" "$BASE/space?limit=20" | grep -o '"key":"[^"]*"\|"name":"[^"]*"'

# 스페이스 내 페이지 목록
curl -s -u "$AUTH" "$BASE/space/{SPACE_KEY}/content/page?limit=50"

# 페이지 내용 조회 (body + version 포함)
curl -s -u "$AUTH" "$BASE/content/{PAGE_ID}?expand=body.storage,version"

# 페이지 전문 검색
curl -s -u "$AUTH" "$BASE/content/search?cql=text+~+\"{키워드}\"+AND+space.key=\"{SPACE_KEY}\""

# 페이지 업데이트 (version.number = 현재버전 + 1)
curl -s -u "$AUTH" \
  -H "Content-Type: application/json" \
  -X PUT "$BASE/content/{PAGE_ID}" \
  --data-binary @/tmp/payload.json
# payload.json 형식:
# { "version": {"number": N+1}, "title": "...", "type": "page",
#   "body": {"storage": {"value": "<html...>", "representation": "storage"}} }
```

## 주의사항

- 한국어 포함 body는 반드시 파일(`--data-binary @file`)로 전송. 인라인 `-d` 사용 시 UTF-8 파싱 오류.
- `version.number`를 현재 버전 +1로 지정하지 않으면 409 Conflict.
- body는 Confluence Storage Format(HTML 유사). ADF(Jira)와 다름.
