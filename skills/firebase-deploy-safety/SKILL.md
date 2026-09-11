---
name: firebase-deploy-safety
description: "Firebase Functions·Hosting 배포 명령을 실행하거나 배포 CI 설정을 작성·수정할 때 사용. 여러 레포가 공유하는 codebase에서 --only functions(함수명 미지정)·--force 배포로 다른 레포의 운영 함수가 삭제되는 사고를 막는다."
---

# Firebase Functions 배포 안전 수칙

> **2026-07-07 사고:** kuru_mobile `web-deploy.yml`이 `firebase deploy --only hosting,functions --force`로
> 실행되어, 공유 프로젝트(reservation-manager-6bd70)의 **타 레포 운영 함수 23개가 전부 삭제**됨
> (setOrderList/sendOrderNotify/checkReservation/customSetBot/notifyChat/kuruapi 등).
> 발주·예약·가격 스케줄러가 밤새 404로 전멸. 이 스킬은 그 재발 방지 규칙이다.

## 왜 위험한가

`reservation-manager-6bd70` 한 프로젝트에 **여러 레포가 함수를 배포**한다.
Firebase CLI는 `--only functions`(이름 미지정)로 배포하면 "codebase의 전체 상태 = 이 레포 소스"로
간주하고, **소스에 없는 함수를 전부 삭제 대상**으로 잡는다. `--force`는 그 삭제를 무확인 실행한다.

| 레포 | 배포 함수 | codebase |
|------|----------|----------|
| `kuru_aggregation` | setOrderList, sendOrderNotify, createDemoAccount, getInquries, onCasReferralSet, setUserOrder | default |
| `kuru_mart_functions` | notifyChat, notifyChannelChat, kuruchatsend, ShopCompanyInfoUpdate, CompanyUpdatePrice, furigana, makePriceHistory | default |
| `kuru_cf_check_reservation_email` | checkReservation | default |
| `kuru_mobile` (웹 SEO) | productSeo, sitemap | default |
| `kuru_functions_legacy` | customSetBot, createUser, downloadOrderList, onGmoCasCustomerAuth, onInstantOrderSet, v2onReceiptCreated/Deleted, kuruapi, kuruai, gmoPaymentApi | default |

**전부 codebase `default`를 공유** → 어느 레포든 이름 없는 functions 배포 한 방이면 나머지 전멸.

## 절대 규칙 (CI·수동 공통)

1. **`--only functions`(이름 미지정) 금지.** 반드시 함수명 명시:
   ```
   firebase deploy --only functions:sendOrderNotify,functions:setOrderList
   ```
   이름 지정 배포는 지정한 함수만 만들고/갱신하며 **절대 남을 삭제하지 않는다.**
2. **functions 배포에 `--force` 금지.** (`--force`의 정당한 용도는 artifact cleanup policy 자동 설정뿐.
   이름 미지정 배포와 결합되는 순간 대량 삭제 스위치가 된다.)
3. **hosting 배포는 site 한정:** `--only hosting:<site>` (예: `hosting:kuru-mart`).
   `hosting,functions` 묶음 배포 금지 — hosting 워크플로우에 functions를 끼워넣지 않는다.
4. **새 워크플로우에 `firebase deploy`를 추가할 때는 이 표를 갱신**하고,
   배포 후 `gcloud functions list --project reservation-manager-6bd70` 로 **함수 개수가 줄지 않았는지** 확인한다.

## 배포 후 감사(1분 체크)

```bash
# 함수 수 확인 (기준: 팀 위키/이 문서의 표와 대조. 줄었으면 즉시 중단·복구)
gcloud functions list --project reservation-manager-6bd70 --format='value(name)' | sort

# 삭제 이벤트 감사 (범인 SA/사람 식별)
gcloud logging read 'protoPayload.methodName:"DeleteFunction"' \
  --project reservation-manager-6bd70 --freshness=1d \
  --format='value(timestamp,protoPayload.authenticationInfo.principalEmail,protoPayload.resourceName)'
```

## 사고 시 복구 절차

1. 원인 배포 경로 차단 (해당 워크플로우/브랜치 비활성화) — **재배포 전에 차단 먼저**
2. 각 소스 레포에서 재배포:
   - `kuru_aggregation`: Actions → "Deploy Firebase Functions" workflow_dispatch (전체 6개)
   - `kuru_mart_functions` / `kuru_cf_check_reservation_email`: 각 deploy.yml 재실행
   - 소스 레포가 없는 레거시 함수(kuruapi, customSetBot 등)는 소스 확보 필요 —
     `gs://gcf-sources-…` 또는 `gcf-v2-sources-492230427391-*` 버킷에서 function-source.zip 복원 가능
3. HTTP 공개 함수는 IAM 재설정: `gcloud run services add-iam-policy-binding <fn> --member=allUsers --role=roles/run.invoker`
   (함수 삭제 시 IAM 바인딩도 함께 소멸됨)
4. 스케줄러는 그대로 살아있음 — 함수 복구되면 다음 주기부터 자동 정상화
5. 카트/주문 등 **RTDB 데이터는 함수 삭제와 무관하게 보존**됨 — 미실행된 시메키리는
   백오피스 締め切りトリガー(実行する) 수동 실행으로 소급 집계 가능

## 중장기 개선 (권장)

- **codebase 분리**: 각 레포 `firebase.json`에 고유 codebase 지정
  (`"codebase": "aggregation"` / `"mart"` / `"reservation"` / `"mobile-web"`).
  분리하면 삭제 영향 범위가 자기 codebase로 한정된다.
  ⚠️ 전 레포 동시 전환 필요(한 레포만 default에 남으면 그 레포가 여전히 전체를 지배).

## 부가 안전장치 (2026-07-08 추가)

- **함수 삭제 실시간 알림**: DeleteFunction 감사로그 → Slack 웹훅("KURU 함수 삭제 감시") — 삭제 즉시 채널 알림.
- **레포 설명 컨벤션**: 함수 레포 description = `[Cloud Functions] <역할> | deploys: 함수목록 | project: <프로젝트>` (복구 맵 겸용). 신규 함수 레포명은 `kuru_functions_<도메인>` 패턴.
- **레거시 레포화 완료**: 소스 없던 11개 함수 → kuru_functions_legacy (CI 배포 검증 완료, KBO-344).
- **알려진 부채**: kuru_functions_legacy/kuruai 소스에 하드코딩 크리덴셜(OpenAI·SA키·Supabase JWT) — 배포본 그대로 복원. 추후 로테이션+Secret 관리 이전 필요.
