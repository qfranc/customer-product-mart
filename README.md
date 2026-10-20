# 고객별 상품 실적 현황 마트

고객이 보유한 수신 · 여신 · 카드 · 서비스의 보유 및 이용 현황을 `기준일자 × 고객번호` 단위의 일자별 스냅샷으로 통합한 데이터 마트입니다.

포트폴리오 「고객별 상품 실적 현황 데이터 마트 설계서」의 **SQL 전문과 컬럼 명세**를 담고 있습니다. 설계 의도와 핵심 로직 설명은 설계서 본문에 있습니다.

## 구조

| 영역 | 단위 | 내용 |
|---|---|---|
| 표준 영역 (선행 마트) | 계좌 × 일 | 원천 개념 단위로 여러 분석에서 재사용 — 일자 마스터, 일별계좌잔액, 계좌연속거래마스터 |
| 소비 영역 (통합 마트) | 고객 × 일 | 분석 · 마케팅 목적의 가공 · 플래그 — 고객별상품실적현황 |
| 정합성 검증 | 기준일자 | 원천 대비 5개 항목 대사 후 검증 결과 테이블에 적재 |

## 배치 순서

| 순서 | 파일 | 내용 | 설계서 |
|---|---|---|---|
| 초기 1회 | [`sql/01_daily_account_balance_init.sql`](sql/01_daily_account_balance_init.sql) | 일별계좌잔액 초기적재 | 4.1 |
| 일 배치 1 | [`sql/02_daily_account_balance_incremental.sql`](sql/02_daily_account_balance_incremental.sql) | 일별계좌잔액 증분 MERGE — 당일 거래 없는 계좌는 전일 잔액 Carry-Forward | 4.1 |
| 일 배치 2 | [`sql/03_account_streak_master.sql`](sql/03_account_streak_master.sql) | 계좌연속거래마스터 적재 (기준일자 DELETE 후 적재) | 2.3 |
| 일 배치 3 | [`sql/04_customer_product_mart.sql`](sql/04_customer_product_mart.sql) | 고객별상품실적현황 Main 마트 적재 (기준일자 DELETE 후 INSERT) | 4.2 |
| 일 배치 4 | [`sql/05_validation.sql`](sql/05_validation.sql) | 원천 대비 정합성 검증 5개 항목 | 6 |

- 일자 마스터는 연 1회 또는 운영 주기에 따라 적재하며, 컬럼 명세만 수록했습니다.
- 적재 배치(02 ~ 04)는 MERGE 또는 기준일자 DELETE 후 INSERT로 작성해, 같은 기준일자로 재실행해도 결과가 같습니다.

## 조건별 추출

| 파일 | 내용 | AARRR |
|---|---|---|
| [`5.1_customer_segment.sql`](sql/extract/5.1_customer_segment.sql) | 성별 · 연령대 · 직업별 세그먼트 추출 | — |
| [`5.2_holding_and_join_order.sql`](sql/extract/5.2_holding_and_join_order.sql) | 상품 · 서비스 보유 여부와 가입 순서 | Acquisition · Activation |
| [`5.3_consecutive_transaction.sql`](sql/extract/5.3_consecutive_transaction.sql) | 계좌별 · 고객별 연속거래 여부 | Retention |
| [`5.4_average_balance.sql`](sql/extract/5.4_average_balance.sql) | 기간별 계좌별 · 고객별 평균잔액 | Retention |
| [`5.5_entry_product_conversion.sql`](sql/extract/5.5_entry_product_conversion.sql) | 진입 상품 기준 타 상품 전환율 | Cross-Activation |

## 컬럼 명세

[`docs/column_spec.md`](docs/column_spec.md) — 선행 마트 · 관리 테이블 6종과 Main 마트(75개 컬럼)의 컬럼명, 데이터타입, 키, 기본값, 설명

## 실행 환경

- DBMS : PostgreSQL (ANSI SQL 기반)
- 파라미터 : `:기준변수일자` — VARCHAR(8), `'YYYYMMDD'` 형식으로 바인딩하여 실행
- Hadoop · Impala 환경에 적용할 때 달라지는 점(파티션 덮어쓰기, 통계 · 소파일 관리)은 설계서 7장에 정리했습니다.
