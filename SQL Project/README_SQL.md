# HR Analytics SQL Project

I put this together to practice going from a messy raw HR dataset to something you could actually hand to a business stakeholder and get real answers out of. Everything here is written in PostgreSQL.

There are two scripts:

- **`Data Preprocessing.sql`** — cleaning up the raw `employee_data` table (bad date formats, inconsistent text, stray whitespace, that kind of thing) and building a clean `hr` table to work off of.
- **`Business Queries.sql`** — the actual analysis: attrition, pay gaps, performance, recruitment sources, manager workload, tenure, termination reasons, and an absenteeism risk flag.

The dataset is the classic ~311-row HR employee dataset (you'll recognize it if you've used it before) — I'm not including the raw CSV here, just the SQL to work with it once it's loaded into a table called `public.employee_data`.

## Why I did it this way

The raw export had all the usual problems: dates stored as text in `MM/DD/YYYY` format, department names with trailing spaces, a termination reason column that says `N/A-StillEmployed` instead of just being null, etc. Rather than patch the original table in place, I rebuild a clean copy (`hr`) with `CREATE TABLE AS`, so the source data stays untouched and I can always start over if I mess something up.

A couple of things worth flagging if you're reading through the code:

- The `dob` values in the source data come in with a two-digit year, so anything parsed straight gives you people born in the 2060s. There's a fix for that in the preprocessing script (`+ INTERVAL '1900 years'`) — a bit hacky, but it does the job.
- `absences` and `dayslatelast30` come in as text and get cast to `INT` partway through the business queries script rather than up front. If you're re-running things, it's cleaner to move those `ALTER TABLE` casts into the preprocessing script — I just didn't get around to tidying that up.
- There are a couple of duplicate query blocks (Query 6 shows up twice, slightly tweaked) — leftover from iterating on the tenure bucket logic. Harmless, just not pretty.

## What the business queries actually cover

1. **Headcount & attrition by department** — who's shrinking, who's growing, and what the turnover rate looks like per team.
2. **Pay by department and gender** — quick gut-check for pay gaps.
3. **Performance distribution by department** — where the underperformers are concentrated.
4. **Recruitment source effectiveness** — which channels bring in people who actually stick around.
5. **Manager workload & team performance** — team size next to average performance, engagement, and satisfaction per manager.
6. **Tenure analysis** — how long people stay, bucketed, and whether tenure tracks with performance or attrition.
7. **Termination reasons** — the "why" behind departures, overall and by department.
8. **Absenteeism / punctuality risk flag** — a simple scoring system to surface active employees worth checking in on, based on absences, lateness, performance, and engagement.

## How to run it

1. Load the raw HR dataset into a table called `public.employee_data` (any Postgres instance works).
2. Run `Data Preprocessing.sql` top to bottom — it drops and rebuilds the `hr` table and runs some sanity checks along the way (row counts, null counts, duplicate IDs, salary outliers).
3. Run `Business Queries.sql` — each section is self-contained, so feel free to run them individually rather than the whole file at once.

## Notes to self / possible next steps

- Move all the `ALTER TABLE ... TYPE` casts into the preprocessing script so `Business Queries.sql` is pure analysis.
- Clean up the duplicate Query 6 block.
- Would be nice to wrap the manager numeric performance mapping (`Exceeds` → 4, etc.) into a reusable view instead of a repeated `CASE` expression.
- Could eventually hook this up to a BI tool (Metabase/Looker Studio) for a live dashboard instead of static queries.

Feel free to fork this if you're learning SQL and want a real (if slightly messy) dataset to practice cleaning and querying against.
