# Production Database Investigation -- Final Consolidated Report

**Instance:** af-database (AWS RDS PostgreSQL 14.17)
**Instance Class:** db.t4g.large (2 vCPU, 8 GB RAM) -- recently downsized from db.t4g.2xlarge
**Storage:** 148 GB gp2, ~7 GB used (4.6%)
**Database Size:** 1.71 GB
**Date:** 2026-04-25
**Phases:** Phase 1 (initial investigation) + Phase 2 (deep dive with EXPLAIN ANALYZE, write analysis, TOAST, advanced patterns)
**Verified by:** Claude Sonnet swarm + OpenAI Codex (independent, parallel verification against live DB and AWS)

---

## Table of Contents

1. [PostgreSQL Configuration Issues](#1-postgresql-configuration-issues)
2. [Query Performance](#2-query-performance)
3. [Indexes -- Missing, Unused, Duplicate, and Optimization](#3-indexes----missing-unused-duplicate-and-optimization)
4. [Write Performance -- Amplification & HOT Updates](#4-write-performance----amplification--hot-updates)
5. [Bloat, Autovacuum & Visibility Map](#5-bloat-autovacuum--visibility-map)
6. [Storage & TOAST Analysis](#6-storage--toast-analysis)
7. [Advanced Query Patterns](#7-advanced-query-patterns)
8. [AWS / Infrastructure](#8-aws--infrastructure)
9. [Logging & Observability Gaps](#9-logging--observability-gaps)
10. [Healthy Baselines (no action required)](#10-healthy-baselines-no-action-required)
11. [Database Stats Overview](#11-database-stats-overview)
12. [Prioritized Action Plan](#12-prioritized-action-plan)
13. [Master Finding Summary Table](#13-master-finding-summary-table)

---

## 1. PostgreSQL Configuration Issues

**Severity: CRITICAL** | Tracked in: [#488](https://github.com/avantifellows/db-service/issues/488)
*Source: Phase 1*

The database is running on the **default.postgres14** parameter group with **zero custom tuning**. Several settings are severely misconfigured for SSD-backed storage and the current workload.

### 1.1 `random_page_cost` = 4.0 (should be 1.1)

**Impact: SEVERE -- affects every query plan in the database**

The default value of 4.0 assumes spinning disks. RDS uses EBS gp2 SSD storage where random I/O is nearly as fast as sequential I/O. At 4.0, the query planner **over-penalizes index scans and favors sequential scans** even when indexes exist and would be faster.

This directly explains why the `student` table has **26.4 million sequential scans at 46.9% seq-scan ratio** despite having multiple indexes, and why `chapter_curriculum` and `topic_curriculum` have **100% sequential scan rates**.

**Fix:** Set `random_page_cost = 1.1` in the RDS parameter group. This is a dynamic parameter -- no reboot required.

### 1.2 `effective_cache_size` = 3,809 MB (should be ~6,144 MB)

**Impact: HIGH -- planner underestimates available cache**

At ~3.8 GB, the planner thinks there's less cache available than there actually is (shared_buffers + OS page cache ~ 6 GB on an 8 GB instance). This causes the planner to favor sequential scans over index scans for larger tables.

**Fix:** Set `effective_cache_size = 6GB` (or `786432` in 8kB pages). Dynamic parameter.

### 1.3 `work_mem` = 4 MB (should be 16 MB)

**Impact: HIGH -- 5.5 TB of cumulative temp file writes**

The database has written **5.5 TB of temp files** cumulatively since stats were last reset (2024-06-19). The primary offenders:
- `session_occurrence JOIN session` queries (419K calls, generating 38,872 temp blocks)
- Various session lookup queries (108K calls, 30,374 temp blocks)

With only ~20 active connections (max 838 configured), there is ample memory headroom to increase this.

**Fix:** Set `work_mem = 16MB`. Dynamic parameter.

### 1.4 `max_connections` = 838 (should be 100-150)

**Impact: MEDIUM -- wastes memory, misleading capacity**

RDS auto-calculates 838 for db.t4g.large, but the database has only ~20 connections. Each PostgreSQL backend reserves memory structures, and 838 connections could theoretically consume 4-8 GB just for connection overhead. The application uses ~11 idle connections on average.

**Fix:** Set `max_connections = 150`. **Requires reboot.** Use a connection pooler (PgBouncer/RDS Proxy) if more are ever needed.

### 1.5 `effective_io_concurrency` = 1 (should be 200)

**Impact: MEDIUM -- not leveraging SSD parallelism**

The default of 1 is for spinning disks. EBS SSD can handle many concurrent I/O requests. This affects bitmap heap scans and prefetching.

**Fix:** Set `effective_io_concurrency = 200`. Dynamic parameter.

### 1.6 `maintenance_work_mem` = 125 MB (should be 256-512 MB)

**Impact: MEDIUM -- VACUUM and CREATE INDEX operations are slower**

With the largest table at 529 MB, 125 MB slows maintenance operations.

**Fix:** Set `maintenance_work_mem = 256MB`. Dynamic parameter.

### 1.7 `statement_timeout` = 0 (disabled)

**Impact: MEDIUM -- no protection against runaway queries**

Any query can run indefinitely, holding connections and locks.

**Fix:** Set `statement_timeout = 30000` (30 seconds). Dynamic parameter.

### 1.8 `idle_in_transaction_session_timeout` = 24 hours

**Impact: LOW -- idle transactions can hold locks for a full day**

Idle-in-transaction connections prevent VACUUM from cleaning dead tuples.

**Fix:** Set `idle_in_transaction_session_timeout = 300000` (5 minutes). Dynamic parameter.

---

## 2. Query Performance

**Severity: CRITICAL**
*Source: Phase 1 (pg_stat_statements) + Phase 2 (EXPLAIN ANALYZE deep dive)*

pg_stat_statements reveals the queries consuming the most cumulative database time. Phase 2 added EXPLAIN ANALYZE plans from production to confirm root causes and identify the ORDER BY issue.

### 2.1 `group_user` composite lookup -- #1 cumulative time consumer

*Found by: Both phases* | Tracked in: [#489](https://github.com/avantifellows/db-service/issues/489)

**Stats:** 4.58M calls, 82,938 seconds (23.0 hours) total, 18.12ms mean, 508ms max, 0.99 rows/call

```sql
SELECT ... FROM group_user WHERE group_id=$1 AND user_id=$2 ORDER BY id LIMIT/OFFSET
```

The table has separate single-column indexes on `group_id` and `user_id` but **no composite index on `(group_id, user_id)`**. PostgreSQL uses one single-column index with a filter on the other column.

**EXPLAIN ANALYZE (Phase 2, real data):**
```
Index Scan using group_user_user_id_index
  Index Cond: (user_id = 1)
  Filter: (group_id = 2)
  Rows Removed by Filter: 3
Planning: 0.401 ms | Execution: 0.083 ms
```

Current sampled plans are fast (0.083ms), but the historical 18ms mean across 4.5M calls suggests the cost comes from historical plan/index state, workload spikes, or the sheer volume of repeated membership probes. Top users have 9-12 memberships, so the bottleneck is more about call volume than large per-call cost.

**Group skew (verified by Codex):**
| group_id | member count |
|---|---|
| 8851 | 258,977 |
| 8850 | 155,725 |
| 8085 | 134,738 |
| 3 | 117,793 |
| 2 | 71,465 |

**Fix:** `CREATE INDEX CONCURRENTLY ON group_user (group_id, user_id);` -- single highest-impact index change. Additionally, consider request-level batching/caching of membership checks, or maintaining a compact membership closure structure to address the 4.6M call volume (a fundamentally application-level problem beyond indexing).

### 2.2 `student` lookup by `student_id` -- #2 cumulative time consumer

*Found by: Both phases* | Tracked in: [#490](https://github.com/avantifellows/db-service/issues/490) | Severity adjusted: Critical → High (council consensus: most of the cost is from random_page_cost, tracked in #488)

**Stats:** 12.2M calls, 74,442 seconds (20.7 hours) total, 6.10ms mean

```sql
SELECT * FROM student WHERE student_id = $1
```

Extremely high call count suggests this is called on nearly every API request involving students.

**EXPLAIN ANALYZE (Phase 2):**
```
Index Scan using student_student_id_index
  Index Cond: (student_id = '13130943')
  Buffers: shared hit=4
Execution Time: 0.079 ms (but width=4,642 bytes per row)
```

The index lookup is fast (0.079ms). The 6.10ms historical average comes from **broad projection** -- the planner estimates 4,122-4,642 bytes per row (48 columns including parent professions, percentages, certificates), though actual sampled tuple size was 88 bytes. The cost is the combination of 12.2M calls and full-row SELECT across wide schema columns. At 12.2M calls, the cost is cumulative data handling, not index access.

**Fix:** For hot-path lookups (auth, identity), use `SELECT id, user_id, student_id, status` instead of `SELECT *`. Keep full-row fetches for detail views only. Fixing `random_page_cost` (Section 1.1) should also improve this. Review if the application can batch these lookups or cache results.

### 2.3a `session_occurrence` active-window query WITHOUT session_id -- 565x speedup available

*Found by: Phase 2 (Codex)* | Tracked in: [#491](https://github.com/avantifellows/db-service/issues/491)

The active-window query **without `session_id`** is extremely sensitive to `ORDER BY id`:

**EXPLAIN ANALYZE -- with ORDER BY id (problematic):**
```
Limit (actual time=255.682..256.660 rows=10)
  Index Scan using session_occurence_pkey
    Filter: (start_time <= X AND end_time >= X)
    Rows Removed by Filter: 630,180
    Buffers: shared hit=618,673
Execution Time: 256.699 ms
```

**EXPLAIN ANALYZE -- with ORDER BY end_time (optimized):**
```
Index Scan using session_occurrence_end_time_index
  Index Cond: (end_time >= X)
  Filter: (start_time <= X)
  Rows Removed by Filter: 66
Execution Time: 0.455 ms
```

**Key insight:** `ORDER BY id` forces a primary key walk scanning 630K rows. Changing to `ORDER BY end_time` uses the existing index and is **565x faster** (0.455ms vs 256ms). Note: only `ORDER BY end_time` was measured; `ORDER BY start_time` was not tested.

**Fix:** Stop paginating by surrogate `id` for temporal queries. Use keyset pagination on a temporal key. **This is the single highest single-query impact fix in the entire database.**

### 2.3b `session_occurrence` hot query WITH session_id -- #3 cumulative time consumer

*Found by: Both phases* | Tracked in: [#492](https://github.com/avantifellows/db-service/issues/492)

**Stats:** 2.05M calls, 39,748 seconds (11.0 hours) total, 19.35ms mean

```sql
SELECT ... FROM session_occurrence
WHERE start_time <= $1 AND end_time >= $2 AND session_id = $3
ORDER BY id LIMIT/OFFSET
```

Has separate indexes on `start_time`, `end_time`, and `session_id` but no composite index.

**EXPLAIN ANALYZE (Phase 2, with session_id -- BitmapAnd):**
```
BitmapAnd
  Bitmap Index Scan on session_occurrence_session_id_index (42 rows)
  Bitmap Index Scan on session_occurrence_start_time_index (4,750 rows)
Bitmap Heap Scan (Rows Removed by Filter: 2)
Execution Time: 0.278 ms
```

Current sampled plans are fast (0.278ms), but cumulative stats show 11 hours of total DB time across 2M calls.

**Fix (composite index):** `CREATE INDEX CONCURRENTLY ON session_occurrence (session_id, start_time, end_time);` -- collapses BitmapAnd into single index seek.

**Fix (application):** Split continuous vs non-continuous schedule queries (the CASE branch pattern hides two distinct access patterns).

### 2.4 `user_session` WHERE user_id -- 244ms parallel full-table scan

*Found by: Phase 2 (Claude)* | Tracked in: [#493](https://github.com/avantifellows/db-service/issues/493)

**EXPLAIN ANALYZE:**
```
Parallel Seq Scan on user_session
  Filter: (user_id = 297513)
  Rows Removed by Filter: 1,301,272 (per worker, 3 workers)
Execution Time: 243.702 ms
```

3.9M-row, 407MB table. Has pkey + `session_occurrence_id` index, but **no index on `user_id`**. Every user lookup = parallel sequential scan.

**Fix:** `CREATE INDEX CONCURRENTLY ON user_session (user_id);`

### 2.5 `session_occurrence` JOIN session with CASE -- temp spill and non-sargable predicate

*Found by: Phase 2 (Codex)*

**Stats:** 421K calls, 6,793 seconds (1.9 hours) total, 16.1ms mean, 53 rows/call, 304MB temp data spilled

```sql
SELECT ... FROM session_occurrence JOIN session
WHERE CASE WHEN session.repeat_schedule->>'type' = 'continuous'
          THEN start_time <= $1 AND end_time >= $2
          ELSE start_time >= $3 AND start_time <= $4
     END
  AND session_id = ANY($5)
ORDER BY id LIMIT/OFFSET
```

The `CASE` hides two distinct access patterns behind one predicate, making targeted time-based index access impossible.

**Fix:** Split into `UNION ALL` of two separate queries (continuous vs non-continuous), or two separate application queries. Each branch can then use an optimized index path.

### 2.6 Session lookups -- extremely chatty (297M calls)

*Found by: Phase 1*

```
Query: SELECT ... FROM session WHERE ...
Calls: 297.2 million
Total time: 8,912 seconds (2.5 hours)
Mean time: 0.03ms per call
```

While individually fast (0.03ms), the sheer volume (297M calls) suggests the application is doing excessive session lookups. This is likely called in a tight loop or on every request without caching.

### 2.7 Oban polling -- extremely chatty

*Found by: Phase 1*

```
pg_notify calls: 28.0 million
Oban queue select: 23.3 million calls
Oban job state update: 23.3 million calls
```

Oban's background polling generates massive query volume. Consider increasing Oban's poll interval if it's set aggressively low.

### 2.8 `form_schema` with OFFSET pagination

*Found by: Phase 1*

```
Query: SELECT ... FROM form_schema ORDER BY id LIMIT $1 OFFSET $2
Calls: 175K
Mean time: 10.17ms
Rows/call: 29.20
```

OFFSET-based pagination becomes increasingly expensive as offset grows. Consider keyset/cursor-based pagination.

---

## 3. Indexes -- Missing, Unused, Duplicate, and Optimization

**Severity: HIGH**
*Source: Phase 1 + Phase 2*

### 3.1 Missing Indexes (37 FK columns lack indexes)

*Found by: Phase 1, confirmed and extended by Phase 2*

**Most impactful missing indexes:**

| Table | Column(s) | Rows | Impact |
|---|---|---|---|
| **group_user** | `(group_id, user_id)` composite | 1.8M | **#1 slow query -- 23 hrs cumulative** |
| **user_session** | `user_id` | 3.9M | **Largest table, 244ms full-table scan (Phase 2)** |
| **user_session** | `session_id` | 3.9M | Largest table, FK unindexed |
| **session_occurrence** | `(session_id, start_time, end_time)` composite | 802K | **#3 slow query -- 11 hrs cumulative** |
| enrollment_record | `subject_id` | 2.4M | |
| school | `user_id` | 10K | |
| school_batch | `batch_id`, `school_id` | 4.2K | |
| chapter_curriculum | `chapter_id`, `curriculum_id` | 322 | 100% seq scan rate |
| topic_curriculum | `topic_id`, `curriculum_id` | 376 | 100% seq scan rate |
| resource | `teacher_id` | -- | |
| problem_lang | `res_id`, `lang_id` | 291 | 98.8% seq scan rate |
| student_exam_record | `student_id`, `exam_id` | 4.2K | |
| resource_concept | `resource_id`, `concept_id` | -- | Has PK on `id` only, no FK indexes |
| batch | `parent_id`, `program_id` | -- | |
| session | `signup_form_id`, `popup_form_id` | 16.6K | |
| teacher | `subject_id` | 3K | |
| topic | `chapter_id` | 376 | |
| chapter | `grade_id`, `subject_id` | 333 | |
| concept | `topic_id` | -- | |
| program | `product_id` | -- | |
| subject | `parent_id` | -- | |
| alumni | `branch_id_pg`, `branch_id_ug`, `college_id_pg`, `college_id_ug` | -- | |
| cutoffs | `college_id`, `branch_id`, `demographic_profile_id` | -- | |
| learning_objective | `concept_id` | -- | |

### 3.2 Duplicate Indexes

*Found by: Phase 1 + Phase 2*

**session_occurrence (found Phase 1, confirmed Phase 2):**
| Index | Column | Size | Scans |
|---|---|---|---|
| `session_occurence_session_id_index` (typo) | `session_fk` | 11 MB | 1,412 |
| `session_occurrence_session_fk_index` | `session_fk` | 6.4 MB | 247,403 |

**user_permission (newly found by Phase 2/Codex):**
| Index | Column |
|---|---|
| `idx_user_permission_email` | `lower(email)` |
| `user_permission_lower_email_index` | `lower(email)` |

### 3.3 Unused or Near-Zero-Scan Indexes

*Found by: Phase 1, extended by Phase 2*

These indexes have zero or negligible scan counts since stats reset on 2024-06-19, while adding write overhead on every INSERT/UPDATE.

| Index | Table | Size | Scans | Status |
|---|---|---|---|---|
| `enrollment_record_group_type_index` | enrollment_record | 22 MB | 114 | Near-zero (Phase 2) |
| `enrollment_record_academic_year_index` | enrollment_record | 21 MB | 11 | Near-zero |
| `enrollment_record_is_current_index` | enrollment_record | 20 MB | 0 | Zero |
| `user_email_phone_index` | user | 18 MB | 0 | Zero |
| `user_phone_index` | user | 13 MB | 6 | Near-zero |
| `user_email_index` | user | 6.3 MB | 0 | Zero |
| `student_grade_id_index` | student | 5 MB | 18 | Near-zero |
| `user_date_of_birth_index` | user | 5 MB | 31 | Near-zero |
| `branch_name_index` | branch | 112 kB | 0 | Zero |
| `oban_jobs_args_index` | oban_jobs | 72 kB | 0 | Zero |
| `oban_jobs_meta_index` | oban_jobs | 24 kB | 0 | Zero (Phase 2) |
| `candidate_subject_id_index` | candidate | 64 kB | 0 | Zero |
| `school_program_ids_index` | school | 48 kB | 0 | Zero |
| `resource_cms_status_id_index` | resource | 16 kB | 0 | Zero |
| `chapter_cms_status_id_index` | chapter | 16 kB | 0 | Zero |
| `topic_cms_status_id_index` | topic | 16 kB | 0 | Zero |
| `resource_curriculum_subject_id_index` | resource_curriculum | 16 kB | 0 | Zero |
| `resource_curriculum_grade_id_index` | resource_curriculum | 16 kB | 0 | Zero |

**Total reclaimable: ~110 MB** (deduplicated across Phase 1 and Phase 2 lists). 13 indexes have exactly zero scans; 5 have negligible scans (6-114) over 10+ months of stats collection.

### 3.4 Tables with 100% or Near-100% Sequential Scans

*Found by: Phase 1*

| Table | Seq Scans | Idx Scans | Seq % | Rows |
|---|---|---|---|---|
| chapter_curriculum | 1,130,553 | 12 | **100%** | 322 |
| topic_curriculum | 56,450 | 0 | **100%** | 376 |
| student_exam_record | 7,888 | 51 | **99.4%** | 4.2K |
| problem_lang | 1,759 | 22 | **98.8%** | 291 |
| topic | 67,401 | 13,155 | **83.7%** | 376 |
| imports | 2,532,051 | 1,256,358 | **66.8%** | 2.3K |
| school_batch | 9,469 | 5,650 | **62.6%** | 4.2K |
| resource_topic | 945,095 | 826,292 | **53.4%** | 366 |
| student | 26,387,361 | 29,862,127 | **46.9%** | 487K |

The `student` table having 26.4M sequential scans is likely influenced by `random_page_cost = 4.0` (see finding 1.1), which causes the planner to over-penalize index scans. Fixing that setting should shift some of these to index scans. Adding missing indexes on the 100% seq-scan tables (chapter_curriculum, topic_curriculum) will have a more direct effect on those specific tables.

### 3.5 Index Correlation Analysis

*Found by: Phase 2*

| Table | Column | Correlation | Meaning |
|---|---|---|---|
| student.mother_name | 0.014 | Near-random physical order |
| student.apaar_id | -0.016 | Near-random |
| student.student_id | -0.257 | Poor -- range scans very expensive |
| enrollment_record.group_id | 0.211 | Poor -- explains 263ms Bitmap Heap Scan |
| enrollment_record.group_type | 0.294 | Poor |
| enrollment_record.user_id | 0.625 | Moderate |
| enrollment_record.is_current | 0.781 | Good (but index has 0 scans) |
| enrollment_record.academic_year | 0.934 | Excellent |
| group_user.group_id | 0.376 | Poor |
| group_user.user_id | 0.883 | Good |
| session_occurrence.session_id | 0.247 | Poor |
| session_occurrence.start_time | 0.642 | Moderate |
| user.email | 0.025 | Near-random |
| user.phone | -0.048 | Near-random |

**Key insight:** `enrollment_record.group_id` correlation of 0.211 explains why `WHERE group_id=2` takes 263ms -- the 319K bitmap hits scatter across 13,904 heap blocks. Index scans on poorly-correlated columns are expensive due to random I/O.

### 3.6 Partial Index Opportunity -- enrollment_record.is_current

*Found by: Phase 2*

**Distribution (verified):**
```
is_current = true:   2,000,642 (83%)
is_current = false:    409,612 (17%)
```

The standalone `enrollment_record_is_current_index` (20MB) has **zero lifetime scans** because 83% selectivity is useless. But `is_current=true` is always combined with `user_id` or `group_id` in real queries.

**Fix:** Drop standalone index. Create partial composite:
```sql
CREATE INDEX CONCURRENTLY enrollment_record_group_current_idx
ON enrollment_record (group_id, user_id)
WHERE is_current = true;
```

### 3.7 Sparse Column Partial Indexes

*Found by: Phase 2 (Codex)*

**Verified distributions:**
```
user.email NOT NULL:      41,209 of 495,570 (8.32%)
user.phone NOT NULL:     270,189 of 495,570 (54.52%)
student.apaar_id NOT NULL: 54,582 of 486,952 (11.21%)
```

`user.email` and `student.apaar_id` are sparse enough that retained indexes should be partial on `IS NOT NULL` -- significantly smaller indexes with better selectivity.

### 3.8 Covering Index Opportunities (Visibility Map Dependence)

*Found by: Phase 2 (Codex)*

**Visibility map coverage (index-only scan viability):**

| Table | All-Visible % | IOS Viability |
|---|---|---|
| user_session | 88.25% | Good |
| session_occurrence | 78.76% | Good |
| group_user | 52.45% | Marginal |
| enrollment_record | 41.39% | Poor |
| student | 35.51% | Poor |
| user | 20.83% | Very poor |

Covering indexes (INCLUDE columns) will only help for `user_session` and `session_occurrence` where visibility map coverage is high. For other tables, frequent autovacuum is needed first to restore visibility.

---

## 4. Write Performance -- Amplification & HOT Updates

**Severity: HIGH**
*Source: Phase 2*

### 4.1 HOT Update Ratios -- verified from production

| Table | Updates | HOT Updates | HOT % | Index Count | Assessment |
|---|---|---|---|---|---|
| enrollment_record | 1,967,194 | 198,717 | **10.1%** | 6 | Critical -- 89.9% non-HOT |
| group_user | 213,165 | 12,146 | **5.7%** | 3 | Critical |
| session_occurrence | 103,057 | 746 | **0.7%** | 6 | Critical -- essentially zero HOT |
| student | 791,611 | 332,736 | **42.0%** | 5 | Poor |
| session | 37,351 | 15,075 | **40.4%** | -- | Poor |
| resource | 7,421 | 1,827 | **24.6%** | -- | Poor |
| user | 879,185 | 803,041 | **91.3%** | 5 | Good |
| oban_peers | 1,648,430 | 1,646,691 | **99.9%** | -- | Excellent |
| imports | 635,208 | 632,050 | **99.5%** | -- | Excellent |

**Key insight:** `enrollment_record` has the worst profile -- highest total writes AND lowest HOT ratio on the most indexed table. Each non-HOT update writes new entries in all 6 indexes. 1.77M non-HOT updates x 6 indexes = ~10.6M index entry writes contributing to write amplification. Not all are avoidable, but dropping unused indexes (is_current, academic_year) and reducing fillfactor would meaningfully reduce this overhead.

All tables use **default fillfactor (100)** -- no room reserved for HOT updates.

### 4.2 Write Patterns -- enrollment_record dominates

| Table | Inserts | Updates | Deletes | Total Writes |
|---|---|---|---|---|
| enrollment_record | 2,280,489 | 1,967,194 | 8,948 | **4,256,631** |
| user_session | 3,835,707 | 0 | 49 | **3,835,756** |
| group_user | 1,725,365 | 213,165 | 15,894 | **1,954,424** |
| session_occurrence | 1,066,448 | 103,057 | 315,689 | **1,485,194** |
| user | 419,977 | 879,185 | 2,620 | **1,301,782** |
| student | 411,383 | 791,612 | 2,607 | **1,205,602** |

**user_session** is purely insert-only (0 updates) -- its HOT ratio is irrelevant. But both FK columns (`session_id`, `user_id`) are unindexed despite being the largest table.

### 4.3 WAL Generation Rate

*Found by: Phase 2 (Codex)*

```
Since reset (2024-06-19): 30 GB WAL, ~554 bytes/sec average
Recent 6hr sample: avg 227 KB/s, max burst 1.1 MB/s
```

WAL generation is low. Not a bottleneck.

### 4.4 Trigger Analysis

*Found by: Phase 2 (Codex)*

Only one non-internal trigger: `oban_notify` on `oban_jobs` (AFTER INSERT, sends pg_notify). Not a bottleneck.

**Fix (write amplification):** For tables with poor HOT ratios (`enrollment_record`, `group_user`, `session_occurrence`), test lower fillfactor (e.g., 80-90) on staging. Drop unused indexes (especially `enrollment_record_is_current_index`) to reduce index churn.

---

## 5. Bloat, Autovacuum & Visibility Map

**Severity: HIGH**
*Source: Phase 1 + Phase 2*

### 5.1 Tables with Stale Autovacuum

*Found by: Phase 1, extended by Phase 2 with threshold analysis*

| Table | Live Tuples | Dead Tuples | Dead % | Last Autovacuum | % to Vacuum Trigger (10%) |
|---|---|---|---|---|---|
| enrollment_record | 2,409,913 | 178,570 | 6.9% | **2025-10-04 (6 months ago)** | 74% |
| session_occurrence | 801,519 | 50,133 | 5.9% | **2025-08-04 (8 months ago)** | 63% |
| user | 495,473 | 38,749 | 7.3% | 2025-12-06 (4 months ago) | 78% |
| group_user | 1,847,929 | 65,341 | 3.4% | 2026-01-13 (3 months ago) | -- |
| student | 486,861 | 19,229 | 3.8% | 2026-01-15 | -- |

**No manual VACUUM has ever been run on any table** (vacuum_count = 0 across the board).

Tables are approaching but not crossing the 10% threshold. For high-write tables on small infrastructure, this is too conservative.

### 5.2 `oban_peers` -- 14 MB for 1 row (97.96% dead tuples)

*Found by: Phase 1*

The `oban_peers` table has bloated to 14 MB (1,740 pages) while holding only 1 row. It has had ~228,660 autovacuums but the table is not being compacted because regular autovacuum does not reclaim disk space -- only `VACUUM FULL` does. Dead tuple ratio fluctuates around 95% due to frequent Oban leader election updates.

**Fix:** `VACUUM FULL oban_peers;` -- reclaims ~14 MB instantly.

### 5.3 Small Tables with Extreme Dead Tuple Ratios

*Found by: Phase 1*

| Table | Dead % | Last Autovacuum |
|---|---|---|
| subject | 58.5% | Never |
| curriculum | 47.6% | Never |
| form_schema | 41.4% | Never |
| chapter | 16.8% | -- |
| batch | 11.9% | Never |

These are small tables so the storage impact is minimal, but the dead tuples affect query statistics accuracy.

### 5.4 Autovacuum Tuning Needed for Large Tables

*Found by: Phase 1, with refined thresholds from Phase 2*

Current `autovacuum_vacuum_scale_factor = 0.1` means vacuum doesn't trigger on `user_session` (3.9M rows) until ~390K dead tuples accumulate.

**Fix (Phase 2 refined):** Per-table overrides:
```sql
ALTER TABLE user_session SET (autovacuum_vacuum_scale_factor = 0.01, autovacuum_analyze_scale_factor = 0.01);
ALTER TABLE enrollment_record SET (
  autovacuum_vacuum_scale_factor = 0.01,
  autovacuum_vacuum_threshold = 1000
);
ALTER TABLE group_user SET (autovacuum_vacuum_scale_factor = 0.02, autovacuum_analyze_scale_factor = 0.01);
ALTER TABLE session_occurrence SET (
  autovacuum_vacuum_scale_factor = 0.01,
  autovacuum_vacuum_threshold = 500
);
```

Also consider increasing `autovacuum_vacuum_cost_limit` from 200 to 400-800 to let autovacuum work faster.

### 5.5 Modification Ratios (Visibility Map Health)

*Found by: Phase 2 (Claude)*

| Table | Updates+Deletes | Live Rows | Mod Ratio |
|---|---|---|---|
| user | 881,806 | 495,566 | 177.9% |
| student | 794,219 | 486,953 | 163.1% |
| enrollment_record | 1,976,142 | 2,410,281 | 82.0% |
| session_occurrence | 418,746 | 801,519 | 52.2% |

Several high-traffic tables have very high modification ratios; `user` (177.9%) and `student` (163.1%) exceed 100%, while `enrollment_record` (82.0%) and `session_occurrence` (52.2%) are also significant. The visibility map is frequently invalidated on these tables, reducing index-only scan effectiveness. Frequent autovacuum is essential.

---

## 6. Storage & TOAST Analysis

**Severity: MEDIUM**
*Source: Phase 2*

### 6.1 TOAST Table Sizes

| Table | JSONB Column | TOAST Size | Avg Bytes | Over 2KB |
|---|---|---|---|---|
| problem_lang | meta_data | 3,160 kB | 10,916 | 46 rows |
| form_schema | attributes | 632 kB | 11,731 | 30 rows |
| session | meta_data | 72 kB | 774 | 0 rows |
| user_session | data | 8 kB | 5 | 0 rows |

**Finding:** TOAST is not the cause of the largest table costs. `user_session.data` averages 5 bytes per row -- not a JSONB problem. The true TOAST outliers are tiny tables in absolute size.

### 6.2 Tuple Widths

| Table | Rows | Avg Tuple Bytes | Wide? |
|---|---|---|---|
| session | 16,575 | 1,266 | Yes -- widest common table |
| student | 486,952 | 131 | Moderate |
| session_occurrence | 801,515 | 122 | Moderate |
| user_session | 3,903,585 | 104 | Narrow |
| enrollment_record | 2,410,251 | 99 | Narrow |
| group_user | 1,848,290 | 64 | Very narrow |

The largest tables are narrow. Their cost is high row count, repeated lookups, and index/update churn -- not wide rows.

---

## 7. Advanced Query Patterns

**Severity: MEDIUM**
*Source: Phase 1 + Phase 2*

### 7.1 `student` table -- 2.67 trillion tuples read via sequential scan

*Found by: Phase 2 (Claude)*

26.4M sequential scans on a 487K-row, 68MB table, with `seq_tup_read` of 2.67 trillion cumulative tuples read (from `pg_stat_user_tables`). The seq scan rate is 46.9% despite having multiple indexes (`student_id`, `user_id`, `apaar_id`, `grade_id`, `uuid`). The high tuple-read count indicates many of these scans touch large portions of the table.

This suggests queries filtering by unindexed columns like `stream`, `category`, or `grade_id` (only 18 index scans on `grade_id`), or bulk export queries that read all students without a filter. The `random_page_cost=4.0` misconfiguration (Section 1.1) also contributes by biasing the planner toward seq scans.

**Fix:** Audit which application queries trigger full student table scans. Add indexes on commonly filtered columns. Fix `random_page_cost` (Section 1). Add pagination to any bulk export endpoints.

### 7.2 `form_schema` -- 628K sequential scans, only pkey index

*Found by: Phase 2 (Claude)*

`form_schema` has 628K sequential scans with only a primary key index. pg_stat_statements shows 175K calls at 10.17ms avg for `SELECT ... FROM form_schema ORDER BY id LIMIT/OFFSET`.

**Fix:** If queries filter by `name`, add `CREATE INDEX ON form_schema (name)`.

### 7.3 `chapter_curriculum` -- 1.13M sequential scans on 322 rows

*Found by: Phase 2 (Claude)*

A tiny, effectively static table scanned 1.13M times. Should be ETS-cached in the application.

### 7.4 Over-fetching List Endpoints

*Found by: Phase 2 (Codex)*

| Query | Calls | Rows/Call | Mean ms |
|---|---|---|---|
| `SELECT ... FROM school WHERE state=$1` | 744 | **1,080** | 6.0 |
| `SELECT ... FROM batch ORDER BY id LIMIT/OFFSET` | 34,521 | **811** | 1.1 |
| `SELECT ... FROM session WHERE platform=$3` | 108,223 | **54** | 0.9 |
| `session_occurrence JOIN session CASE` | 421,656 | **53** | 16.1 |

These are list endpoints returning broad rows with offset pagination. The school endpoint returns 1,080 rows on average per call.

**Fix:** Keyset pagination and endpoint-specific narrow projections.

### 7.5 Recursive Batch Hierarchy Query

*Found by: Phase 2 (Codex)*

```
calls=601,683 | total=675 seconds | mean=1.12ms | rows/call=2.05
WITH RECURSIVE batch_hierarchy AS (...) JOIN group_user, group, batch
```

**Fix:** Maintain a batch/group closure or membership cache table instead of recursive CTEs.

### 7.6 Import Status Count -- Constant Polling

*Found by: Phase 2 (Codex)*

```
calls=383,744 | mean=1.9ms
SELECT status, count(id) FROM imports GROUP BY status
```

A 20MB table queried 383K times for status counts. This should be cached at the application layer or maintained in a summary counter.

### 7.7 `oban_jobs` Small-Table Churn

*Found by: Phase 2 (Codex)*

The `oban_notify` trigger is not a bottleneck, but `oban_jobs` still has small-table churn with non-HOT updates and zero-scan GIN indexes (`oban_jobs_args_index`, `oban_jobs_meta_index`). These GIN indexes add write overhead on every job insert for zero read benefit.

### 7.8 Partitioning Guidance

*Found by: Phase 2 (Codex)*

Credible partitioning candidates:
- **`user_session`** by timestamp -- only if reads and retention are time-windowed
- **`enrollment_record`** by lifecycle/date -- only if queries naturally constrain `start_date`, `end_date`, or academic period
- **`session_occurrence`** by time -- only if most queries are time-bounded and can avoid global `ORDER BY id`

**Do NOT partition `group_user`** -- it is relationship-driven, and reducing repeated membership probes is a better optimization than partitioning.

---

## 8. AWS / Infrastructure

**Severity: MEDIUM**
*Source: Phase 1 + Phase 2*

### 8.1 Instance is Publicly Accessible

*Found by: Phase 1*

`PubliclyAccessible: true` -- the database has a public IP and is reachable from the internet (subject to security group rules). For a production database, this is a **security risk**.

**Fix:** Move to a private subnet and access via bastion host or VPN.

### 8.2 Recent Downsize Depleted CPU Credits

*Found by: Phase 1*

The instance was downsized from db.t4g.2xlarge to db.t4g.large on 2026-04-24 at 19:54 UTC. The credit balance dropped from 4608 to near-zero (minimum 1.08 credits). It's recovering but is still at ~210 credits vs. 4608 max.

**Current risk:** At current low CPU usage (~5.5% average), credits are recovering (currently ~220-245 credits, up from near-zero). But a sustained CPU spike before full recovery could throttle the instance.

### 8.3 Default Parameter Group -- No Tuning Applied

*Found by: Phase 1*

Using `default.postgres14` with zero modifications. All the findings in Section 1 stem from this.

**Fix:** Create a custom parameter group, apply all the changes from Section 1, and associate it with the instance.

### 8.4 Storage Type is gp2, Not gp3

*Found by: Phase 1*

gp2 provides 3 IOPS/GB baseline (= 444 IOPS for 148 GB). gp3 provides 3000 baseline IOPS at similar or lower cost, decoupled from storage size.

**Fix:** Migrate to gp3 for better baseline IOPS and cost efficiency. Can be done online via `modify-db-instance`.

### 8.5 Enhanced Monitoring is Disabled

*Found by: Phase 1*

No OS-level metrics (memory breakdown, process list, swap details). Only basic CloudWatch metrics are available.

**Fix:** Enable Enhanced Monitoring at 60-second intervals.

### 8.6 No Multi-AZ

*Found by: Phase 1*

Single-AZ deployment means any AZ failure causes downtime. Acceptable for the current workload but worth noting.

### 8.7 AWS Performance Insights -- Wait Event Summary (7-day)

*Found by: Phase 2 (Codex)*

| Wait Event | Avg Wait (fraction of vCPU) |
|---|---|
| Client:ClientRead | 0.0016 |
| CPU | 0.0013 |
| Client:ClientWrite | 0.0007 |
| IPC:MessageQueueSend | 0.0005 |
| IO:WALSync | 0.00004 |

**Finding:** PI does not show current saturation. The database is not pinned on CPU or IO. The performance issues are cumulative inefficiency from repeated application query patterns, not resource exhaustion.

**Current Load:**
```
db.load.avg: 0.01 - 0.05 (baseline), 0.52 (brief spike)
```

Database load is minimal. The instance has ample headroom.

### 8.8 PostgreSQL Version

*Found by: Phase 1*

Running 14.17. PostgreSQL 16 is available on RDS. Plan an upgrade path -- PG14 is still supported but nearing end of community support (Nov 2026).

---

## 9. Logging & Observability Gaps

**Severity: MEDIUM**
*Source: Phase 1*

### 9.1 No Slow Query Logging

`log_min_duration_statement = -1` (disabled). There is **zero visibility into slow queries** via logs. The only way to identify them is pg_stat_statements (which is installed, fortunately).

**Fix:** Set `log_min_duration_statement = 1000` (log queries > 1 second).

### 9.2 No Lock Wait Logging

`log_lock_waits = off`. Lock contention is invisible.

**Fix:** Set `log_lock_waits = on`.

### 9.3 No Temp File Logging

`log_temp_files = -1` (disabled). Cannot identify queries spilling to disk via logs.

**Fix:** Set `log_temp_files = 0` (log all temp file usage).

### 9.4 Application Connections Have No `application_name`

All 11 idle connections show no `application_name` in pg_stat_activity. This makes it impossible to distinguish which application or service holds which connection.

**Fix:** Set `application_name` in the Ecto Repo config:
```elixir
config :dbservice, Dbservice.Repo,
  parameters: [application_name: "dbservice"]
```

---

## 10. Healthy Baselines (No Action Required)

*Source: Phase 1*

| Finding | Value | Status |
|---|---|---|
| Connection usage | 20 of 838 (2.4%) | Healthy |
| Buffer cache hit ratio | 100.0% | Excellent |
| Index cache hit ratio | 100.0% | Excellent |
| Lock contention | None detected | OK |
| Long-running queries | None detected | OK |
| Transaction ID wraparound | 20.8M / 200M (10.42%) | Healthy |
| Checkpoint activity | 99.99% timed, 2.47% backend writes | Healthy |
| Disk read IOPS | 0.26-0.55 avg | Minimal |
| Disk write IOPS | 4-6 avg | Minimal |
| Burst balance | 99.4-99.9% | Not a bottleneck |
| WAL generation | 30 GB cumulative, ~554 bytes/sec avg | Low |

---

## 11. Database Stats Overview

*Source: Phase 1, supplemented by Phase 2*

### Table Sizes (top 10)

| Table | Rows | Total Size | Table Size | Index Size |
|---|---|---|---|---|
| user_session | 3,901,889 | 529 MB | 407 MB | 122 MB |
| enrollment_record | 2,409,915 | 439 MB | 247 MB | 192 MB |
| group_user | 1,847,931 | 213 MB | 125 MB | 89 MB |
| session_occurrence | 801,519 | 168 MB | 104 MB | 64 MB |
| student | 486,861 | 134 MB | 68 MB | 66 MB |
| user | 495,474 | 114 MB | 60 MB | 53 MB |
| session | 16,575 | 26 MB | 23 MB | 2.5 MB |
| imports | 2,253 | 20 MB | 20 MB | 56 kB |
| oban_peers | 1 | 14 MB | 14 MB | 64 kB |
| college | 53,254 | 11 MB | 8.5 MB | 2.7 MB |

### Connection Stats

| Metric | Value |
|---|---|
| Total connections | 20 |
| Max connections | 838 |
| Active | 1 |
| Idle | 13 |
| Idle in transaction | 0 |
| Usage | 2.4% |

### Cache Performance

| Metric | Hit Ratio |
|---|---|
| Buffer cache | 100.00% |
| Index cache | 100.00% |

---

## 12. Prioritized Action Plan

Phase 2 priorities take precedence. The ORDER BY fix is Tier 1 #1 based on Phase 2's verified 565x speedup.

### Tier 1 -- Immediate (minutes, massive impact)

| # | Action | Impact | Source | Requires Reboot |
|---|---|---|---|---|
| 1 | Application: stop using `ORDER BY id` for temporal session_occurrence queries; use `ORDER BY end_time` or keyset pagination | **565x speedup** (256ms to 0.45ms) -- highest single-query impact | Phase 2 | No (code change) |
| 2 | `CREATE INDEX CONCURRENTLY ON group_user (group_id, user_id)` | Fixes #1 slow query (23 hours cumulative) | Both | No |
| 3 | `CREATE INDEX CONCURRENTLY ON user_session (user_id)` | Fixes 244ms full-table scan on largest table | Phase 2 | No |
| 4 | `CREATE INDEX CONCURRENTLY ON session_occurrence (session_id, start_time, end_time)` | Fixes #3 slow query (11 hours cumulative) + eliminates BitmapAnd | Both (Phase 2 refined) | No |
| 5 | Create custom parameter group: `random_page_cost = 1.1` | Fixes query plans for every query | Phase 1 | No |
| 6 | Set `effective_cache_size = 6GB` | Better index scan selection | Phase 1 | No |
| 7 | Set `work_mem = 16MB` | Reduces future temp file spills (5.5 TB cumulative since reset) | Phase 1 | No |
| 8 | Set `effective_io_concurrency = 200` | Leverages SSD parallelism | Phase 1 | No |
| 9 | `DROP INDEX CONCURRENTLY session_occurence_session_id_index` | Remove 11MB duplicate | Both | No |
| 10 | `DROP INDEX CONCURRENTLY enrollment_record_is_current_index` | Remove 20MB zero-scan index, reduce write amplification | Both | No |
| 11 | Set `log_min_duration_statement = 1000` | Enables slow query visibility | Phase 1 | No |

### Tier 2 -- Short Term (hours, high impact)

| # | Action | Impact | Source |
|---|---|---|---|
| 12 | Create partial composite: `enrollment_record (group_id, user_id) WHERE is_current = true` | Targeted current-enrollment lookups | Phase 2 |
| 13 | Drop additional low-value indexes (academic_year 21MB, group_type 22MB, user_email_phone 18MB, user_phone 13MB, user_email 6.3MB, student_grade_id 5MB, user_date_of_birth 5MB, oban GIN indexes, others) | ~110MB total reclaimable, reduced write amplification | Both |
| 14 | Drop duplicate `user_permission` lower(email) index | Remove write overhead | Phase 2 |
| 15 | Add missing FK indexes on `user_session(session_id)` | Index on largest table | Phase 1 |
| 16 | Add indexes on `chapter_curriculum`, `topic_curriculum` FK columns | Fixes 100% seq scan tables | Phase 1 |
| 17 | Set per-table autovacuum overrides on enrollment_record, session_occurrence, user_session, group_user | Prevent dead tuple accumulation | Both |
| 18 | `VACUUM FULL oban_peers` | Reclaims 14 MB from 1-row table | Phase 1 |
| 19 | `VACUUM ANALYZE enrollment_record` | 178K dead tuples, 6 months stale | Phase 1 |
| 20 | `VACUUM ANALYZE session_occurrence` | 50K dead tuples, 8 months stale | Phase 1 |
| 21 | Set `maintenance_work_mem = 256MB` | Faster VACUUM/index operations | Phase 1 |
| 22 | Set `log_lock_waits = on`, `log_temp_files = 0` | Better observability | Phase 1 |
| 23 | Set `statement_timeout = 30000` | Protect against runaway queries | Phase 1 |
| 24 | Set `idle_in_transaction_session_timeout = 300000` | Prevent stale txns | Phase 1 |
| 25 | Investigate student table 26.4M seq scans -- audit application queries | 2.67 trillion tuples read via seq scan | Phase 2 |
| 26 | Add index on `form_schema(name)` if queries filter by name | Reduce 628K seq scans | Phase 2 |

### Tier 3 -- Medium Term (days, architectural)

| # | Action | Impact | Source |
|---|---|---|---|
| 27 | Narrow `student` SELECT projections for hot paths | Reduce broad row transfers on 12.2M lookups | Phase 2 |
| 28 | ETS-cache chapter_curriculum (322 rows, 1.13M scans) | Eliminate 1.13M seq scans | Phase 2 |
| 29 | Split CASE-based session_occurrence JOIN into two queries | Enable targeted index access per branch | Phase 2 |
| 30 | Cache import status counts at app layer | Eliminate 383K polling queries | Phase 2 |
| 31 | Batch/cache group_user membership checks | Reduce 4.6M individual lookups | Phase 2 |
| 32 | Test lower fillfactor (80-90) on high-churn tables in staging | Improve HOT update ratios | Phase 2 |
| 33 | Maintain batch/group closure table for recursive hierarchy | Replace 601K recursive CTE calls | Phase 2 |
| 34 | Set `max_connections = 150` | Frees memory | Phase 1 (requires reboot) |
| 35 | Migrate storage from gp2 to gp3 | Better baseline IOPS, lower cost | Phase 1 |
| 36 | Make instance private (not publicly accessible) | Security | Phase 1 |
| 37 | Enable Enhanced Monitoring | OS-level metrics | Phase 1 |
| 38 | Add `application_name` to Ecto config | Connection observability | Phase 1 |
| 39 | Investigate Oban poll interval (28M pg_notify calls) | Reduce background noise | Phase 1 |
| 40 | Plan PostgreSQL 14 to 16 upgrade | EOL Nov 2026 | Phase 1 |
| 41 | Evaluate partitioning for `user_session` (time-bounded) -- avoid partitioning `group_user` | Only if reads/retention are time-windowed | Phase 2 |

---

## 13. Master Finding Summary Table

Every finding from both investigation phases, organized by category with severity, source, and action plan reference.

| # | Category | Finding | Severity | Source | Action # |
|---|---|---|---|---|---|
| F1 | PG Config | `random_page_cost` = 4.0 (should be 1.1) | Critical | Phase 1 | 5 | Tracked in: #488 |
| F2 | PG Config | `effective_cache_size` = 3,809 MB (should be ~6 GB) | High | Phase 1 | 6 | Tracked in: #488 |
| F3 | PG Config | `work_mem` = 4 MB; 5.5 TB cumulative temp writes | High | Phase 1 | 7 | Tracked in: #488 |
| F4 | PG Config | `max_connections` = 838 (should be 100-150) | Medium | Phase 1 | 34 | Tracked in: #488 |
| F5 | PG Config | `effective_io_concurrency` = 1 (should be 200) | Medium | Phase 1 | 8 | Tracked in: #488 |
| F6 | PG Config | `maintenance_work_mem` = 125 MB (should be 256 MB) | Medium | Phase 1 | 21 | Tracked in: #488 |
| F7 | PG Config | `statement_timeout` disabled | Medium | Phase 1 | 23 | Tracked in: #488 |
| F8 | PG Config | `idle_in_transaction_session_timeout` = 24 hrs | Low | Phase 1 | 24 | Tracked in: #488 |
| F9 | Query Perf | `group_user` lookup: 4.58M calls, 23 hrs total | Critical | Both | 2 | Tracked in: #489 |
| F10 | Query Perf | `student` lookup: 12.2M calls, 20.7 hrs total, SELECT * | High (↓) | Both | 27 | Tracked in: #490 |
| F11 | Query Perf | `session_occurrence` ORDER BY id: 565x slower than ORDER BY end_time | Critical | Phase 2 | 1 | Tracked in: #491 |
| F12 | Query Perf | `session_occurrence` with session_id: 2.05M calls, 11 hrs total | Critical | Both | 4 | Tracked in: #492 |
| F13 | Query Perf | `user_session` WHERE user_id: 244ms full-table scan | Critical | Phase 2 | 3 | Tracked in: #493 |
| F14 | Query Perf | `session_occurrence` JOIN session CASE: 421K calls, 1.9 hrs, 304MB temp | High | Phase 2 | 29 |
| F15 | Query Perf | Session lookups: 297M calls (chatty) | Medium | Phase 1 | -- |
| F16 | Query Perf | Oban polling: 28M pg_notify, 23.3M queue polls | Medium | Phase 1 | 39 |
| F17 | Query Perf | `form_schema` OFFSET pagination: 175K calls, 10ms mean | Medium | Phase 1 | 26 |
| F18 | Indexes | 37 FK columns lack indexes | High | Phase 1 | 2,3,4,15,16 |
| F19 | Indexes | Duplicate `session_occurrence` index (typo, 11 MB) | Medium | Both | 9 |
| F20 | Indexes | Duplicate `user_permission` lower(email) index | Medium | Phase 2 | 14 |
| F21 | Indexes | 18 unused/near-zero-scan indexes (~110 MB) | High | Both | 10,13 |
| F22 | Indexes | Tables with 100% seq scan rate (chapter_curriculum, topic_curriculum) | High | Phase 1 | 16 |
| F23 | Indexes | `student` table 46.9% seq scan rate (26.4M scans) | High | Both | 5,25 |
| F24 | Indexes | Index correlation analysis (poor correlation on hot columns) | Medium | Phase 2 | -- |
| F25 | Indexes | Partial index opportunity: enrollment_record.is_current | High | Phase 2 | 12 |
| F26 | Indexes | Sparse column partial indexes (user.email, student.apaar_id) | Medium | Phase 2 | -- |
| F27 | Indexes | Covering index viability limited by visibility map | Medium | Phase 2 | 17 |
| F28 | Write Perf | enrollment_record: 10.1% HOT ratio, 4.2M total writes | High | Phase 2 | 10,13,32 |
| F29 | Write Perf | session_occurrence: 0.7% HOT ratio | High | Phase 2 | 32 |
| F30 | Write Perf | group_user: 5.7% HOT ratio | High | Phase 2 | 32 |
| F31 | Write Perf | All tables use default fillfactor (100) | Medium | Phase 2 | 32 |
| F32 | Write Perf | WAL generation: 30 GB cumulative, low | Low | Phase 2 | -- |
| F33 | Write Perf | Only 1 non-internal trigger (oban_notify) | Low | Phase 2 | -- |
| F34 | Bloat | enrollment_record: 178K dead tuples, 6 months since vacuum | High | Phase 1 | 19 |
| F35 | Bloat | session_occurrence: 50K dead tuples, 8 months since vacuum | High | Phase 1 | 20 |
| F36 | Bloat | oban_peers: 14 MB for 1 row | Medium | Phase 1 | 18 |
| F37 | Bloat | Small tables with extreme dead tuple ratios (subject 58.5%, etc.) | Low | Phase 1 | -- |
| F38 | Bloat | Autovacuum 10% scale factor too conservative for large tables | High | Both | 17 |
| F39 | Bloat | Visibility map heavily invalidated on high-traffic tables | Medium | Phase 2 | 17 |
| F40 | TOAST | TOAST not a bottleneck; user_session.data avg 5 bytes | Low | Phase 2 | -- |
| F41 | TOAST | Largest tables are narrow; cost is row count not width | Low | Phase 2 | -- |
| F42 | Patterns | student table: 2.67 trillion tuples read via seq scan | High | Phase 2 | 25 |
| F43 | Patterns | form_schema: 628K seq scans, only pkey index | Medium | Phase 2 | 26 |
| F44 | Patterns | chapter_curriculum: 1.13M seq scans on 322 rows | Medium | Phase 2 | 28 |
| F45 | Patterns | Over-fetching list endpoints (school 1080 rows/call) | Medium | Phase 2 | -- |
| F46 | Patterns | Recursive batch hierarchy: 601K calls, 675 seconds | Medium | Phase 2 | 33 |
| F47 | Patterns | Import status polling: 383K calls | Medium | Phase 2 | 30 |
| F48 | Patterns | oban_jobs GIN indexes: zero scans, write overhead | Low | Phase 2 | 13 |
| F49 | Patterns | Partitioning guidance (user_session, enrollment_record viable; group_user not) | Low | Phase 2 | 41 |
| F50 | AWS | Instance publicly accessible | High | Phase 1 | 36 |
| F51 | AWS | CPU credits depleted after downsize | Medium | Phase 1 | -- |
| F52 | AWS | Default parameter group | Critical | Phase 1 | 5-8 | Tracked in: #488 |
| F53 | AWS | Storage gp2, not gp3 | Medium | Phase 1 | 35 |
| F54 | AWS | Enhanced Monitoring disabled | Medium | Phase 1 | 37 |
| F55 | AWS | No Multi-AZ | Low | Phase 1 | -- |
| F56 | AWS | Performance Insights: no saturation detected | Low | Phase 2 | -- |
| F57 | AWS | PostgreSQL 14.17 nearing EOL (Nov 2026) | Low | Phase 1 | 40 |
| F58 | Logging | No slow query logging | High | Phase 1 | 11 |
| F59 | Logging | No lock wait logging | Medium | Phase 1 | 22 |
| F60 | Logging | No temp file logging | Medium | Phase 1 | 22 |
| F61 | Logging | No application_name on connections | Low | Phase 1 | 38 |
| F62 | Healthy | Connection usage: 2.4% | OK | Phase 1 | -- |
| F63 | Healthy | Cache hit ratio: 100% | OK | Phase 1 | -- |
| F64 | Healthy | No lock contention | OK | Phase 1 | -- |
| F65 | Healthy | No long-running queries | OK | Phase 1 | -- |
| F66 | Healthy | XID wraparound: 10.42% | OK | Phase 1 | -- |
| F67 | Healthy | Checkpoints: 99.99% timed | OK | Phase 1 | -- |
| F68 | Healthy | Disk I/O minimal | OK | Phase 1 | -- |
| F69 | Healthy | Storage over-provisioned (4.6% used) | OK | Phase 1 | -- |
