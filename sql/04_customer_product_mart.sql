/* ============================================================================
*  고객별 상품실적현황 마트
* ----------------------------------------------------------------------------
*  목적  : 고객기준 수신/여신/카드/서비스의 보유 및 이용 현황과
          상품 지표를 하나의 테이블에서 집계하여 분석에 활용
*  산출단위 : 기준일자 , 고객번호  ( 일자별 스냅샷 / PK = (기준일자, 고객번호) )
*  DBMS   : PostgreSQL (ANSI SQL 기반) / 로컬 PostgreSQL에서 생성 및 검증 완료
*  파라미터 : :기준변수일자 - VARCHAR(8) ('YYYYMMDD')
*
*  선행 의존 마트 ( 기준변수일자로 먼저 적재 후  )
*  일별계좌잔액       : 일자별 계좌 잔액 마트  → 당월 평잔 활용
*  계좌연속거래마스터  : 계좌별 연속거래 마트   → 연속거래 활용
*
*  적재 : 기준일자 재적재 시 중복 방지를 위해 DELETE 후 INSERT
*
*  DELETE FROM 고객별상품실적현황 WHERE 기준일자 = :기준변수일자;
*  INSERT INTO 고객별상품실적현황
*
*  공통규칙 : 당일 배치 기준 정상('01') 고객 · 계좌 사용, 기준일자 이후 신규 계좌 · 카드 제외
*                과거 기준일자 재적재 시에는 원천을 원장 스냅샷 (2.5) 으로 교체
*
* ========================================================================== */

DELETE FROM 고객별상품실적현황
 WHERE 기준일자 = :기준변수일자
;

INSERT INTO 고객별상품실적현황
(
  기준일자
, 고객번호
, 고객유형코드
, 고객상태코드
, 개인법인구분코드
, 성별코드
, 생년월일
, 연령
, 연령대
, 직업구분코드
, 고객신규일자
, 전체상품가입순서
, 수신_보유여부
, 수신_정상계좌수
, 수신_최초가입일자
, 수신_최종가입일자
, 수신_가입순번
, 수신_보통예금_보유여부
, 수신_정기적금_보유여부
, 수신_정기예금_보유여부
, 수신_입출금통장_보유여부
, 수신_주택청약저축_보유여부
, 수신_개인IRP_보유여부
, 수신_10년적금_보유여부
, 수신_자유적금_보유여부
, 수신_총잔액
, 수신_당월평균잔액
, 수신_최대연속거래일수
, 수신_최대연속거래여부
, 여신_보유여부
, 여신_정상계좌수
, 여신_최초가입일자
, 여신_최종가입일자
, 여신_가입순번
, 여신_마이너스통장_보유여부
, 여신_신용대출_보유여부
, 여신_중저신용대출_보유여부
, 여신_전월세보증금대출_보유여부
, 여신_주택담보대출_보유여부
, 여신_총잔액
, 여신_당월평균잔액
, 여신_최대연속거래일수
, 여신_최대연속거래여부
, 카드_보유여부
, 카드_정상카드수
, 개인카드_보유여부
, 법인카드_보유여부
, 체크카드_보유여부
, 신용카드_보유여부
, 카드_최초발급일자
, 카드_최종발급일자
, 카드_가입순번
, 카드_사용여부
, 카드_당월사용금액
, 카드_당월이용건수
, 카드_현금_이용여부
, 카드_일시불_이용여부
, 카드_할부_이용여부
, 서비스_이용여부
, 서비스_내신용정보_이용여부
, 서비스_개인IRP_이용여부
, 서비스_해외송금_이용여부
, 서비스_타사계좌연결_이용여부
, 서비스_자동이체_이용여부
, 서비스_최초사용일자
, 서비스_최종사용일자
, 상품보유수
, 수신만보유_여부
, 여신만보유_여부
, 카드만보유_여부
, 수신여신보유_여부
, 수신카드보유_여부
, 여신카드보유_여부
, 수신여신카드보유_여부
, 적재일시
)

----------------------------------------------------------------
-- 1. 고객 기본 ( 정상 )
----------------------------------------------------------------
WITH 고객기본 AS (

SELECT 고객번호
     , 고객유형코드
     , 고객상태코드
     , 개인법인구분코드
     , 성별코드
     , 생년월일

     /* 만 나이 */
     , CAST( SUBSTRING( :기준변수일자, 1, 4 ) AS INTEGER )
       - CAST( SUBSTRING( 생년월일, 1, 4 ) AS INTEGER )
       - CASE WHEN SUBSTRING ( :기준변수일자, 5, 4 ) < SUBSTRING( 생년월일, 5, 4 )  THEN 1
              ELSE 0
         END   AS 연령

     , 직업구분코드
     , 고객신규일자
  FROM 고객
 WHERE 고객상태코드 = '01'

)

----------------------------------------------------------------
-- 2. 상품 가입 순서 구하기
----------------------------------------------------------------
, 계좌신규가입기본 AS (

SELECT 고객번호
     , '수신'   AS 상품구분
     , MIN(신규일자 || 신규시각) AS 신규가입일시
  FROM 수신계좌
 WHERE 수신계좌상태코드 = '01'
   AND 신규일자 <= :기준변수일자          /* 기준일자 이후 신규 제외 */
 GROUP BY 고객번호

UNION ALL

SELECT 고객번호
     , '여신'   AS 상품구분
     , MIN(신규일자 || 신규시각) AS 신규가입일시
  FROM 여신계좌
 WHERE 여신계좌상태코드 = '01'
   AND 신규일자 <= :기준변수일자          /* 기준일자 이후 신규 제외 */
 GROUP BY 고객번호

UNION ALL

SELECT 고객번호
     , '카드'   AS 상품구분
     , MIN(신규일자 || 신규시각) AS 신규가입일시
  FROM 카드
 WHERE 카드상태코드 = '01'
   AND 신규일자 <= :기준변수일자          /* 기준일자 이후 신규 제외 */
 GROUP BY 고객번호

)

, 상품가입기본 AS (

SELECT 고객번호
     , 상품구분
     , 신규가입일시
     , DENSE_RANK() OVER ( PARTITION BY 고객번호 ORDER BY 신규가입일시 ) AS 상품가입순번
  FROM 계좌신규가입기본

)

, 가입상품순번 AS (

SELECT 고객번호
     , MAX(CASE WHEN 상품구분 = '수신' THEN 상품가입순번 END) AS 수신_가입순번
     , MAX(CASE WHEN 상품구분 = '여신' THEN 상품가입순번 END) AS 여신_가입순번
     , MAX(CASE WHEN 상품구분 = '카드' THEN 상품가입순번 END) AS 카드_가입순번
  FROM 상품가입기본
 GROUP BY 고객번호

)

----------------------------------------------------------------
-- 3. 최초 상품 가입 순서 구하기
----------------------------------------------------------------
, 동일상품순번 AS (

SELECT 고객번호
     , 신규가입일시
     , STRING_AGG( 상품구분 , '='  ORDER BY 상품구분 )  AS 동일상품명
  FROM 계좌신규가입기본
 GROUP BY 고객번호
        , 신규가입일시

)

, 상품가입순서기본 AS (

SELECT 고객번호
    ,  STRING_AGG( 동일상품명 , '->'  ORDER BY 신규가입일시 )  AS 상품가입순서명
  FROM 동일상품순번
 GROUP BY 고객번호

)

----------------------------------------------------------------
-- 4. 수신계좌 집계
----------------------------------------------------------------
, 집계수신계좌 AS (

SELECT DPA.고객번호
     , COUNT(DPA.계약번호)     AS 수신_정상계좌수
     , 'Y'                    AS 수신_보유여부
     , MIN(DPA.신규일자)       AS 수신_최초가입일자
     , MAX(DPA.신규일자)       AS 수신_최종가입일자
     , SUM(DPA.계좌잔액)       AS 수신_총잔액
     , MAX(CASE WHEN PRD.수신업무구분코드 = '001' THEN 'Y' ELSE 'N' END)   AS 수신_보통예금_보유여부
     , MAX(CASE WHEN PRD.수신업무구분코드 = '002' THEN 'Y' ELSE 'N' END)   AS 수신_정기적금_보유여부
     , MAX(CASE WHEN PRD.수신업무구분코드 = '003' THEN 'Y' ELSE 'N' END)   AS 수신_정기예금_보유여부
     , MAX(CASE WHEN PRD.수신계좌과목코드 = 'PROD_CD-001' THEN 'Y' ELSE 'N' END)   AS 수신_입출금통장_보유여부
     , MAX(CASE WHEN PRD.수신계좌과목코드 = 'PROD_CD-002' THEN 'Y' ELSE 'N' END)   AS 수신_주택청약저축_보유여부
     , MAX(CASE WHEN PRD.수신계좌과목코드 = 'PROD_CD-003' THEN 'Y' ELSE 'N' END)   AS 수신_개인IRP_보유여부
     , MAX(CASE WHEN PRD.수신계좌과목코드 = 'PROD_CD-004' THEN 'Y' ELSE 'N' END)   AS 수신_10년적금_보유여부
     , MAX(CASE WHEN PRD.수신계좌과목코드 = 'PROD_CD-005' THEN 'Y' ELSE 'N' END)   AS 수신_자유적금_보유여부
  FROM 수신계좌 DPA
  LEFT OUTER JOIN 상품코드 PRD
    ON DPA.상품코드 = PRD.상품코드
 WHERE DPA.수신계좌상태코드 = '01'
   AND DPA.신규일자 <= :기준변수일자      /* 기준일자 이후 신규 제외 */
 GROUP BY DPA.고객번호

)

----------------------------------------------------------------
-- 5. 여신계좌 집계
----------------------------------------------------------------
, 집계여신계좌 AS (

SELECT LNA.고객번호
     , COUNT(LNA.계약번호)   AS 여신_정상계좌수
     , 'Y'                 AS 여신_보유여부
     , MIN(LNA.신규일자)     AS 여신_최초가입일자
     , MAX(LNA.신규일자)     AS 여신_최종가입일자
     , SUM(LNA.계좌잔액)     AS 여신_총잔액
     , MAX(CASE WHEN PRD.여신상품군 = '00001' THEN 'Y' ELSE 'N' END)   AS 여신_마이너스통장_보유여부
     , MAX(CASE WHEN PRD.여신상품군 = '00002' THEN 'Y' ELSE 'N' END)   AS 여신_신용대출_보유여부
     , MAX(CASE WHEN PRD.여신상품군 = '00003' THEN 'Y' ELSE 'N' END)   AS 여신_중저신용대출_보유여부
     , MAX(CASE WHEN PRD.여신상품군 = '00004' THEN 'Y' ELSE 'N' END)   AS 여신_전월세보증금대출_보유여부
     , MAX(CASE WHEN PRD.여신상품군 = '00005' THEN 'Y' ELSE 'N' END)   AS 여신_주택담보대출_보유여부
  FROM 여신계좌 LNA
  LEFT OUTER JOIN 상품코드 PRD
    ON LNA.상품코드 = PRD.상품코드
 WHERE LNA.여신계좌상태코드 = '01'
   AND DPA.신규일자 <= :기준변수일자      /* 기준일자 이후 신규 제외 */
 GROUP BY LNA.고객번호

)

----------------------------------------------------------------
-- 6. 카드 기본
----------------------------------------------------------------
, 카드기본 AS (

SELECT 고객번호
     , COUNT(카드번호)    AS 카드_정상카드수
     , 'Y'              AS 카드_보유여부
     , MIN(신규일자)      AS 카드_최초발급일자
     , MAX(신규일자)      AS 카드_최종발급일자
     , MAX( CASE WHEN 개인법인구분코드 = '01'  THEN 'Y' ELSE 'N' END )   AS 개인카드_보유여부
     , MAX( CASE WHEN 개인법인구분코드 = '02'  THEN 'Y' ELSE 'N' END )   AS 법인카드_보유여부
     , MAX( CASE WHEN 카드종류코드 = '01'  THEN 'Y' ELSE 'N' END )   AS 체크카드_보유여부
     , MAX( CASE WHEN 카드종류코드 = '02'  THEN 'Y' ELSE 'N' END )   AS 신용카드_보유여부
  FROM 카드
 WHERE 카드상태코드 = '01'
   AND DPA.신규일자 <= :기준변수일자      /* 기준일자 이후 신규 제외 */
 GROUP BY 고객번호

)

----------------------------------------------------------------
-- 7. 카드 당월 이용 집계
----------------------------------------------------------------
, 카드당월집계 AS (

SELECT CAD.고객번호
     , 'Y'               AS 카드_사용여부

     , SUM(CAL.사용금액)   AS 카드_당월사용금액
     , COUNT(*)          AS 카드_당월이용건수

     , MAX(CASE WHEN CAL.매입거래구분코드 = '01' THEN 'Y' ELSE 'N' END)   AS 카드_현금_이용여부
     , MAX(CASE WHEN CAL.매입거래구분코드 = '02' THEN 'Y' ELSE 'N' END)   AS 카드_일시불_이용여부
     , MAX(CASE WHEN CAL.매입거래구분코드 = '03' THEN 'Y' ELSE 'N' END)   AS 카드_할부_이용여부

  FROM 카드사용내역 CAL
 INNER JOIN 카드 CAD
    ON CAL.카드번호 = CAD.카드번호
   AND CAD.카드상태코드 = '01'   /* 01 : 정상 */
 WHERE CAL.매입상태코드 = '01'   /* 01 : 정상 */
   AND CAL.매입일자 BETWEEN SUBSTRING(:기준변수일자, 1,6) || '01' AND :기준변수일자
 GROUP BY CAD.고객번호

)

----------------------------------------------------------------
-- 8. 고객 서비스 명세 집계
----------------------------------------------------------------
, 집계서비스 AS (

SELECT 고객번호
     , 'Y'               AS 서비스_이용여부
     , MAX(CASE WHEN 서비스코드 = '00001' THEN 'Y' ELSE 'N' END) AS 서비스_내신용정보_이용여부
     , MAX(CASE WHEN 서비스코드 = '00002' THEN 'Y' ELSE 'N' END) AS 서비스_개인IRP_이용여부
     , MAX(CASE WHEN 서비스코드 = '00003' THEN 'Y' ELSE 'N' END) AS 서비스_해외송금_이용여부
     , MAX(CASE WHEN 서비스코드 = '00004' THEN 'Y' ELSE 'N' END) AS 서비스_타사계좌연결_이용여부
     , MAX(CASE WHEN 서비스코드 = '00005' THEN 'Y' ELSE 'N' END) AS 서비스_자동이체_이용여부

     , MIN(서비스최초사용일자)     AS 서비스_최초사용일자
     , MAX(서비스최종사용일자)     AS 서비스_최종사용일자

  FROM 고객서비스명세

 WHERE 서비스상태코드 = '01'
 GROUP BY 고객번호

)

----------------------------------------------------------------
-- 9. 고객별 여신/수신 당월 평균 잔액  - 일별계좌잔액 마트 테이블 활용
----------------------------------------------------------------
, 고객별일별잔액 AS (

SELECT 수신여신구분코드
     , 고객번호
     , 기준일자
     , SUM(일마감잔액)  AS 고객일별잔액합계
  FROM 일별계좌잔액
 WHERE 기준일자 BETWEEN SUBSTRING( :기준변수일자, 1,6 ) || '01' AND :기준변수일자
 GROUP BY 수신여신구분코드
        , 고객번호
        , 기준일자

)
, 고객별당월평균잔액 AS (

SELECT 수신여신구분코드
     , 고객번호
     , ROUND( AVG( 고객일별잔액합계 ) , 2 )  AS 고객당월평균잔액
  FROM 고객별일별잔액
 GROUP BY 수신여신구분코드
        , 고객번호

)

, 고객상품당월평잔 AS (

SELECT 고객번호
     , MAX(CASE WHEN 수신여신구분코드 = '01' THEN 고객당월평균잔액 ELSE 0 END) AS 수신_당월평균잔액
     , MAX(CASE WHEN 수신여신구분코드 = '02' THEN 고객당월평균잔액 ELSE 0 END) AS 여신_당월평균잔액
  FROM 고객별당월평균잔액
 GROUP BY 고객번호

)

----------------------------------------------------------------
-- 10. 고객별 여신/수신 연속 거래 여부
----------------------------------------------------------------
, 고객연속거래 AS (

SELECT 고객번호
     , MAX(CASE WHEN 수신여신구분코드 = '01' THEN 연속거래일수 END) AS 수신_최대연속거래일수
     , MAX(CASE WHEN 수신여신구분코드 = '01' THEN 연속거래여부 END) AS 수신_최대연속거래여부
     , MAX(CASE WHEN 수신여신구분코드 = '02' THEN 연속거래일수 END) AS 여신_최대연속거래일수
     , MAX(CASE WHEN 수신여신구분코드 = '02' THEN 연속거래여부 END) AS 여신_최대연속거래여부
  FROM 계좌연속거래마스터
 WHERE 기준일자 = :기준변수일자          -- 같은 스냅샷
 GROUP BY 고객번호

)

----------------------------------------------------------------
-- 상품 실적 현황 마트 추출
----------------------------------------------------------------

SELECT :기준변수일자  AS 기준일자
     , CUB.고객번호
     , CUB.고객유형코드
     , CUB.고객상태코드
     , CUB.개인법인구분코드
     , CUB.성별코드
     , CUB.생년월일
     , CUB.연령

    /* 연령대 */
     , CASE WHEN CUB.연령 < 10 THEN '10세 미만'
            WHEN CUB.연령 BETWEEN 10 AND 19 THEN '10대'
            WHEN CUB.연령 BETWEEN 20 AND 29 THEN '20대'
            WHEN CUB.연령 BETWEEN 30 AND 39 THEN '30대'
            WHEN CUB.연령 BETWEEN 40 AND 49 THEN '40대'
            WHEN CUB.연령 BETWEEN 50 AND 59 THEN '50대'
            WHEN CUB.연령 BETWEEN 60 AND 69 THEN '60대'
            ELSE '70세 이상'
       END   AS 연령대

     , CUB.직업구분코드
     , CUB.고객신규일자
     , PRN.상품가입순서명  AS 전체상품가입순서

     /* 수신 */
     , COALESCE( ADP.수신_보유여부,          'N' )      AS 수신_보유여부
     , COALESCE( ADP.수신_정상계좌수,         0 )       AS 수신_정상계좌수
     , ADP.수신_최초가입일자
     , ADP.수신_최종가입일자
     , PRW.수신_가입순번

     , COALESCE(ADP.수신_보통예금_보유여부, 'N' )      AS 수신_보통예금_보유여부
     , COALESCE(ADP.수신_정기적금_보유여부, 'N' )      AS 수신_정기적금_보유여부
     , COALESCE(ADP.수신_정기예금_보유여부, 'N' )      AS 수신_정기예금_보유여부

     , COALESCE( ADP.수신_입출금통장_보유여부,  'N' )     AS 수신_입출금통장_보유여부
     , COALESCE( ADP.수신_주택청약저축_보유여부, 'N' )      AS 수신_주택청약저축_보유여부
     , COALESCE( ADP.수신_개인IRP_보유여부,   'N' )     AS 수신_개인IRP_보유여부
     , COALESCE( ADP.수신_10년적금_보유여부,  'N' )      AS 수신_10년적금_보유여부
     , COALESCE( ADP.수신_자유적금_보유여부,   'N' )     AS 수신_자유적금_보유여부

     , COALESCE( ADP.수신_총잔액,             0 )      AS 수신_총잔액
     , MAV.수신_당월평균잔액
     , COALESCE( CON.수신_최대연속거래일수, 0 )   AS 수신_최대연속거래일수
     , COALESCE( CON.수신_최대연속거래여부, 'N' ) AS 수신_최대연속거래여부

     /* 여신 */
     , COALESCE(ADL.여신_보유여부,          'N') AS 여신_보유여부
     , COALESCE(ADL.여신_정상계좌수,         0)  AS 여신_정상계좌수
     , ADL.여신_최초가입일자
     , ADL.여신_최종가입일자
     , PRW.여신_가입순번

     , COALESCE(ADL.여신_마이너스통장_보유여부,       'N') AS 여신_마이너스통장_보유여부
     , COALESCE(ADL.여신_신용대출_보유여부,         'N') AS 여신_신용대출_보유여부
     , COALESCE(ADL.여신_중저신용대출_보유여부,     'N') AS 여신_중저신용대출_보유여부
     , COALESCE(ADL.여신_전월세보증금대출_보유여부, 'N') AS 여신_전월세보증금대출_보유여부
     , COALESCE(ADL.여신_주택담보대출_보유여부,     'N') AS 여신_주택담보대출_보유여부

     , COALESCE(ADL.여신_총잔액,                    0)   AS 여신_총잔액
     , MAV.여신_당월평균잔액
     , COALESCE( CON.여신_최대연속거래일수, 0 )   AS 여신_최대연속거래일수
     , COALESCE( CON.여신_최대연속거래여부, 'N' ) AS 여신_최대연속거래여부

    /* 카드 */
     , COALESCE(CAB.카드_보유여부,     'N')      AS 카드_보유여부
     , COALESCE(CAB.카드_정상카드수,    0)       AS 카드_정상카드수

     , COALESCE(CAB.개인카드_보유여부,  'N')     AS 개인카드_보유여부
     , COALESCE(CAB.법인카드_보유여부,  'N')     AS 법인카드_보유여부

     , COALESCE(CAB.체크카드_보유여부,  'N')     AS 체크카드_보유여부
     , COALESCE(CAB.신용카드_보유여부,  'N')     AS 신용카드_보유여부

     , CAB.카드_최초발급일자
     , CAB.카드_최종발급일자
     , PRW.카드_가입순번

     , COALESCE( CAM.카드_사용여부,     'N' )       AS 카드_사용여부
     , COALESCE( CAM.카드_당월사용금액,    0 )       AS 카드_당월사용금액
     , COALESCE( CAM.카드_당월이용건수,    0 )       AS 카드_당월이용건수

     , COALESCE( CAM.카드_현금_이용여부, 'N' )      AS 카드_현금_이용여부
     , COALESCE( CAM.카드_일시불_이용여부, 'N' )     AS 카드_일시불_이용여부
     , COALESCE( CAM.카드_할부_이용여부, 'N' )      AS 카드_할부_이용여부

     /* 서비스 */

     , COALESCE( SVB.서비스_이용여부,     'N' )         AS 서비스_이용여부
     , COALESCE( SVB.서비스_내신용정보_이용여부, 'N' )    AS 서비스_내신용정보_이용여부
     , COALESCE( SVB.서비스_개인IRP_이용여부, 'N' )      AS 서비스_개인IRP_이용여부
     , COALESCE( SVB.서비스_해외송금_이용여부, 'N' )      AS 서비스_해외송금_이용여부
     , COALESCE( SVB.서비스_타사계좌연결_이용여부, 'N' )      AS 서비스_타사계좌연결_이용여부
     , COALESCE( SVB.서비스_자동이체_이용여부, 'N' )        AS 서비스_자동이체_이용여부
     , SVB.서비스_최초사용일자
     , SVB.서비스_최종사용일자

     /* 상품 3종 보유수 ( 수신 + 여신 + 카드 ) */
     , ( CASE WHEN COALESCE( ADP.수신_보유여부 , 'N' ) ='Y' THEN 1 ELSE 0 END
         + CASE WHEN COALESCE( ADL.여신_보유여부 , 'N' ) ='Y' THEN 1 ELSE 0 END
         + CASE WHEN COALESCE( CAB.카드_보유여부 , 'N' ) ='Y' THEN 1 ELSE 0 END
       )   AS 상품보유수

    /* 상품 보유 여부 분석 */
     , CASE WHEN COALESCE( ADP.수신_보유여부 , 'N' ) = 'Y'
                 AND COALESCE( ADL.여신_보유여부 , 'N' ) = 'N'
                 AND COALESCE( CAB.카드_보유여부 , 'N' ) = 'N'
            THEN 'Y'
            ELSE 'N'
       END   AS 수신만보유_여부

     , CASE WHEN COALESCE( ADP.수신_보유여부 , 'N' ) = 'N'
                 AND COALESCE( ADL.여신_보유여부 , 'N' ) = 'Y'
                 AND COALESCE( CAB.카드_보유여부 , 'N' ) = 'N'
            THEN 'Y'
            ELSE 'N'
       END   AS 여신만보유_여부

     , CASE WHEN COALESCE( ADP.수신_보유여부 , 'N' ) = 'N'
                 AND COALESCE( ADL.여신_보유여부 , 'N' ) = 'N'
                 AND COALESCE( CAB.카드_보유여부 , 'N' ) = 'Y'
            THEN 'Y'
            ELSE 'N'
       END   AS 카드만보유_여부

     , CASE WHEN COALESCE( ADP.수신_보유여부 , 'N' ) = 'Y'
                 AND COALESCE( ADL.여신_보유여부 , 'N' ) = 'Y'
                 AND COALESCE( CAB.카드_보유여부 , 'N' ) = 'N'
            THEN 'Y'
            ELSE 'N'
       END   AS 수신여신보유_여부

     , CASE WHEN COALESCE( ADP.수신_보유여부 , 'N' ) = 'Y'
                 AND COALESCE( ADL.여신_보유여부 , 'N' ) = 'N'
                 AND COALESCE( CAB.카드_보유여부 , 'N' ) = 'Y'
            THEN 'Y'
            ELSE 'N'
       END   AS 수신카드보유_여부

     , CASE WHEN COALESCE( ADP.수신_보유여부 , 'N' ) = 'N'
                 AND COALESCE( ADL.여신_보유여부 , 'N' ) = 'Y'
                 AND COALESCE( CAB.카드_보유여부 , 'N' ) = 'Y'
            THEN 'Y'
            ELSE 'N'
       END   AS 여신카드보유_여부

     , CASE WHEN COALESCE( ADP.수신_보유여부 , 'N' ) = 'Y'
                 AND COALESCE( ADL.여신_보유여부 , 'N' ) = 'Y'
                 AND COALESCE( CAB.카드_보유여부 , 'N' ) = 'Y'
            THEN 'Y'
            ELSE 'N'
       END   AS 수신여신카드보유_여부

      , CURRENT_TIMESTAMP  AS 적재일시

  FROM 고객기본 CUB
  LEFT OUTER JOIN 가입상품순번 PRW
    ON CUB.고객번호 = PRW.고객번호
  LEFT OUTER JOIN 상품가입순서기본 PRN
    ON CUB.고객번호 = PRN.고객번호
  LEFT OUTER JOIN 집계수신계좌 ADP
    ON CUB.고객번호 = ADP.고객번호
  LEFT OUTER JOIN 집계여신계좌 ADL
    ON CUB.고객번호 = ADL.고객번호
  LEFT OUTER JOIN 카드기본 CAB
    ON CUB.고객번호 = CAB.고객번호
  LEFT OUTER JOIN 카드당월집계 CAM
    ON CUB.고객번호 = CAM.고객번호
  LEFT OUTER JOIN 집계서비스 SVB
    ON CUB.고객번호 = SVB.고객번호
  LEFT OUTER JOIN 고객상품당월평잔 MAV
    ON CUB.고객번호 = MAV.고객번호
  LEFT OUTER JOIN 고객연속거래 CON
    ON CUB.고객번호 = CON.고객번호
;
