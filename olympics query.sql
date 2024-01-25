CREATE TABLE IF NOT EXISTS olympics_events (id INT, name VARCHAR, sex VARCHAR, age VARCHAR, height VARCHAR, weight VARCHAR, team VARCHAR, noc VARCHAR, games VARCHAR, YEAR INT, season VARCHAR, city VARCHAR, sport VARCHAR, event VARCHAR, medal VARCHAR);


CREATE TABLE IF NOT EXISTS olympics_events_noc_regions (noc VARCHAR, region VARCHAR, notes VARCHAR);


SELECT *
FROM olympics_events
LIMIT 10;


SELECT *
FROM olympics_events_noc_regions
LIMIT 10;

-- 1.How many olympics games have been held?

SELECT count(DISTINCT games)
FROM olympics_events;

-- 2.List down all Olympics games held so far.

SELECT DISTINCT YEAR,
	season,
	games
FROM olympics_events;

-- 3. Mention the total no of nations who participated in each olympics game?

SELECT DISTINCT games,
	count(DISTINCT noc) AS total_country
FROM olympics_events
GROUP BY games;

-- 4. Which year saw the highest and lowest no of countries participating in olympics?

WITH T1 AS ( -- games and region 
	SELECT games, olyp_evnt_reg.region
	FROM olympics_events AS olyp_evnt 
	INNER JOIN olympics_events_noc_regions AS olyp_evnt_reg ON olyp_evnt.noc = olyp_evnt_reg.noc 
	GROUP BY games, olyp_evnt_reg.region
),
T2 AS ( -- games and number of region participated with rank
	SELECT games, count(1) AS total_countries,
	RANK() OVER (ORDER BY COUNT(1) DESC) AS first_rank,
	RANK() OVER (ORDER BY COUNT(1) ASC) AS last_rank
	FROM T1 GROUP BY games
),
T3 AS ( -- concat games and number of reion particilated by rank
	SELECT games, first_rank, last_rank, CONCAT(STRING_AGG(games, ' '), ' - ', MAX(total_countries)) as country_participating
	FROM T2 
	WHERE first_rank = 1 or last_rank = 1
	GROUP BY games, first_rank, last_rank
)
SELECT -- Highest and Lowest rank with games
	MAX(CASE WHEN first_rank = 1 THEN country_participating END) AS highest,
	MAX(CASE WHEN last_rank = 1 THEN country_participating END) AS lowest
from T3;


-- 5. Which nation has participated in all of the olympic games?

WITH tot_games AS (
	SELECT
		COUNT(DISTINCT games) 
		AS total_games 
	FROM olympics_events
),
country_participated AS (
	SELECT noc_region.region AS country, COUNT(DISTINCT olyp_event.games) AS total_participated_games
	FROM olympics_events_noc_regions AS noc_region
	INNER JOIN olympics_events AS olyp_event 
	on noc_region.noc = olyp_event.noc
	GROUP BY noc_region.region
	ORDER BY total_participated_games
)

SELECT  cp.*
	FROM country_participated AS cp
	INNER JOIN tot_games AS tg 
	ON tg.total_games = cp.total_participated_games
	ORDER BY 1
;

-- 6. Identify the sport which was played in all summer olympics.

WITH t1 AS
	(SELECT count(DISTINCT games) AS total_summer_games
		FROM olympics_events
		WHERE season = 'Summer' ),
	t2 AS
	(SELECT DISTINCT sport,
			games
		FROM olympics_events
		WHERE season = 'Summer'
		ORDER BY games),
	t3 AS
	(SELECT sport,
			count(games) AS no_of_games
		FROM t2
		GROUP BY sport)
		
SELECT *
FROM t3
INNER JOIN t1 ON t3.no_of_games = t1.total_summer_games;

-- 7. Which Sports were just played only once in the olympics?

WITH T1 AS ( -- games and sport in olympic
	SELECT  games, sport
	FROM olympics_events GROUP BY games, sport
	),
	T2 AS ( -- sport and number of games attended in
		SELECT sport, COUNT(1) as no_of_games
		FROM T1 GROUP BY sport
	)
	
SELECT T2.*, T1.games FROM T2 
INNER JOIN T1 ON T1.sport = T2.sport
WHERE T2.no_of_games = 1
ORDER BY T1.sport

-- 8. Fetch the total no of sports played in each olympic games.

WITH t1 AS
	(SELECT games,
			sport
		FROM olympics_events
		GROUP BY games,
			sport
		ORDER BY games)
SELECT games,
	count(1) AS no_of_sport
FROM t1
GROUP BY games
ORDER BY no_of_sport DESC

-- 9. Fetch details of the oldest athletes to win a gold medal.
WITH athletes_info AS (
	SELECT name, sex, 
	cast( CASE WHEN age='NA' then '0' ELSE age END AS int) AS age,
	team,games,city,sport,event,medal
	FROM olympics_events
),
ranking AS (
	SELECT *, RANK() OVER(ORDER BY age DESC) AS rnk
	FROM athletes_info 
	WHERE medal = 'Gold'
)

SELECT * FROM ranking WHERE rnk = 1;

-- 10. Find the Ratio of male and female athletes participated in all olympic games.
WITH T1 AS (
	SELECT sex, count(sex) as count
	FROM olympics_events
	GROUP BY sex
),
T2 AS (
	SELECT *, ROW_NUMBER() OVER (ORDER BY count) AS rnk
	FROM T1
),
min_cnt AS (
	SELECT count FROM T2 WHERE rnk=1
),
max_cnt AS (
	SELECT count FROM T2 WHERE rnk=2
)

SELECT CONCAT('1 : ', ROUND(max_cnt.count::decimal/min_cnt.count, 2)) AS ratio FROM min_cnt, max_cnt;


-- 11. Fetch the top 5 athletes who have won the most gold medals.
WITH t1 AS
	(SELECT name,
			team,
			count(medal) AS total_gold_medal
		FROM olympics_events
		WHERE medal = 'Gold'
		GROUP BY name,
			team),
	t2 AS
	(SELECT *,
			dense_rank() OVER (
						ORDER BY total_gold_medal DESC) AS rank
		FROM t1)
SELECT name,
	team,
	total_gold_medal
FROM t2
WHERE rank <= 5;


-- 12. Fetch the top 5 athletes who have won the most medals (gold/silver/bronze).

WITH T1 AS (
	SELECT name, team, count(medal) AS total_medals FROM olympics_events 
		WHERE medal IN('Gold', 'Silver','Bronze')
	GROUP BY name, team
),
T2 AS (
	SELECT *, DENSE_RANK() OVER (ORDER BY total_medals DESC) AS rnk
	FROM T1
)

SELECT name, team, total_medals FROM T2
WHERE rnk <= 5;

-- 13. Fetch the top 5 most successful countries in olympics. Success is defined by no of medals won.

WITH T1 AS ( -- region and medal

	SELECT region, medal
	FROM olympics_events AS olyp_evnt
	INNER JOIN olympics_events_noc_regions AS noc_region
	ON olyp_evnt.noc = noc_region.noc
),
T2 AS ( -- region and total medals
	SELECT region, count(medal) as total_medals
	FROM T1 
	WHERE medal IN('Gold', 'Silver','Bronze')
	GROUP BY region
),
T3 AS (
	SELECT *, DENSE_RANK() OVER(ORDER BY total_medals DESC) AS rnk
	FROM T2
)

SELECT * FROM T3
WHERE rnk <= 5;

-- 14. List down total gold, silver and bronze medals won by each country.

WITH T1 AS (
	SELECT region AS country, medal, count(1) AS total_medals 
	FROM olympics_events AS olyp_event
	INNER JOIN olympics_events_noc_regions AS noc_region
	ON olyp_event.noc = noc_region.noc
	WHERE medal <> 'NA'
	GROUP BY region, medal
	ORDER BY region, medal
)

-- USE CROSSTAB FOR PIVOT TABLE 
-- CREATE EXTENSION TABLEFUNC;

SELECT country,
	COALESCE(gold, 0) AS gold,
	COALESCE(silver, 0) AS silver,
	COALESCE(bronze, 0) AS bronze
		FROM CROSSTAB('SELECT region AS country, medal, count(1) AS total_medals 
		FROM olympics_events AS olyp_event
		INNER JOIN olympics_events_noc_regions AS noc_region
		ON olyp_event.noc = noc_region.noc
		WHERE medal <> ''NA''
		GROUP BY region, medal
		ORDER BY region, medal',
				 'values (''Bronze''), (''Gold''), (''Silver'') ')
	AS RESULT (country varchar, bronze bigint, gold bigint, silver bigint)
ORDER BY gold DESC, silver DESC, bronze DESC


-- ALTERNATIVELY--

WITH t1 AS
	(SELECT ohnr.region,
			oh.medal,
			count(*) total_medals
		FROM olympics_events oh
		JOIN olympics_events_noc_regions ohnr ON ohnr.noc = oh.noc
		WHERE oh.medal IN ('Gold','Silver','Bronze')
		GROUP BY ohnr.region,
			oh.medal
		ORDER BY ohnr.region ASC)
SELECT region,
	sum(CASE WHEN medal = 'Gold' THEN total_medals ELSE 0 END) gold,
	sum(CASE WHEN medal = 'Silver' THEN total_medals ELSE 0 END) silver,
	sum(CASE WHEN medal = 'Bronze' THEN total_medals ELSE 0 END) bronze
FROM t1
GROUP BY region
ORDER BY gold DESC,
	silver DESC,
	bronze DESC;


-- 15. List down total gold, silver and bronze medals won by each country corresponding to each olympic games.
WITH T1 AS (
	SELECT games, region, medal, count(*) AS total_medals
	FROM olympics_events AS olyp_event
	INNER JOIN olympics_events_noc_regions AS noc_region 
	ON olyp_event.NOC = noc_region.NOC
	WHERE medal <> 'NA'
	GROUP BY games, region, medal
	ORDER BY games ASC
)

SELECT games, region AS country,
SUM(CASE WHEN medal='Gold' THEN total_medals ELSE 0 END) AS gold,
SUM(CASE WHEN medal='Silver' THEN total_medals ELSE 0 END) AS silver,
SUM(CASE WHEN medal='Bronze' THEN total_medals ELSE 0 END) AS bronze
FROM T1
GROUP BY games,region
ORDER BY games ASC, region ASC, gold DESC, silver DESC, bronze DESC;


-- 16. Identify which country won the most gold, most silver and most bronze medals in each olympic games.

WITH T1 AS (
	SELECT SUBSTRING(country, 1, POSITION(' - ' IN country) -1) AS games,
	SUBSTRING(country, POSITION(' - ' IN country) + 3) AS country,
	COALESCE(gold, 0) AS gold,
	COALESCE(silver, 0) AS silver,
	COALESCE(bronze, 0) AS bronze
		FROM CROSSTAB('SELECT CONCAT(games, '' - '', noc_region.region) as country, medal, count(1) AS total_medals 
		FROM olympics_events AS olyp_event
		INNER JOIN olympics_events_noc_regions AS noc_region
		ON olyp_event.noc = noc_region.noc
		WHERE medal <> ''NA''
		GROUP BY games, region, medal
		ORDER BY games, region, medal',
				 'values (''Bronze''), (''Gold''), (''Silver'') ')
	AS RESULT (country varchar, bronze bigint, gold bigint, silver bigint)
ORDER BY games
)
SELECT 
	DISTINCT games,
	CONCAT(FIRST_VALUE(country) OVER(PARTITION BY games ORDER BY gold DESC),  ' - ', 
		  FIRST_VALUE(gold) OVER(PARTITION BY games ORDER BY gold DESC)) AS max_gold,
	CONCAT(FIRST_VALUE(country) OVER(PARTITION BY games ORDER BY silver DESC),  ' - ', 
		  FIRST_VALUE(silver) OVER(PARTITION BY games ORDER BY silver DESC)) AS max_silver,
	CONCAT(FIRST_VALUE(country) OVER(PARTITION BY games ORDER BY bronze DESC),  ' - ', 
		  FIRST_VALUE(bronze) OVER(PARTITION BY games ORDER BY bronze DESC)) AS max_bronze
	
FROM T1 order by games;


-- 18. Which countries have never won gold medal but have won silver/bronze medals?

WITH T1 AS (
	SELECT games, region, medal, count(*) AS total_medals
	FROM olympics_events AS olyp_event
	INNER JOIN olympics_events_noc_regions AS noc_region 
	ON olyp_event.NOC = noc_region.NOC
	WHERE medal <> 'NA'
	GROUP BY games, region, medal
	ORDER BY games ASC
),
T2 AS (
	SELECT games, region AS country,
SUM(CASE WHEN medal='Gold' THEN total_medals ELSE 0 END) AS gold,
SUM(CASE WHEN medal='Silver' THEN total_medals ELSE 0 END) AS silver,
SUM(CASE WHEN medal='Bronze' THEN total_medals ELSE 0 END) AS bronze

FROM T1
GROUP BY games,region
ORDER BY games ASC, region ASC, gold DESC, silver DESC, bronze DESC
)

SELECT * FROM T2 
WHERE gold = 0
AND (silver > 0 OR bronze > 0)
ORDER BY 2 DESC, 3 DESC, 4 DESC;

-- 19. In which Sport/event, India has won highest medals.
WITH T1 AS (
	SELECT games, sport, region, count(1) AS total_medals,
	RANK() OVER(ORDER BY COUNT(1) DESC) AS rank
	FROM olympics_events AS olyp_event
	INNER JOIN olympics_events_noc_regions AS noc_region 
	ON olyp_event.NOC = noc_region.NOC
	WHERE medal <> 'NA' AND region = 'India'
	GROUP BY sport, region, games
	ORDER BY total_medals desc
)
SELECT * from T1
WHERE rank =1

-- 20. Break down all olympic games where india won medal for Hockey and how many medals in each olympic games.
WITH T1 AS (
	SELECT games, sport, region, count(1) AS total_medals,
	RANK() OVER(ORDER BY COUNT(1) DESC) AS rank
	FROM olympics_events AS olyp_event
	INNER JOIN olympics_events_noc_regions AS noc_region 
	ON olyp_event.NOC = noc_region.NOC
	WHERE medal <> 'NA' AND region = 'India' AND sport='Hockey'
	GROUP BY sport, region, games
	ORDER BY total_medals desc
)
SELECT * from T1;











