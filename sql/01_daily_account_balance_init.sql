-- ================================================================
-- 일별계좌잔액 초기적재 쿼리
-- 초기 적재 시 활용
-- 이후 일 증분 적재는 MERGE DML 활용
-- :기준변수일자  - 변수날짜까지 모든 거래 내역을 일별로 적재함
-- TRUNCATE TABLE 로 비우고 시작
-- ================================================================

TRUNCATE TABLE 일별계좌잔액 ;

INSERT INTO 일별계좌잔액
(
  기준일자
, 수신여신구분코드
, 계약번호
, 고객번호
, 상품코드
, 일마감잔액
, 적재일시
)

WITH 거래일자잔액 AS (

----- 수신 거래 일자별 마감잔액 -----

SELECT '01'                        AS 수신여신구분코드
     , 계약번호                      AS 계약번호
     , COALESCE(기산일자, 거래일자)   AS 거래기준일자
     , 거래후잔액                    AS 거래후잔액
     , ROW_NUMBER() OVER ( PARTITION BY 계약번호, COALESCE(기산일자, 거래일자)
                               ORDER BY 거래시각 DESC, 거래일련번호 DESC
                         )         AS RN
  FROM 수신거래내역
 WHERE 거래상태코드 = '01'  -- 정상거래만

UNION ALL

------ 여신 거래 일자별 마감잔액 -----

SELECT '02'                        AS 수신여신구분코드
     , 계약번호                      AS 계약번호
     , COALESCE(기산일자, 거래일자)   AS 거래기준일자
     , 거래후잔액                    AS 거래후잔액
     , ROW_NUMBER() OVER ( PARTITION BY 계약번호, COALESCE(기산일자, 거래일자)
                               ORDER BY 거래시각 DESC, 거래일련번호 DESC
                         )         AS RN
  FROM 여신거래내역
 WHERE 거래상태코드 = '01'  -- 정상거래만

)

, 일별최종거래 AS (   -- 일자 마지막 거래건만

SELECT 수신여신구분코드
     , 계약번호
     , 거래기준일자      AS 최종거래일자
     , 거래후잔액        AS 일마감잔액
     , COALESCE( ( LEAD(거래기준일자) OVER ( PARTITION BY 수신여신구분코드, 계약번호 ORDER BY 거래기준일자 ) ) , '99991231' )  AS 다음거래일자
  FROM 거래일자잔액
 WHERE RN = 1

)

, 통합계좌기본 AS (   -- 수신/여신 계좌 마스터

SELECT '01'      AS 수신여신구분코드
     , 계약번호
     , 고객번호
     , 상품코드
     , 신규일자
     , 해지일자
     , LEAST( COALESCE(해지일자, '99991231') , :기준변수일자)  AS 계좌종료일자
  FROM 수신계좌

UNION ALL

SELECT '02'      AS 수신여신구분코드
     , 계약번호
     , 고객번호
     , 상품코드
     , 신규일자
     , 해지일자
     , LEAST( COALESCE(해지일자, '99991231') , :기준변수일자)  AS 계좌종료일자
  FROM 여신계좌

)

, 계좌통합일자 AS (   -- 계좌 잔액을 붙이기 위한 생존 일자 전개

SELECT DBASE.기준일자
     , ACO.수신여신구분코드
     , ACO.계약번호
     , ACO.고객번호
     , ACO.상품코드
  FROM 통합계좌기본 ACO
 INNER JOIN 일자마스터 DBASE
    ON DBASE.기준일자 BETWEEN ACO.신규일자 AND ACO.계좌종료일자

)

----- 수신/여신 일별 잔액 -----

SELECT ACD.기준일자
     , ACD.수신여신구분코드
     , ACD.계약번호
     , ACD.고객번호
     , ACD.상품코드
     , COALESCE( ACL.일마감잔액, CAST( 0 AS NUMERIC(18, 2) ) ) AS 일마감잔액
     , CURRENT_TIMESTAMP  AS 적재일시
  FROM 계좌통합일자 ACD
  LEFT JOIN 일별최종거래 ACL
    ON ACD.수신여신구분코드 = ACL.수신여신구분코드
   AND ACD.계약번호 = ACL.계약번호
   AND ACD.기준일자 >= ACL.최종거래일자
   AND ACD.기준일자 < ACL.다음거래일자

;
