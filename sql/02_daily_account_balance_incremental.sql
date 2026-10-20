/* ============================================================
 일별계좌잔액 — 증분 적재 MERGE (일 배치)
 파라미터 : :기준변수일자 (YYYYMMDD)

 처리 대상:
 Part 1. 당일 거래 있는 계좌 → 당일 최종 거래후잔액 적재
 Part 2. 당일 거래 없는 계좌 → 전일 잔액 Carry-Forward
============================================================ */

MERGE INTO 일별계좌잔액 TG
USING (

WITH 거래일자잔액 AS (

----- 수신 거래 일자별 마감잔액 -----

SELECT '01'       AS 수신여신구분코드
     , 계약번호     AS 계약번호
     , 거래후잔액   AS 거래후잔액
     , ROW_NUMBER() OVER ( PARTITION BY 계약번호 ORDER BY 거래시각 DESC, 거래일련번호 DESC) AS RN
  FROM 수신거래내역
 WHERE 거래상태코드 = '01'  -- 정상거래만
   AND 거래일자 = :기준변수일자

UNION ALL

------ 여신 거래 일자별 마감잔액 -----

SELECT '02'       AS 수신여신구분코드
     , 계약번호     AS 계약번호
     , 거래후잔액   AS 거래후잔액
     , ROW_NUMBER() OVER ( PARTITION BY 계약번호 ORDER BY 거래시각 DESC, 거래일련번호 DESC) AS RN
  FROM 여신거래내역
 WHERE 거래상태코드 = '01'  -- 정상거래만
   AND 거래일자 = :기준변수일자

)

, 일별최종거래 AS (   -- 일자 마지막 거래건만

SELECT 수신여신구분코드
     , 계약번호
     , 거래후잔액  AS 일마감잔액
  FROM 거래일자잔액
 WHERE RN = 1

)

, 통합계좌기본 AS (   -- 수신/여신 계좌 마스터

SELECT '01'      AS 수신여신구분코드
     , 계약번호
     , 고객번호
     , 상품코드
  FROM 수신계좌
 WHERE 신규일자 <= :기준변수일자
   AND COALESCE(해지일자, '99991231') >= :기준변수일자

UNION ALL

SELECT '02'      AS 수신여신구분코드
     , 계약번호
     , 고객번호
     , 상품코드
  FROM 여신계좌
 WHERE 신규일자 <= :기준변수일자
   AND COALESCE(해지일자, '99991231') >= :기준변수일자

)

, 직전최종잔액 AS (

------ 가장 최근 직전일자의 잔액 가져오기 (거래 없는 계좌 적재) -----

SELECT 수신여신구분코드
     , 계약번호
     , 일마감잔액  AS 전일마감잔액
  FROM (
        SELECT 수신여신구분코드
             , 계약번호
             , 일마감잔액
             , ROW_NUMBER() OVER ( PARTITION BY 수신여신구분코드, 계약번호 ORDER BY 기준일자 DESC ) AS PRN
          FROM 일별계좌잔액
         WHERE 기준일자 < :기준변수일자  -- 오늘 직전 과거 데이터 중 가장 최근 건
       )
 WHERE PRN = 1

)

----- 수신/여신 기준변수일자 잔액 -----

SELECT :기준변수일자  AS 기준일자
     , ATG.수신여신구분코드
     , ATG.계약번호
     , ATG.고객번호
     , ATG.상품코드
     , COALESCE( ACL.일마감잔액, APR.전일마감잔액, CAST( 0 AS NUMERIC(18, 2) ) )   AS 일마감잔액
  FROM 통합계좌기본 ATG
  LEFT JOIN 일별최종거래 ACL
    ON ATG.수신여신구분코드 = ACL.수신여신구분코드
   AND ATG.계약번호 = ACL.계약번호
  LEFT JOIN 직전최종잔액 APR
    ON ATG.수신여신구분코드 = APR.수신여신구분코드
   AND ATG.계약번호 = APR.계약번호

) SC

ON (
      TG.기준일자       = SC.기준일자
  AND TG.수신여신구분코드 = SC.수신여신구분코드
  AND TG.계약번호       = SC.계약번호
)

-- 1. 매칭되는 당일 데이터가 이미 존재한다면 (예: 당일 배치 재처리 등) 최신 잔액으로 갱신

WHEN MATCHED THEN
UPDATE SET 고객번호   = SC.고객번호
         , 상품코드   = SC.상품코드
         , 일마감잔액 = SC.일마감잔액

-- 2. 당일 데이터가 없다면 신규 삽입

WHEN NOT MATCHED THEN
INSERT (
         기준일자
       , 수신여신구분코드
       , 계약번호
       , 고객번호
       , 상품코드
       , 일마감잔액
       )
VALUES (
         SC.기준일자
       , SC.수신여신구분코드
       , SC.계약번호
       , SC.고객번호
       , SC.상품코드
       , SC.일마감잔액
       )
;
