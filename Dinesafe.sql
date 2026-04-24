-----------------カウント-------------------------
WITH
  cleaned_data AS (
    SELECT
      _id,
      INITCAP(TRIM(`Establishment ID`)) AS `Establishment ID`,
      INITCAP(TRIM(`Inspection ID`)) AS `Inspection ID`,
      INITCAP(TRIM(`Establishment Name`)) AS `Establishment Name`,
      -- Distinguish Establishment Type 
      CASE
        WHEN UPPER(TRIM(`Establishment Type`)) LIKE 'ICE CREAM%'
          THEN 'Ice Cream Parlour'
        WHEN
          UPPER(TRIM(`Establishment Type`))
          IN ('BUTCHER SHOP', 'BUTCHER SHOPS')
          THEN 'Butcher Shop'
        WHEN
          UPPER(TRIM(`Establishment Type`))
          IN ('CENTRALIZED KITCHEN', 'CENTRALIZED KITCHENS')
          THEN 'Centralized Kitchen'
        ELSE INITCAP(TRIM(`Establishment Type`))
        END
        AS `Establishment Type`,
------ Take Postal Code From Address(right 7 letters)and remove words'none' and clean it---------------------------
      INITCAP(
        TRIM(
          REGEXP_REPLACE(
            SUBSTR(
              `Establishment Address`,
              1,
              GREATEST(0, LENGTH(`Establishment Address`) - 7)),
            r'(?i)none',
            '')))
        AS `Establishment Address`,
      INITCAP(TRIM(`Infraction Details`)) AS `Infraction Details`,
      INITCAP(TRIM(`Inspection Observation`)) AS `Inspection Observation`,
      `Inspection Date`,
      INITCAP(TRIM(`Severity`)) AS `Severity`,
      INITCAP(TRIM(`Action`)) AS `Action`,
      INITCAP(TRIM(`Outcome`)) AS `Outcome`,
      `Outcome Date`,
      `Amount Fined`,
      `Latitude`,
      `Longitude`,
      INITCAP(TRIM(`unique_id`)) AS `unique_id`,
      -- Pull 7 letters from right as postal code, and remove 'none'
      CASE
        WHEN
          REGEXP_CONTAINS(
            RIGHT(TRIM(`Establishment Address`), 7),
            r'[A-Z][0-9][A-Z] ?[0-9][A-Z][0-9]')
          THEN RIGHT(TRIM(`Establishment Address`), 7)
        ELSE NULL
        END
        AS `postal_code`
    FROM `lunar-carving-457020-h5.YuseiSQL.Dinesafe`
  )

-- Check Establishment Type 
SELECT `Establishment Type`, COUNT(*) AS count
FROM cleaned_data
GROUP BY 1
ORDER BY count DESC;

------------------Cleaned Original----------------------------------------
SELECT
  _id,
  INITCAP(TRIM(`Establishment ID`)) AS `Establishment ID`,
  INITCAP(TRIM(`Inspection ID`)) AS `Inspection ID`,
  INITCAP(TRIM(`Establishment Name`)) AS `Establishment Name`,
  INITCAP(TRIM(`Establishment Type`)) AS `Establishment Type`,
  -- remove none and postal code
  INITCAP(
    TRIM(
      REGEXP_REPLACE(
        SUBSTR(
          `Establishment Address`,
          1,
          GREATEST(0, LENGTH(`Establishment Address`) - 7)),
        r'(?i)none',
        '')))
    AS `Establishment Address`,
  INITCAP(TRIM(`Infraction Details`)) AS `Infraction Details`,
  INITCAP(TRIM(`Inspection Observation`)) AS `Inspection Observation`,
  `Inspection Date`,
  INITCAP(TRIM(`Severity`)) AS `Severity`,
  INITCAP(TRIM(`Action`)) AS `Action`,
  INITCAP(TRIM(`Outcome`)) AS `Outcome`,
  `Outcome Date`,
  `Amount Fined`,
  `Latitude`,
  `Longitude`,
  INITCAP(TRIM(`unique_id`)) AS `unique_id`,
  -- pull postal code
  CASE
    WHEN
      REGEXP_CONTAINS(
        RIGHT(TRIM(`Establishment Address`), 7),
        r'[A-Z][0-9][A-Z] ?[0-9][A-Z][0-9]')
      THEN RIGHT(TRIM(`Establishment Address`), 7)
    ELSE NULL
    END
    AS `postal_code`
FROM `lunar-carving-457020-h5.YuseiSQL.Dinesafe`;
-----------------------Score based severity-----------------------------------------
WITH
  cleaned_data AS (
    SELECT
      `Establishment ID`,
      `Establishment Name`,
      INITCAP(TRIM(`Severity`)) AS Severity_Clean,
      -- Severity scoring
      CASE
        WHEN INITCAP(TRIM(`Severity`)) = 'Crucial' THEN 10
        WHEN INITCAP(TRIM(`Severity`)) = 'Significant' THEN 5
        WHEN INITCAP(TRIM(`Severity`)) = 'Minor' THEN 2
        WHEN `Severity` IS NULL OR TRIM(`Severity`) = '' THEN 0
        ELSE 0  -- NA or others
        END
        AS penalty_score
    FROM `lunar-carving-457020-h5.YuseiSQL.Dinesafe`
  ),
  establishment_scores AS (
    SELECT
      `Establishment ID`,
      ANY_VALUE(`Establishment Name`) AS `Establishment Name`,
      SUM(penalty_score) AS total_penalty_score,
      COUNT(*) AS total_inspections
    FROM cleaned_data
    GROUP BY 1
  )

-- ranking of severity score------------
SELECT
  `Establishment Name`,
  total_penalty_score,
  total_inspections,
  -- if there is no penalty or waring, 'P' stands for pass
  IF(total_penalty_score = 0, 'P', CAST(total_penalty_score AS STRING))
    AS health_rating
FROM establishment_scores
ORDER BY total_penalty_score DESC;
--------------------Establishment Type and scoring------------------------

WITH
  cleaned_data AS (
    SELECT
      CASE
        WHEN UPPER(TRIM(`Establishment Type`)) LIKE 'ICE CREAM%'
          THEN 'Ice Cream Parlour'
        WHEN
          UPPER(TRIM(`Establishment Type`))
          IN ('BUTCHER SHOP', 'BUTCHER SHOPS')
          THEN 'Butcher Shop'
        WHEN
          UPPER(TRIM(`Establishment Type`))
          IN ('CENTRALIZED KITCHEN', 'CENTRALIZED KITCHENS')
          THEN 'Centralized Kitchen'
        ELSE INITCAP(TRIM(`Establishment Type`))
        END
        AS `Establishment_Type`,
      -- soring based on statement
      CASE
      WHEN INITCAP(TRIM(`Severity`)) = '*Crucial' THEN 1.5
       WHEN INITCAP(TRIM(`Severity`)) = '*Significant' THEN 1.5
        WHEN INITCAP(TRIM(`Severity`)) IN ('NA', 'Na', 'None') THEN 0
        WHEN `Severity` IS NULL OR TRIM(`Severity`) = '' THEN 0
        ELSE 1  -- Minor, or ant other warning is 1
        END
        AS is_warned
    FROM `lunar-carving-457020-h5.YuseiSQL.Dinesafe`
  )
SELECT
  `Establishment_Type`,
  -- Total warning
  SUM(is_warned) AS total_warning_count,
  -- total records
  COUNT(*) AS total_records,
  -- warning rate percentage = Total warning / Total records
  ROUND(SUM(is_warned) / COUNT(*) * 100, 2) AS warning_rate_percentage
FROM cleaned_data
GROUP BY 1
ORDER BY total_warning_count DESC;
-------------------Which month has the most number of warning--------------------------

WITH
  monthly_data AS (
    SELECT
      -- extract month
      EXTRACT(MONTH FROM `Inspection Date`) AS inspection_month,
      -- if they received warning
      CASE
        WHEN INITCAP(TRIM(`Severity`)) IN ('NA', 'Na', 'None') THEN 0
        WHEN `Severity` IS NULL OR TRIM(`Severity`) = '' THEN 0
        ELSE 1  -- if they had a warning then 1
        END
        AS is_warned
    FROM `lunar-carving-457020-h5.YuseiSQL.Dinesafe`
  )
SELECT
  inspection_month,
  -- amount of warning
  SUM(is_warned) AS total_warning_count,
  -- amount of inspections
  COUNT(*) AS total_inspections,
  -- warning/inspections（%）
  ROUND(SUM(is_warned) / COUNT(*) * 100, 2) AS warning_rate_percentage
FROM monthly_data
GROUP BY 1
ORDER BY inspection_month ASC;



