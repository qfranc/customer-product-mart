/* ==============================================================================
--  정합성 검증 SQL  ( PostgreSQL ANSI SQL )
--
--  소스 집계값과 고객별상품실적현황 마트 값을 대사하여 검증테이블에 적재 및 조회
--  :기준변수일자  - VARCHAR(8) 'YYYYMMDD'
--
--  고객별상품실적현황 마트 - 정상고객 (고객상태코드='01') 대상
--  ( 검증일자 / 검증항목명 / 검증유형명 / 소스검증값 / 마트검증값 / 검증결과 / 적재일시 )
-- ============================================================================= */

/*  1. 고객수 검증  */

-- INSERT INTO 검증테이블

WITH 소스검증테이블 AS (
SELECT '고객수'   AS 검증항목
     , CAST( COUNT( 고객번호 ) AS VARCHAR )  AS 소스검증값
  FROM 고객
 WHERE 고객상태코드 = '01'   /* 01 : 정상 */
)

, 마트검증테이블 AS (
SELECT '고객수'   AS 검증항목
     , CAST( COUNT( 고객번호 ) AS VARCHAR )  AS 마트검증값
  FROM 고객별상품실적현황
 WHERE 기준일자 = :기준변수일자
)
SELECT :기준변수일자           AS 검증일자
     , A.검증항목              AS 검증항목명
     , 'CNT'                  AS 검증유형명
     , A.소스검증값            AS 소스검증값
     , B.마트검증값            AS 마트검증값
     , CASE WHEN A.소스검증값 = B.마트검증값 THEN '일치'
            ELSE '불일치'
       END                    AS 검증결과
     , CURRENT_TIMESTAMP      AS 적재일시
  FROM 소스검증테이블 A
  LEFT OUTER JOIN 마트검증테이블 B
    ON A.검증항목 = B.검증항목
;

/*  2. 수신 총 잔액 합계 검증  */

-- INSERT INTO 검증테이블

WITH 소스검증테이블 AS (
SELECT '수신총잔액합계'   AS 검증항목
     , CAST( SUM( A.계좌잔액 )  AS VARCHAR )  AS 소스검증값
  FROM 수신계좌 A
 INNER JOIN 고객 B
    ON A.고객번호 = B.고객번호
   AND B.고객상태코드 = '01'       /* 01 : 정상 */
 WHERE A.수신계좌상태코드 = '01'   /* 01 : 정상 */
)

, 마트검증테이블 AS (
SELECT '수신총잔액합계'   AS 검증항목
     , CAST( SUM( 수신_총잔액 )  AS VARCHAR )  AS 마트검증값
  FROM 고객별상품실적현황
 WHERE 기준일자 = :기준변수일자
   AND 수신_보유여부 = 'Y'
)
SELECT :기준변수일자        AS 검증일자
     , A.검증항목           AS 검증항목명
     , 'SUM'               AS 검증유형명
     , A.소스검증값         AS 소스검증값
     , B.마트검증값         AS 마트검증값
     , CASE WHEN A.소스검증값 = B.마트검증값 THEN '일치'
            ELSE '불일치'
       END                 AS 검증결과
     , CURRENT_TIMESTAMP   AS 적재일시
  FROM 소스검증테이블 A
  LEFT OUTER JOIN 마트검증테이블 B
    ON A.검증항목 = B.검증항목
;

/*  3. 여신 정상 계좌수 검증  */

-- INSERT INTO 검증테이블

WITH 소스검증테이블 AS (

SELECT '여신계좌수'   AS 검증항목
     , CAST( COUNT( A.계약번호 ) AS VARCHAR )   AS 소스검증값
  FROM 여신계좌 A
 INNER JOIN 고객 B
    ON A.고객번호 = B.고객번호
   AND B.고객상태코드 = '01'       /* 01 : 정상 */
 WHERE A.여신계좌상태코드 = '01'   /* 01 : 정상 */

)

, 마트검증테이블 AS (

SELECT '여신계좌수'   AS 검증항목
     , CAST( SUM( 여신_정상계좌수 ) AS VARCHAR )  AS 마트검증값
  FROM 고객별상품실적현황
 WHERE 기준일자 = :기준변수일자
   AND 여신_보유여부 = 'Y'

)
SELECT :기준변수일자       AS 검증일자
     , A.검증항목          AS 검증항목명
     , 'CNT'               AS 검증유형명
     , A.소스검증값        AS 소스검증값
     , B.마트검증값        AS 마트검증값
     , CASE WHEN A.소스검증값 = B.마트검증값 THEN '일치'
            ELSE '불일치'
       END                 AS 검증결과
     , CURRENT_TIMESTAMP   AS 적재일시
  FROM 소스검증테이블 A
  LEFT OUTER JOIN 마트검증테이블 B
    ON A.검증항목 = B.검증항목
;

/*  4. 카드 발급 수 검증  */

-- INSERT INTO 검증테이블

WITH 소스검증테이블 AS (

SELECT '발급카드수'   AS 검증항목
     , CAST( COUNT( A.카드번호 ) AS VARCHAR )   AS 소스검증값
  FROM 카드 A
 INNER JOIN 고객 B
    ON A.고객번호 = B.고객번호
   AND B.고객상태코드 = '01'   /* 01 : 정상 */
 WHERE A.카드상태코드 = '01'   /* 01 : 정상 */

)

, 마트검증테이블 AS (

SELECT '발급카드수'   AS 검증항목
     , CAST( SUM( 카드_정상카드수 ) AS VARCHAR )  AS 마트검증값
  FROM 고객별상품실적현황
 WHERE 기준일자 = :기준변수일자
   AND 카드_보유여부 = 'Y'

)
SELECT :기준변수일자       AS 검증일자
     , A.검증항목          AS 검증항목명
     , 'CNT'               AS 검증유형명
     , A.소스검증값        AS 소스검증값
     , B.마트검증값        AS 마트검증값
     , CASE WHEN A.소스검증값 = B.마트검증값 THEN '일치'
            ELSE '불일치'
       END                 AS 검증결과
     , CURRENT_TIMESTAMP   AS 적재일시
  FROM 소스검증테이블 A
  LEFT OUTER JOIN 마트검증테이블 B
    ON A.검증항목 = B.검증항목
;

/*  5. 서비스 최초사용일자 검증  */

-- INSERT INTO 검증테이블

WITH 소스검증테이블 AS (

SELECT '서비스최초사용일자'        AS 검증항목
     , MIN( A.서비스최초사용일자 )   AS 소스검증값
  FROM 고객서비스명세 A
 INNER JOIN 고객 B
    ON A.고객번호 = B.고객번호
   AND B.고객상태코드 = '01'     /* 01 : 정상 */
 WHERE A.서비스상태코드 = '01'   /* 01 : 정상 */

)

, 마트검증테이블 AS (

SELECT '서비스최초사용일자'         AS 검증항목
     , MIN( 서비스_최초사용일자 )   AS 마트검증값
  FROM 고객별상품실적현황
 WHERE 기준일자 = :기준변수일자
   AND 서비스_이용여부 = 'Y'

)
SELECT :기준변수일자       AS 검증일자
     , A.검증항목          AS 검증항목명
     , 'MIN'               AS 검증유형명
     , A.소스검증값        AS 소스검증값
     , B.마트검증값        AS 마트검증값
     , CASE WHEN A.소스검증값 = B.마트검증값 THEN '일치'
            ELSE '불일치'
       END                 AS 검증결과
     , CURRENT_TIMESTAMP   AS 적재일시
  FROM 소스검증테이블 A
  LEFT OUTER JOIN 마트검증테이블 B
    ON A.검증항목 = B.검증항목
;
