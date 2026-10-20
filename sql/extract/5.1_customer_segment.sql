/* 성별, 연령대별 고객수 및 평균 계좌수 추출 */

SELECT 기준일자
     , 성별코드
     , 연령대
     , COUNT(*)                                                      AS 고객수
     , SUM( CASE WHEN 수신_보유여부 = 'Y' THEN 1 ELSE 0 END )           AS 수신보유고객수
     , SUM( CASE WHEN 여신_보유여부 = 'Y' THEN 1 ELSE 0 END )           AS 여신보유고객수
     , SUM( CASE WHEN 카드_보유여부 = 'Y' THEN 1 ELSE 0 END )           AS 카드보유고객수
     , SUM( CASE WHEN 수신_개인IRP_보유여부 = 'Y' THEN 1 ELSE 0 END )   AS 수신_개인IRP_보유고객수
     , SUM( CASE WHEN 여신_마이너스통장_보유여부 = 'Y' THEN 1 ELSE 0 END )  AS 여신_마이너스통장_보유고객수
     , SUM( CASE WHEN 신용카드_보유여부 = 'Y' THEN 1 ELSE 0 END )        AS 카드_신용카드_보유고객수
     , SUM( CASE WHEN 서비스_자동이체_이용여부 = 'Y' THEN 1 ELSE 0 END )     AS 서비스_자동이체_이용고객수
     , ROUND( AVG(수신_정상계좌수), 2 )                                  AS 평균_수신_정상계좌수
     , ROUND( AVG(여신_정상계좌수), 2 )                                  AS 평균_여신_정상계좌수
     , ROUND( AVG(상품보유수), 2 )                                         AS 평균_상품_보유수
  FROM 고객별상품실적현황
 WHERE 기준일자 = :기준변수일자
 GROUP BY 기준일자
        , 성별코드
        , 연령대
 ORDER BY 기준일자
        , 성별코드
        , 연령대
;

/* 특정 세그먼트 추출 - 30대, 수신만 보유한 고객의 패턴 확인 - 상품 타깃 */

SELECT 기준일자
     , 성별코드
     , 연령대
     , 직업구분코드
     , SUM( CASE WHEN 수신_보통예금_보유여부 = 'Y' THEN 1 ELSE 0 END )   AS 수신_보통예금_보유고객수
     , SUM( CASE WHEN 수신_정기적금_보유여부 = 'Y' THEN 1 ELSE 0 END )   AS 수신_정기적금_보유고객수
     , SUM( CASE WHEN 수신_정기예금_보유여부 = 'Y' THEN 1 ELSE 0 END )   AS 수신_정기예금_보유고객수
     , ROUND( AVG(수신_당월평균잔액), 2 )                               AS 당월_평균_수신잔액
  FROM 고객별상품실적현황
 WHERE 기준일자 = :기준변수일자
   AND 연령대 = '30대'         /* 30대 */
   AND 개인법인구분코드 = '01'   /* 개인고객 */
   AND 수신만보유_여부 = 'Y'     /* 수신만 보유 */
 GROUP BY 기준일자
        , 성별코드
        , 연령대
        , 직업구분코드
 ORDER BY 기준일자
        , 성별코드
        , 연령대
        , 직업구분코드
;
