
-- ============================================================
-- SECTION 3 : BUSINESS KPI QUERIES
-- ============================================================
 
-- ────────────────────────────────────────────────────────────
-- QUERY 1 : Headcount & attrition summary by department
-- Business question: Which departments have the highest turnover and how many active employees remain?
-- SQL skills: GROUP BY, FILTER aggregation, ROUND, division
-- ────────────────────────────────────────────────────────────
SELECT
    department,
 	-- total employees ever in this department
    COUNT(*)                                                    AS total_employees,
 
    -- currently active
    COUNT(*) FILTER (WHERE employmentstatus = 'Active')        AS active,
 
    -- voluntarily left
    COUNT(*) FILTER (WHERE employmentstatus = 'Voluntarily Terminated') AS vol_terminated,
 
    -- fired for cause
    COUNT(*) FILTER (WHERE employmentstatus = 'Terminated for Cause')   AS terminated_for_cause,
 
    -- attrition rate = (all terminated / total) * 100
    ROUND(
        COUNT(*) FILTER (WHERE termd = '1') * 100.0 / COUNT(*),
    1)                                                          AS attrition_rate_pct
 
FROM hr
GROUP BY department
ORDER BY attrition_rate_pct DESC;

 
-- ────────────────────────────────────────────────────────────
-- QUERY 2 : Average salary by department and gender
-- Business question: Is there a pay gap between M and F
--   within each department?
-- SQL skills: GROUP BY multiple columns, ROUND, AVG
-- ────────────────────────────────────────────────────────────
SELECT
    department,
    sex,
    COUNT(*)             AS headcount,
    ROUND(AVG(salary))   AS avg_salary,
    MIN(salary)          AS min_salary,
    MAX(salary)          AS max_salary
FROM hr
GROUP BY department, sex
ORDER BY department, sex;


-- ────────────────────────────────────────────────────────────
-- QUERY 3 : Performance score distribution per department
-- Business question: Which departments have the most
--   underperformers (PIP / Needs Improvement)?
-- SQL skills: FILTER aggregation, calculated percentages
-- ────────────────────────────────────────────────────────────
SELECT
    department,
    COUNT(*)                                                              AS total,
 
    COUNT(*) FILTER (WHERE performancescore = 'Exceeds')                AS exceeds,
    COUNT(*) FILTER (WHERE performancescore = 'Fully Meets')            AS fully_meets,
    COUNT(*) FILTER (WHERE performancescore = 'Needs Improvement')      AS needs_improvement,
    COUNT(*) FILTER (WHERE performancescore = 'PIP')                    AS pip,
 
    -- % of employees flagged as underperforming
    ROUND(
        (COUNT(*) FILTER (WHERE performancescore IN ('Needs Improvement')))
        * 100.0 / COUNT(*),
    1)                                            AS underperformer_pct
FROM hr
GROUP BY department
ORDER BY underperformer_pct DESC;


-- ────────────────────────────────────────────────────────────
-- QUERY 4 : Recruitment source effectiveness
-- Business question: Which hiring channel brings the most employees, and which has the highest termination rate?
-- SQL skills: GROUP BY, FILTER, subquery for ranking
-- ────────────────────────────────────────────────────────────
SELECT
    recruitmentsource,
    COUNT(*)                                               AS total_hired,
    COUNT(*) FILTER (WHERE employmentstatus = 'Active')   AS still_active,
    COUNT(*) FILTER (WHERE termd = '1')                      AS terminated,
 
    ROUND(
        COUNT(*) FILTER (WHERE termd ='1' ) * 100.0 / COUNT(*),
    1)                                                     AS termination_rate_pct,
 
    ROUND(AVG(salary))                                     AS avg_salary_offered
FROM hr
GROUP BY recruitmentsource
ORDER BY total_hired DESC;


-- ────────────────────────────────────────────────────────────
-- QUERY 5 : Manager workload & team performance
-- Business question: How many employees does each manager
--   oversee, and what is their team's average performance
--   and engagement?
-- SQL skills: GROUP BY, AVG, JOIN-like self-reference,
--             ROUND, ORDER BY
-- ────────────────────────────────────────────────────────────
SELECT
    managername,
    department,
    COUNT(*)                            AS team_size,
 
    -- map text score to numeric for averaging
    ROUND(AVG(
        CASE performancescore
            WHEN 'Exceeds'           THEN 4
            WHEN 'Fully Meets'       THEN 3
            WHEN 'Needs Improvement' THEN 2
            WHEN 'PIP'               THEN 1
        END
    ), 2)                               AS avg_perf_score_numeric,
 
    ROUND(AVG(engagementsurvey), 2)    AS avg_engagement,
    ROUND(AVG(empsatisfaction), 2)     AS avg_satisfaction,
    ROUND(AVG(absences), 1)             AS avg_absences,
 
    COUNT(*) FILTER (WHERE termd = '1')   AS employees_lost
FROM hr
WHERE managername IS NOT NULL
GROUP BY managername, department
ORDER BY team_size DESC;


-- ---------------------------------------
-- Step 1: add the column
ALTER TABLE hr ADD COLUMN age INT;

-- Step 2: calculate age from dob and store it

UPDATE hr
SET dob = (dob + INTERVAL '1900 years')::DATE;

UPDATE hr
SET age = DATE_PART('year', AGE(CURRENT_DATE, dob))::INT;

-- Verify
SELECT employee_name, dob, age FROM hr LIMIT 10;
-- Step 3: move the column position to appear near dob
-- (PostgreSQL doesn't support reordering, but you can verify it's there)
SELECT empid, employee_name, dob, age, department, salary
FROM hr
ORDER BY empid
LIMIT 10;


ALTER TABLE hr
    ALTER COLUMN date_of_hire
        TYPE DATE USING date_of_hire::DATE;


-- ────────────────────────────────────────────────────────────
-- QUERY 6 : Employee tenure analysis (years of service)
-- Business question: What is the average tenure of active vs terminated employees? Do long-tenured staff perform better?
-- SQL skills: DATE arithmetic with AGE(), EXTRACT, CASE WHEN
--             bucketing, GROUP BY
-- ────────────────────────────────────────────────────────────

-- 6a. Tenure buckets for all employees
SELECT
    CASE
        WHEN EXTRACT(YEAR FROM age(
                COALESCE(date_of_termination, CURRENT_DATE), date_of_hire
             )) < 1  THEN '< 1 year'
        WHEN EXTRACT(YEAR FROM age(
                COALESCE(date_of_termination, CURRENT_DATE), date_of_hire
             )) < 3  THEN '1–2 years'
        WHEN EXTRACT(YEAR FROM age(
                COALESCE(date_of_termination, CURRENT_DATE), date_of_hire
             )) < 6  THEN '3–5 years'
        WHEN EXTRACT(YEAR FROM age(
                COALESCE(date_of_termination, CURRENT_DATE), date_of_hire
             )) < 11 THEN '6–10 years'
        ELSE '10+ years'
    END                          AS tenure_bucket,
 
    COUNT(*)                     AS employees,
    ROUND(AVG(salary))           AS avg_salary,
    ROUND(AVG(engagementsurvey),2) AS avg_engagement,
 
    COUNT(*) FILTER (WHERE termd = '1')  AS terminated_count,
    ROUND(
        COUNT(*) FILTER (WHERE termd ='1' ) * 100.0 / COUNT(*),
    1)                           AS attrition_pct
 
FROM hr
GROUP BY tenure_bucket
--ORDER BY MIN(EXTRACT(YEAR FROM age(COALESCE(date_of_termination, CURRENT_DATE), dateofhire
--)));


  
-- ────────────────────────────────────────────────────────────
-- QUERY 6 : Employee tenure analysis (years of service)
-- Business question: What is the average tenure of active vs
--   terminated employees? Do long-tenured staff perform better?
-- SQL skills: DATE arithmetic with AGE(), EXTRACT, CASE WHEN
--             bucketing, GROUP BY
-- ────────────────────────────────────────────────────────────
 
-- 6a. Tenure buckets for all employees
SELECT
    CASE
        WHEN EXTRACT(YEAR FROM age(
                COALESCE(date_of_termination, CURRENT_DATE), date_of_hire
             )) < 1  THEN '< 1 year'
        WHEN EXTRACT(YEAR FROM age(
                COALESCE(date_of_termination, CURRENT_DATE), date_of_hire
             )) < 3  THEN '1–2 years'
        WHEN EXTRACT(YEAR FROM age(
                COALESCE(date_of_termination, CURRENT_DATE), date_of_hire
             )) < 6  THEN '3–5 years'
        WHEN EXTRACT(YEAR FROM age(
                COALESCE(date_of_termination, CURRENT_DATE), date_of_hire
             )) < 11 THEN '6–10 years'
        ELSE '10+ years'
    END                          AS tenure_bucket,
 
    COUNT(*)                     AS employees,
    ROUND(AVG(salary))           AS avg_salary,
    ROUND(AVG(engagementsurvey),2) AS avg_engagement,
 
    COUNT(*) FILTER (WHERE termd = '1')  AS terminated_count,
    ROUND(
        COUNT(*) FILTER (WHERE termd = '1') * 100.0 / COUNT(*),
    1)                           AS attrition_pct
 
FROM hr
GROUP BY tenure_bucket
ORDER BY MIN(EXTRACT(YEAR FROM age(
    COALESCE(date_of_termination, CURRENT_DATE), date_of_hire
)));
 

 -- 6b. Average tenure: active vs terminated
SELECT
    employment_status,
    ROUND(
        AVG(EXTRACT(YEAR FROM age(
            COALESCE(date_of_termination, CURRENT_DATE), date_of_hire
        ))),
    1)                           AS avg_tenure_years,
    ROUND(AVG(salary))           AS avg_salary
FROM hr
WHERE employment_status != 'Active'
   OR date_of_termination IS NULL
GROUP BY employment_status;

 
-- ────────────────────────────────────────────────────────────
-- QUERY 7 : Termination reasons breakdown
-- Business question: Why are employees leaving, and does the
--   reason vary by department or performance level?
-- SQL skills: WHERE, GROUP BY, ORDER BY, FILTER, subquery
-- ────────────────────────────────────────────────────────────
 
-- 7a. Overall top termination reasons
SELECT
    term_reason,
    COUNT(*)                    AS total_departures,
    ROUND(AVG(salary))          AS avg_salary_at_exit,
    ROUND(AVG(
        EXTRACT(YEAR FROM age(date_of_termination, date_of_hire))
    ), 1)                       AS avg_tenure_at_exit_yrs
FROM hr
WHERE termd = '1'
  AND term_reason <> 'Still Employed'
GROUP BY term_reason
ORDER BY total_departures DESC;

-- 7b. Termination reasons by department (top reason per dept)
-- Uses a subquery to find the most common reason per department
SELECT
    department,
    term_reason,
    cnt
FROM (
    SELECT
        department,
        term_reason,
        COUNT(*)                              AS cnt,
        RANK() OVER (
            PARTITION BY department
            ORDER BY COUNT(*) DESC
        )                                     AS rnk
    FROM hr
    WHERE termd = '1'
      AND term_reason <> 'Still Employed'
    GROUP BY department, term_reason
) ranked
WHERE rnk = 1
ORDER BY department;
 
 
  
-- ────────────────────────────────────────────────────────────
-- QUERY 8 : Absenteeism & punctuality risk flag
-- Business question: Which active employees are high-risk based on absences AND days late — and does absenteeism
--   correlate with lower performance?
-- SQL skills: CASE WHEN scoring, WHERE filter on active,
--             ORDER BY multi-column, comparison operators
-- ────────────────────────────────────────────────────────────
 
-- 8a. High-risk employees (active only)


ALTER TABLE hr ALTER COLUMN absences          TYPE INT     USING absences::INT;
 
SELECT *
	FROM (
    	SELECT
        	empid,
        	employee_name,
        	department,
        	emp_position,
        	absences,
        	dayslatelast30,
        	performancescore,
        	engagementsurvey,

        CASE WHEN absences         > 15  THEN 2 ELSE 0 END +
        CASE WHEN dayslatelast30 > 3   THEN 2 ELSE 0 END +
        CASE WHEN performancescore IN ('Needs Improvement', 'PIP') THEN 2 ELSE 0 END +
        CASE WHEN engagementsurvey < 3.0 THEN 1 ELSE 0 END  AS risk_score

    FROM hr
    WHERE employmentstatus = 'Active'
) AS scored
WHERE risk_score >= 3
ORDER BY risk_score DESC, absences DESC;
 



-- 8b. Average absences by performance score (all employees)
-- Shows whether poor performers are also absent more
ALTER TABLE hr ALTER COLUMN dayslatelast30  TYPE INT     USING dayslatelast30::INT;

SELECT
    performancescore,
    COUNT(*)                        AS employees,
    ROUND(AVG(absences), 1)         AS avg_absences,
    ROUND(AVG(dayslatelast30), 1) AS avg_days_late,
    ROUND(AVG(engagementsurvey), 2) AS avg_engagement
FROM hr
GROUP BY performancescore
ORDER BY avg_absences DESC;
 
 
-- ============================================================
-- END OF SCRIPT
-- ============================================================

 
 
 
 