/* 수신 보유 기준 타상품 전환율 */

SELECT COUNT(*)                                            AS 전체고객수
     , SUM(CASE WHEN 수신_보유여부 = 'Y' THEN 1 ELSE 0 END)   AS 수신보유고객수
     , SUM(CASE WHEN 여신_보유여부 = 'Y' THEN 1 ELSE 0 END)   AS 여신보유고객수
     , SUM(CASE WHEN 카드_보유여부 = 'Y' THEN 1 ELSE 0 END)   AS 카드보유고객수

     -- 진입상품(수신) 보유 고객 기준 타상품 전환율 (%)
     , ROUND( 100.0 * SUM(CASE WHEN 수신_보유여부 = 'Y' AND 여신_보유여부 = 'Y' THEN 1 ELSE 0 END)
                    / NULLIF(SUM(CASE WHEN 수신_보유여부 = 'Y' THEN 1 ELSE 0 END), 0), 2)  AS 수신_여신_전환율
     , ROUND( 100.0 * SUM(CASE WHEN 수신_보유여부 = 'Y' AND 카드_보유여부 = 'Y' THEN 1 ELSE 0 END)
                    / NULLIF(SUM(CASE WHEN 수신_보유여부 = 'Y' THEN 1 ELSE 0 END), 0), 2)  AS 수신_카드_전환율
     , ROUND( 100.0 * SUM(CASE WHEN 수신_보유여부 = 'Y' AND 여신_보유여부 = 'Y' AND 카드_보유여부 = 'Y' THEN 1 ELSE 0 END)
                    / NULLIF(SUM(CASE WHEN 수신_보유여부 = 'Y' THEN 1 ELSE 0 END), 0), 2)  AS 수신여신카드_전환율

     -- 보유 상품 수 분포 (2종 이상)
     , SUM(CASE WHEN 상품보유수 = 1 THEN 1 ELSE 0 END)        AS 단일상품_고객수
     , SUM(CASE WHEN 상품보유수 = 2 THEN 1 ELSE 0 END)        AS 이종보유_고객수
     , SUM(CASE WHEN 상품보유수 = 3 THEN 1 ELSE 0 END)        AS 삼종보유_고객수

     , ROUND( 100.0 * SUM(CASE WHEN 상품보유수 >= 2 THEN 1 ELSE 0 END)
                    / NULLIF(COUNT(*), 0), 2)                AS 전환율

  FROM 고객별상품실적현황
 WHERE 기준일자 = :기준변수일자
;

/* 연령대별 상품 전환율 */

SELECT 연령대
     , COUNT(*)                                            AS 고객수
     , SUM(CASE WHEN 수신_보유여부 = 'Y' THEN 1 ELSE 0 END)   AS 수신보유고객수

     , ROUND( 100.0 * SUM(CASE WHEN 수신_보유여부 = 'Y' AND 여신_보유여부 = 'Y' THEN 1 ELSE 0 END)
                    / NULLIF(SUM(CASE WHEN 수신_보유여부 = 'Y' THEN 1 ELSE 0 END), 0), 2)  AS 수신_여신_전환율
     , ROUND( 100.0 * SUM(CASE WHEN 수신_보유여부 = 'Y' AND 카드_보유여부 = 'Y' THEN 1 ELSE 0 END)
                    / NULLIF(SUM(CASE WHEN 수신_보유여부 = 'Y' THEN 1 ELSE 0 END), 0), 2)  AS 수신_카드_전환율
     , ROUND( 100.0 * SUM(CASE WHEN 수신_보유여부 = 'Y' AND 여신_보유여부 = 'Y' AND 카드_보유여부 = 'Y' THEN 1 ELSE 0 END)
                    / NULLIF(SUM(CASE WHEN 수신_보유여부 = 'Y' THEN 1 ELSE 0 END), 0), 2)  AS 수신여신카드_전환율

     , ROUND( 100.0 * SUM(CASE WHEN 상품보유수 >= 2 THEN 1 ELSE 0 END)
                    / NULLIF(COUNT(*), 0), 2)                AS 전환율
  FROM 고객별상품실적현황
 WHERE 기준일자 = :기준변수일자
 GROUP BY 연령대
 ORDER BY 연령대
;
