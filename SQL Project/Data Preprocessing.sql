 
-- ============================================================
-- SECTION 1 : DATA CLEANING
-- ============================================================
 
-- ── 1.1  Create a clean working table ───────────────────────
-- We cast text dates to proper DATE, trim whitespace,
-- and standardise inconsistent values.
 
DROP TABLE IF EXISTS hr;
 
CREATE TABLE hr AS
SELECT
    empid,
    TRIM(employee_name)      AS employee_name,
    -- dates safely cast from text
    TO_DATE(dateofhire, 'MM/DD/YYYY') AS date_of_hire,
 
    -- active employees have no termination date → NULL is correct
    CASE
        WHEN TRIM(dateoftermination) = ''
          OR dateoftermination IS NULL
        THEN NULL
        ELSE TO_DATE(dateoftermination, 'MM/DD/YYYY')
    END                                             AS date_of_termination,
 	TO_DATE(dob, 'MM/DD/YYYY')                     AS dob,
 	TO_DATE(lastperformancereview_date, 'MM/DD/YYYY')   AS last_performance_review_date,
 	-- trim trailing spaces from department (raw data has "Production       ")
    TRIM(department)                                AS department,
 	TRIM(emp_position)                              AS emp_position,
    TRIM(sex)                                       AS sex,           -- raw has "M " with space
 -- normalise term_reason: active employees get a consistent label
    CASE
        WHEN TRIM(termreason) = 'N/A-StillEmployed' THEN 'Still Employed'
        ELSE TRIM(termreason)
    END                                             AS term_reason,
 
    TRIM(employmentstatus)                         AS employment_status,
    TRIM(performancescore)                         AS performance_score,
    TRIM(maritaldesc)                              AS marital_desc,
    TRIM(citizendesc)                              AS citizen_desc,
    TRIM(racedesc)                                 AS race_desc,
    TRIM(hispaniclatino)                           AS hispanic_latino,
    TRIM(recruitmentsource)                        AS recruitment_source,
    TRIM(managername)                              AS manager_name,
 
    salary,
    managerid,
    engagementsurvey,
    empsatisfaction,
    specialprojectscount,
    dayslatelast30,
    absences,
    termd,
    deptid,
    positionid,
    perfscoreid,
	employmentstatus,
	performancescore,
	recruitmentsource,
	lastperformancereview_date,
	managername,
	dateofhire
FROM public.employee_data;

-- ── 1.2  Verify row count matches original ──────────────────
SELECT COUNT(*) AS total_rows FROM hr;
-- Expected: 311

select * from hr
-- ── 1.3  Check for duplicate EmpIDs ─────────────────────────
-- Each employee should appear exactly once.
SELECT
    empid,
    COUNT(*) AS occurrences
FROM hr
GROUP BY empid
HAVING COUNT(*) > 1;


-- Expected: 0 rows (no duplicates)
 
 -- ── 1.4  Confirm date columns parsed correctly ───────────────
SELECT
    MIN(date_of_hire)   AS earliest_hire,
    MAX(date_of_hire)   AS latest_hire,
    MIN(dob)            AS oldest_dob,
    MAX(dob)            AS youngest_dob
FROM hr;

 
-- ── 1.5  Standardise sex column check ───────────────────────
-- After TRIM the only values should be 'M' and 'F'.
SELECT
    sex,
    COUNT(*) AS cnt
FROM hr
GROUP BY sex;


 
-- ── 1.6  Salary sanity check — flag outliers ────────────────
-- Any salary <= 0 or suspiciously high (>500k) is worth flagging.
SELECT
    empid,
    employee_name,
    salary
FROM hr
WHERE salary <= 0
   OR salary > 500000;



-- ============================================================
-- SECTION 2 : NULL / MISSING VALUE ANALYSIS
-- ============================================================
 
-- ── 2.1  Count NULLs in every column ────────────────────────
-- This single query gives you a full data-quality snapshot.
SELECT
    COUNT(*)                                            AS total_rows,
    COUNT(*) FILTER (WHERE empid              IS NULL) AS null_emp_id,
    COUNT(*) FILTER (WHERE employee_name       IS NULL) AS null_name,
    COUNT(*) FILTER (WHERE date_of_hire        IS NULL) AS null_hire_date,
    COUNT(*) FILTER (WHERE date_of_termination IS NULL) AS null_term_date,  
    COUNT(*) FILTER (WHERE dob                 IS NULL) AS null_dob,
    COUNT(*) FILTER (WHERE salary              IS NULL) AS null_salary,
    COUNT(*) FILTER (WHERE department          IS NULL) AS null_dept,
    COUNT(*) FILTER (WHERE managerid  = 0 ) AS null_manager_id, 
    COUNT(*) FILTER (WHERE performance_score   IS NULL) AS null_perf_score,
    COUNT(*) FILTER (WHERE engagementsurvey   IS NULL) AS null_engagement,
    COUNT(*) FILTER (WHERE lastperformancereview_date IS NULL) AS null_review_date
FROM hr;

-- ── 2.2  Understand WHY term_date is null ───────────────────
-- It should only be NULL for currently active employees.
-- If any terminated employees are missing it, that is a real data gap.
SELECT
    employmentstatus,
    COUNT(*)                                              AS total,
    COUNT(*) FILTER (WHERE date_of_termination IS NULL)  AS missing_term_date
FROM hr
GROUP BY employmentstatus
ORDER BY total DESC;

-- ── 2.3  Employees with no manager assigned ──────────────────
-- 8 employees have  manager_id as 0 — find who they are.
SELECT
    empid,
    employee_name,
    department,
    emp_position,
    employment_status
FROM hr
WHERE managerid = 0
ORDER BY department;

-- ── 2.4  Employees never reviewed ───────────────────────────
SELECT
    empid,
    employee_name,
    date_of_hire,
    employmentstatus
FROM hr
WHERE lastperformancereview_date IS NULL
ORDER BY date_of_hire;
 

 