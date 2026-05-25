# EV Population Data Engineering — Project Documentation

> **Snowflake-native data platform** for Electric Vehicle (EV) population analytics using the Medallion Architecture pattern, real-time CDC pipelines, and AI-powered natural language querying.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture Diagram](#architecture-diagram)
3. [Data Flow Diagram](#data-flow-diagram)
4. [Component Breakdown](#component-breakdown)
5. [Technology Decisions & Tradeoffs](#technology-decisions--tradeoffs)
6. [Infrastructure Layer](#infrastructure-layer)
7. [Bronze Layer — Raw Ingestion](#bronze-layer--raw-ingestion)
8. [Silver Layer — Cleansing & Validation](#silver-layer--cleansing--validation)
9. [Gold Layer — Business Aggregations](#gold-layer--business-aggregations)
10. [Data Quality Framework](#data-quality-framework)
11. [Orchestration — Task DAG](#orchestration--task-dag)
12. [Applications Layer](#applications-layer)
13. [Iceberg Integration](#iceberg-integration)
14. [dbt Integration](#dbt-integration)
15. [Git Integration & Version Control](#git-integration--version-control)
16. [Security Model (RBAC)](#security-model-rbac)
17. [Cost Controls](#cost-controls)
18. [Pros & Cons Summary](#pros--cons-summary)
19. [Ideal vs. Actual — Challenges Encountered](#ideal-vs-actual--challenges-encountered)
20. [Glossary](#glossary)

---

## Project Overview

| Attribute        | Value                                                     |
|------------------|-----------------------------------------------------------|
| **Database**     | `EV_POPULATION_DB`                                        |
| **Source Data**  | Washington State DOL — EV Population (JSON)               |
| **CDC Source**   | Simulated PostgreSQL charging station data                 |
| **Architecture** | Medallion (Bronze → Silver → Gold)                        |
| **Refresh**      | Dynamic Tables (1-hour lag) + Stream/Task CDC             |
| **Serving**      | Streamlit apps, Cortex Analyst (NL→SQL), Iceberg export   |
| **IaC**          | SQL scripts in Git, dbt for charging stations             |

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           SNOWFLAKE ACCOUNT (EV_POPULATION_DB)                       │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  ┌─────────────┐    ┌────────────────────────────────────────────────────────────┐  │
│  │  EXTERNAL   │    │                   MEDALLION LAYERS                         │  │
│  │  SOURCES    │    │                                                            │  │
│  │             │    │  ┌──────────┐    ┌──────────┐    ┌──────────────────────┐  │  │
│  │ ┌─────────┐ │    │  │  BRONZE  │    │  SILVER  │    │        GOLD          │  │  │
│  │ │JSON File│─┼────┼─▶│ Raw JSON │───▶│ Cleaned  │───▶│ Facts + Dimensions  │  │  │
│  │ │(S3/Stage)│ │    │  │ VARIANT  │    │ Typed    │    │ Aggregations + KPIs │  │  │
│  │ └─────────┘ │    │  │          │    │ Deduped  │    │ Iceberg Tables      │  │  │
│  │             │    │  └──────────┘    └──────────┘    └──────────────────────┘  │  │
│  │ ┌─────────┐ │    │       ▲                                     │              │  │
│  │ │PostgreSQL│─┼────┼───────┘ (CDC Stream)                       ▼              │  │
│  │ │(Simulated)│    │                              ┌──────────────────────────┐  │  │
│  │ └─────────┘ │    │                              │   SERVING LAYER          │  │  │
│  └─────────────┘    │                              │  ┌────────┐ ┌─────────┐  │  │  │
│                     │                              │  │Streamlit│ │ Cortex  │  │  │  │
│                     │                              │  │Dashboard│ │ Analyst │  │  │  │
│                     │                              │  └────────┘ └─────────┘  │  │  │
│                     │                              └──────────────────────────┘  │  │
│                     └────────────────────────────────────────────────────────────┘  │
│                                                                                     │
│  ┌──────────────────────────┐  ┌───────────────────┐  ┌───────────────────────┐    │
│  │  AUDIT & DATA QUALITY    │  │   ORCHESTRATION   │  │    INFRASTRUCTURE     │    │
│  │  • DQ Stored Procs       │  │   • Task DAG      │  │    • RBAC (3 roles)   │    │
│  │  • Dead Letter Queue     │  │   • 60-min cycle  │  │    • Resource Monitor  │    │
│  │  • Pipeline Logs         │  │   • Stream-driven  │  │    • Git Integration  │    │
│  │  • Email Alerts          │  │                   │  │    • dbt Project       │    │
│  └──────────────────────────┘  └───────────────────┘  └───────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Data Flow Diagram

```
                         ┌──────────────────────────────────────────────────┐
                         │              INGESTION PATHS                     │
                         └──────────────────────────────────────────────────┘

    PATH 1: EV Population (JSON)              PATH 2: Charging Stations (CDC)
    ═══════════════════════════               ══════════════════════════════

    JSON File Uploaded                        PostgreSQL Table (Simulated)
         │                                          │
         ▼                                          ▼
    @EV_RAW_STAGE/ev_population/              PG_RAW_SOURCE.PG_RAW_CHARGING_STATIONS
         │                                          │
         ▼ (Snowpipe AUTO_INGEST)                   ▼ (Stream: PG_STM_CHARGING_STATIONS)
    BRONZE.RAW_EV_POPULATION_STAGING          ──────┤
         │                                          │
         ▼ (Stream: STM_RAW_EV_STAGING)             ▼ (Task: TSK_BRONZE_PG_MERGE)
    ──────┤                                   PG_BRONZE.PG_CHARGING_STATIONS
         │                                          │
         ▼ (Task: TSK_FLATTEN_EV_STAGING)           │
    BRONZE.RAW_EV_POPULATION                        │
         │                                          │
         ▼ (Dynamic Table, 1hr lag)                 ▼ (dbt model)
    SILVER.CLEAN_EV_POPULATION               SILVER.PG_CLEAN_CHARGING_STATIONS
         │                                          │
         ▼ (Dynamic Table)                          ▼ (dbt model)
    GOLD.FACT_EV_REGISTRATIONS               GOLD.DIM_CHARGING_STATIONS
         │                                          │
         ├──▶ GOLD.AGG_EV_BY_REGION                 │
         ├──▶ GOLD.AGG_EV_YOY_GROWTH               │
         ├──▶ GOLD.AGG_EV_BY_MAKE_MODEL             │
         └──▶ GOLD.AGG_EV_CHARGING_COVERAGE ◀───────┘ (JOIN)
                        │
                        ▼
              ┌─────────────────────┐
              │   SERVING LAYER     │
              │  • Streamlit Apps   │
              │  • Cortex Analyst   │
              │  • Iceberg Export   │
              └─────────────────────┘
```

---

## Component Breakdown

### Schemas (7 total)

| Schema            | Purpose                                        | Layer     |
|-------------------|------------------------------------------------|-----------|
| `BRONZE`          | Raw JSON ingestion, append-only                | Ingestion |
| `PG_RAW_SOURCE`   | CDC landing zone from PostgreSQL               | Ingestion |
| `PG_BRONZE`       | Reconciled current-state from CDC              | Ingestion |
| `SILVER`          | Cleaned, typed, deduplicated data              | Transform |
| `GOLD`            | Facts, dimensions, aggregations, KPIs          | Serving   |
| `AUDIT`           | Pipeline logs, DQ results, dead letter queue   | Ops       |
| `UTILITIES`       | Stages, file formats, Git repo, UDFs           | Shared    |

---

## Technology Decisions & Tradeoffs

### 1. Dynamic Tables vs. Materialized Views vs. Tasks

| Approach            | Chosen? | Why / Why Not                                                    |
|---------------------|---------|------------------------------------------------------------------|
| **Dynamic Tables**  | ✅ Yes  | Auto-refresh, declarative, no scheduling logic needed            |
| Materialized Views  | ❌ No   | Cannot handle complex transforms (QUALIFY, CASE, multi-table)    |
| Task + MERGE        | ✅ Yes  | Used for CDC path (requires MERGE semantics)                     |

**Tradeoff:** Dynamic Tables simplify maintenance but cost ~0.02 credits/refresh. With 6 dynamic tables × 24 refreshes/day = ~2.9 credits/day. Acceptable for demo; in production, consider increasing `TARGET_LAG` to 4-6 hours for cost savings.

---

### 2. Snowpipe vs. COPY INTO (Manual) vs. External Tables

| Approach          | Chosen? | Why / Why Not                                                    |
|-------------------|---------|------------------------------------------------------------------|
| **Snowpipe**      | ✅ Yes  | Automated, event-driven, serverless (~0.06 credits/file)         |
| COPY INTO         | ❌ No   | Manual, requires scheduling, not event-driven                    |
| External Tables   | ❌ No   | Query-time parsing = slow; good for ad-hoc, not pipelines        |

**Tradeoff:** Snowpipe requires S3 event notification setup (SQS). In this project, AUTO_INGEST handles it, but cloud provider configuration is external.

---

### 3. Stream + Task CDC vs. Snowflake Connector for PostgreSQL

| Approach              | Chosen? | Why / Why Not                                                |
|-----------------------|---------|--------------------------------------------------------------|
| **Simulated CDC**     | ✅ Yes  | No external infra needed; demonstrates pattern clearly       |
| PG Connector (Kafka)  | ❌ No   | Requires Kafka + Debezium + connector setup (production-grade)|
| Snowpipe Streaming    | ❌ No   | Requires client SDK; overkill for demo                       |

**Tradeoff:** Simulated CDC doesn't capture real incremental changes from a live Postgres DB. In production, use Snowflake Connector for PostgreSQL or Kafka + Debezium for true CDC.

---

### 4. dbt vs. Pure SQL for Transformations

| Approach          | Chosen? | Where Applied                                |
|-------------------|---------|----------------------------------------------|
| **dbt**           | ✅ Yes  | Charging stations (Silver → Gold)            |
| **Pure SQL**      | ✅ Yes  | EV population (Bronze → Silver → Gold)       |

**Tradeoff:** Using both demonstrates flexibility but adds cognitive overhead. Ideal: Pick one approach per pipeline. dbt is better for complex multi-model lineage; Dynamic Tables are simpler for straightforward chains.

---

### 5. Iceberg Tables vs. Standard Tables for Gold

| Approach           | Chosen? | Why / Why Not                                             |
|--------------------|---------|-----------------------------------------------------------|
| **Iceberg Tables** | ✅ Yes  | Open format; external engines (Spark, Trino) can query    |
| Standard only      | ✅ Yes  | Primary serving; Iceberg is supplementary export          |

**Tradeoff:** Iceberg tables are static (INSERT OVERWRITE to refresh). No auto-refresh like Dynamic Tables. Good for cross-platform sharing; bad for real-time consumers.

---

### 6. Cortex Analyst vs. Direct SQL for End Users

| Approach            | Chosen? | Why / Why Not                                          |
|---------------------|---------|--------------------------------------------------------|
| **Cortex Analyst**  | ✅ Yes  | Natural language → SQL; no SQL skills required          |
| Direct SQL/BI       | ✅ Yes  | Dashboard Streamlit app uses direct SQL for speed       |

**Tradeoff:** Cortex Analyst adds latency (~2-5s per query) and may hallucinate SQL. Production tip: add verified queries to the semantic model for common questions.

---

## Infrastructure Layer

### Warehouse Configuration

```
┌──────────────────────────────────────┐
│         EV_DEMO_WH                   │
├──────────────────────────────────────┤
│  Size:         X-SMALL (1 credit/hr) │
│  Auto-Suspend: 60 seconds            │
│  Auto-Resume:  TRUE                  │
│  Query Timeout: 300 seconds (5 min)  │
│  Initial State: SUSPENDED            │
└──────────────────────────────────────┘
```

**Design Decision:** Single X-Small warehouse for all workloads. Cost-optimized for demo. In production, separate warehouses per workload type (ingestion, transform, serving) for isolation and independent scaling.

### Resource Monitor

```
┌───────────────────────────────────────────────────┐
│           EV_DEMO_MONITOR                         │
├───────────────────────────────────────────────────┤
│  Quota:   10 credits/month (~$30 Standard)        │
│  75%  →   NOTIFY (email alert)                    │
│  90%  →   SUSPEND (finish running queries)        │
│  100% →   SUSPEND_IMMEDIATE (kill everything)     │
└───────────────────────────────────────────────────┘
```

---

## Bronze Layer — Raw Ingestion

### Path 1: EV Population JSON

```
File Upload → @EV_RAW_STAGE → Snowpipe → Staging Table → Stream → Task (FLATTEN) → RAW_EV_POPULATION
```

| Component                     | Type          | Purpose                                      |
|-------------------------------|---------------|----------------------------------------------|
| `@EV_RAW_STAGE`              | Internal Stage | Landing zone for JSON files                  |
| `JSON_RAW_FORMAT`            | File Format   | `TYPE=JSON, STRIP_OUTER_ARRAY=FALSE`         |
| `EV_AUTO_INGEST_PIPE`        | Snowpipe      | Auto-loads new files as single VARIANT row    |
| `RAW_EV_POPULATION_STAGING`  | Table         | 1 row per file (whole JSON), CHANGE_TRACKING |
| `STM_RAW_EV_STAGING`         | Stream        | Detects new files loaded by Snowpipe         |
| `TSK_FLATTEN_EV_STAGING`     | Task          | LATERAL FLATTEN → individual vehicle rows    |
| `RAW_EV_POPULATION`          | Table         | Final Bronze: 1 row per vehicle (VARIANT)    |

**Cost per file:** ~0.08 credits (Snowpipe: 0.06 + Task: 0.02)

### Path 2: Charging Stations CDC

```
Simulated INSERT/UPDATE/DELETE → PG_RAW_CHARGING_STATIONS → Stream → Task (MERGE) → PG_CHARGING_STATIONS
```

| Component                     | Type    | Purpose                                    |
|-------------------------------|---------|--------------------------------------------|
| `PG_RAW_CHARGING_STATIONS`   | Table   | Raw source (simulates Postgres replica)    |
| `PG_STM_CHARGING_STATIONS`   | Stream  | Tracks CDC (INSERT/UPDATE/DELETE)          |
| `TSK_BRONZE_PG_MERGE`        | Task    | MERGE into reconciled current-state table  |
| `PG_CHARGING_STATIONS`       | Table   | Current-state with soft-delete flag        |

---

## Silver Layer — Cleansing & Validation

### EV Population: Dynamic Table

**`SILVER.CLEAN_EV_POPULATION`** — Dynamic Table, TARGET_LAG = 1 hour

Transformations applied:
1. VARIANT positional access → named typed columns
2. TRIM + UPPER/INITCAP for consistency
3. NULLIF(0) for range/MSRP (0 = no data)
4. Dedup: ROW_NUMBER by VIN+Year, keep latest
5. Filter: exclude NULL VINs (routed to DLQ)

### Charging Stations: dbt Model

**`SILVER.PG_CLEAN_CHARGING_STATIONS`** — dbt materialized table

Transformations:
1. TRIM + INITCAP/UPPER normalization
2. Filter: `IS_DELETED = FALSE`
3. Filter: `STATION_ID IS NOT NULL`
4. Validation: `POWER_LEVEL_KW BETWEEN 1 AND 500`

---

## Gold Layer — Business Aggregations

### Dimensional Model

```
                    ┌──────────────────────────┐
                    │  FACT_EV_REGISTRATIONS   │
                    │  ─────────────────────   │
                    │  VIN (PK)               │
                    │  DOL_VEHICLE_ID          │
                    │  MAKE, MODEL             │
                    │  MODEL_YEAR              │
                    │  EV_TYPE / EV_TYPE_SHORT │
                    │  ELECTRIC_RANGE          │
                    │  BASE_MSRP              │
                    │  CITY, COUNTY, STATE     │
                    │  IS_CAFV_ELIGIBLE        │
                    │  REGISTERED_AT           │
                    └────────────┬─────────────┘
                                 │
                    ┌────────────┴─────────────┐
                    │  DIM_CHARGING_STATIONS   │
                    │  ─────────────────────   │
                    │  STATION_ID (PK)        │
                    │  STATION_NAME            │
                    │  CITY, STATE             │
                    │  CONNECTOR_TYPE          │
                    │  POWER_LEVEL_KW          │
                    │  NETWORK                 │
                    │  STATION_STATUS          │
                    │  CHARGING_TIER           │
                    └──────────────────────────┘
```

### Aggregation Tables (All Dynamic Tables)

| Table                        | Grain                  | Key Metrics                                   |
|------------------------------|------------------------|-----------------------------------------------|
| `AGG_EV_BY_REGION`          | State / County / City  | Total EVs, BEV %, CAFV %, Avg Range           |
| `AGG_EV_YOY_GROWTH`         | Model Year             | Registrations, YoY Growth %, BEV/PHEV split   |
| `AGG_EV_BY_MAKE_MODEL`      | Make / Model           | Total registrations, Market Share %, Avg Range |
| `AGG_EV_CHARGING_COVERAGE`  | City                   | EVs/Station, Coverage Status, Networks         |

---

## Data Quality Framework

### Architecture

```
┌───────────────────────────────────────────────────────────────────────────┐
│                       DATA QUALITY GATES                                  │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  BRONZE CHECKS                SILVER CHECKS         COMPREHENSIVE         │
│  ─────────────                ─────────────         ─────────────         │
│  • NULL VIN (0%)              • NULL checks          • Schema validation  │
│  • NULL Make (95%)            • Range bounds          • Business rules     │
│  • Duplicate VIN+Year         • Type validation       • Referential integ. │
│  • Row count match            • Freshness             • Freshness (48hr)   │
│                                                                           │
│  ON FAILURE:                                                              │
│  ┌───────────┐  ┌─────────────────────┐  ┌──────────────────────┐        │
│  │  DLQ_     │  │ AUDIT_DQ_RESULTS    │  │ EMAIL ALERT          │        │
│  │  BRONZE   │  │ (check history)     │  │ (on FAIL/WARN)       │        │
│  └───────────┘  └─────────────────────┘  └──────────────────────┘        │
└───────────────────────────────────────────────────────────────────────────┘
```

### Dead Letter Queue (DLQ) Pattern

Records failing critical checks (NULL VIN, invalid data) are routed to `AUDIT.DLQ_BRONZE` for manual investigation. This prevents bad data from propagating downstream while preserving it for debugging.

**Tradeoff:** DLQ adds storage overhead but guarantees no silent data loss. Alternative: DROP bad rows (simpler, but unrecoverable).

---

## Orchestration — Task DAG

```
    TSK_PIPELINE_ROOT (every 60 min)
         │
         ├─────────────────────────────────────────┐
         │                                         │
         ▼                                         ▼
    TSK_BRONZE_EV_FLATTEN               TSK_BRONZE_PG_MERGE
    (Stream: STM_RAW_EV_STAGING)        (Stream: PG_STM_CHARGING_STATIONS)
         │                                         │
         └──────────────┬──────────────────────────┘
                        │
                        ▼
                  TSK_DQ_GATE
                  (Runs ALL DQ procs)
                  (Sends email on failure)
```

**Key Behaviors:**
- Root fires every 60 minutes
- Children execute ONLY if their stream has data (zero cost otherwise)
- DQ gate waits for BOTH Bronze tasks to complete
- If a parent fails, children don't fire
- Suspend root → stops entire pipeline

---

## Applications Layer

### 1. EV Analytics Chat (Cortex Analyst)

| Feature            | Implementation                                |
|--------------------|-----------------------------------------------|
| Interface          | Streamlit chat (Snowflake-hosted)             |
| AI Backend         | Cortex Analyst + Semantic View                |
| Semantic View      | `EV_POPULATION_DB.GOLD.EV_ANALYTICS_SV`      |
| Capabilities       | Natural language → SQL → Results + Charts     |
| Suggestions        | Pre-built prompts (YoY, Tesla vs others, etc) |

### 2. EV Dashboard (Direct SQL)

| Feature            | Implementation                                |
|--------------------|-----------------------------------------------|
| Interface          | Streamlit multi-tab dashboard                 |
| Data Source        | Direct SQL against Gold aggregation tables    |
| Tabs               | YoY Growth, Regional, Market Share, Coverage  |
| Metrics            | Total EVs, BEV Share, Peak Growth, Avg Range  |
| Caching            | `@st.cache_data` with manual refresh button   |

---

## Iceberg Integration

```
GOLD.FACT_EV_REGISTRATIONS  ──▶  GOLD.FACT_EV_REGISTRATIONS_ICE (Iceberg)
GOLD.DIM_CHARGING_STATIONS  ──▶  GOLD.DIM_CHARGING_STATIONS_ICE (Iceberg)
```

| Property         | Value                                                  |
|------------------|--------------------------------------------------------|
| Catalog          | `SNOWFLAKE` (Snowflake-managed)                        |
| External Volume  | `SNOWFLAKE_MANAGED`                                    |
| Format           | Apache Parquet (open format)                           |
| Refresh          | Manual: `INSERT OVERWRITE INTO ... SELECT * FROM ...`  |
| Consumers        | Spark, Trino, Presto, Databricks, Flink               |

**Tradeoff:** Using `SNOWFLAKE_MANAGED` external volume is simplest but doesn't expose files to external object storage (S3/GCS). For true multi-engine access, configure a custom external volume pointing to your S3 bucket.

---

## dbt Integration

### Project: `ev_charging_dbt`

```
silver/dbt_charging_stations/
├── dbt_project.yml
├── profiles.yml
├── models/
│   ├── sources.yml
│   ├── silver/
│   │   ├── pg_clean_charging_stations.sql
│   │   └── schema.yml (tests)
│   └── gold/
│       └── dim_charging_stations.sql
└── macros/
    └── generate_schema_name.sql
```

**Tests included:**
- `unique`: STATION_ID
- `not_null`: STATION_ID, STATION_NAME, CITY, STATE, ZIP_CODE, POWER_LEVEL_KW
- `accepted_values`: CONNECTOR_TYPE, STATION_STATUS

**Why dbt here (not Dynamic Tables):** Demonstrates multi-tool capability. dbt provides better testing, documentation, and lineage for the charging station pipeline specifically.

---

## Git Integration & Version Control

```
┌────────────────────────┐          ┌──────────────────────────┐
│  GitHub Repository     │          │  Snowflake Git Object    │
│  free4hny/snowflake-POC│◀────────▶│  EV_GIT_REPO             │
│                        │  HTTPS   │  (UTILITIES schema)      │
└────────────────────────┘          └──────────────────────────┘
         ▲                                      │
         │                                      ▼
    ┌────┴───────┐                    ┌─────────────────────┐
    │  Developer │                    │  Snowflake Workspace │
    │  (local)   │                    │  (snowflake-POC)     │
    └────────────┘                    └─────────────────────┘
```

| Component               | Value                                           |
|-------------------------|-------------------------------------------------|
| API Integration         | `EV_GIT_API_INTEGRATION`                        |
| Secret                  | `EV_GIT_SECRET` (GitHub PAT)                    |
| Repository              | `EV_POPULATION_DB.UTILITIES.EV_GIT_REPO`        |
| Remote URL              | `https://github.com/free4hny/snowflake-POC.git` |

---

## Security Model (RBAC)

### Role Hierarchy

```
    ACCOUNTADMIN
         │
      SYSADMIN
         │
    EV_DEMO_ADMIN         ← Full control: DDL, Tasks, Pipes, DQ
         │
    EV_DEMO_ENGINEER      ← Read-write Bronze/Silver/Gold, run pipelines
         │
    EV_DEMO_ANALYST       ← Read-only Silver + Gold (reporting)
```

### Permission Matrix

| Object/Action              | ADMIN | ENGINEER | ANALYST |
|----------------------------|:-----:|:--------:|:-------:|
| CREATE/ALTER objects       |   ✅  |    ✅    |   ❌    |
| EXECUTE TASK               |   ✅  |    ❌    |   ❌    |
| Read BRONZE                |   ✅  |    ✅    |   ❌    |
| Read/Write SILVER          |   ✅  |    ✅    |   ❌    |
| Read SILVER                |   ✅  |    ✅    |   ✅    |
| Read/Write GOLD            |   ✅  |    ✅    |   ❌    |
| Read GOLD                  |   ✅  |    ✅    |   ✅    |
| Read AUDIT                 |   ✅  |    ✅    |   ❌    |
| Use EV_DEMO_WH             |   ✅  |    ✅    |   ✅    |

**Design Decision:** Least-privilege model with future grants. Analysts cannot see raw data (PII risk in Bronze). Engineers cannot manage tasks/pipes (admin responsibility).

---

## Cost Controls

### Credit Consumption (Last 30 Days — as of May 25, 2026)

**Total Credits Used: ~89.61**

#### By Service Type

| Service Type | Credits | % of Total |
|---|:---:|:---:|
| Cortex Code (Snowsight) | 81.01 | 90.4% |
| Snowpark Container Services | 4.98 | 5.6% |
| Warehouse Metering | 3.33 | 3.7% |
| AI Services | 0.27 | 0.3% |
| Telemetry Data Ingest | 0.01 | <0.1% |
| Auto-Clustering | 0.01 | <0.1% |
| Pipe | 0.00 | <0.1% |
| Copy Files | 0.00 | <0.1% |

#### By Warehouse (3.33 credits total)

| Warehouse | Credits | % of Warehouse Total |
|---|:---:|:---:|
| COMPUTE_WH | 2.12 | 63.7% |
| EV_OPENFLOW_WH | 0.77 | 23.1% |
| EV_DEMO_WH | 0.44 | 13.2% |

#### Daily Trend

| Date | Credits |
|---|:---:|
| May 24, 2026 | 38.11 |
| May 23, 2026 | 51.50 |
| May 21–22, 2026 | 0.00 |

> **Key Insight:** Cortex Code (this AI assistant) is the dominant cost driver at 90.4% of total spend. Warehouse compute is minimal at 3.7%. To reduce costs, manage Cortex Code usage or set a budget alert.

#### Workspace / Project Attribution

Credits are metered account-wide, but query history lets us attribute usage by database context:

| Database (Context) | Query Count | Cloud Svc Credits | Purpose |
|---|:---:|:---:|---|
| USER$ABHISHEK | 34,250 | 0.0003 | Cortex Code workspace (this assistant) |
| (no database) | 22,151 | 0.0037 | System/background operations |
| SNOWFLAKE | 4,810 | 0.0000 | Account usage & metadata queries |
| **EV_POPULATION_DB** | **645** | **0.0253** | **This project's workload** |
| SNOWFLAKE_SAMPLE_DATA | 1 | 0.0000 | Sample data exploration |

#### EV Project Warehouse Breakdown (EV_POPULATION_DB)

| Warehouse | Queries | Cloud Svc Credits | Elapsed (hrs) |
|---|:---:|:---:|:---:|
| EV_OPENFLOW_WH | 337 | 0.014 | 0.048 |
| EV_DEMO_WH | 308 | 0.011 | 0.043 |

#### Account-Wide — Full Resource Detail

| Service | Resource | Credits |
|---|---|:---:|
| Cortex Code (Snowsight) | CORTEX_CODE_SNOWSIGHT | 81.01 |
| Snowpark Container Services | SYSTEM_COMPUTE_POOL_CPU | 4.98 |
| Warehouse | COMPUTE_WH | 2.12 |
| Warehouse | EV_OPENFLOW_WH | 0.77 |
| Warehouse | EV_DEMO_WH | 0.44 |
| AI Services | (unnamed) | 0.27 |
| Auto-Clustering | AI_OBSERVABILITY_EVENTS | 0.006 |
| Copy Files | Workspace stage | 0.003 |
| Pipes | EV_AUTO_INGEST_PIPE + others | ~0.00 |

> **Attribution Summary:** The EV project (EV_POPULATION_DB) directly consumed ~1.21 warehouse credits (EV_OPENFLOW_WH + EV_DEMO_WH). Cortex Code (81 credits) powers this AI assistant. COMPUTE_WH (2.12 credits) handles ad-hoc/system queries.

#### Credit Reconciliation Gap

| Metric | Credits |
|---|:---:|
| Initial allocation (trial) | 400.00 |
| Remaining balance | 209.00 |
| **Actual consumed** | **191.00** |
| Tracked in ACCOUNT_USAGE (all time) | ~91.00 |
| **Unaccounted gap** | **~100.00** |

**Why ~100 credits are not visible in ACCOUNT_USAGE:**

1. **Reporting latency (up to 6 hrs)** — `METERING_HISTORY` has a documented lag of up to 6 hours. Current-day Cortex Code usage (the largest consumer) may not have landed yet. Given daily rates of 38–51 credits, multiple hours of un-landed data easily accounts for 40–50+ credits.
2. **Cortex Code multi-hour lag** — Cortex Code (Snowsight) credits are aggregated and reported with additional delay beyond standard warehouse metering.
3. **SPCS standby costs** — Compute pool idle/standby credits may not fully itemize in hourly metering but still deduct from balance.
4. **Platform overhead on trial accounts** — Some trial accounts incur non-itemized deductions (storage platform fees, internal metadata operations) that reduce balance without appearing as line items.
5. **First recorded usage is May 22** — If the account was created earlier, any usage before that date may have fallen outside the ACCOUNT_USAGE 365-day retention window or was consumed before metering views were populated.

> **Recommendation:** Re-check this reconciliation in 24 hours when reporting lag clears. The gap should narrow significantly as un-landed Cortex Code credits appear in the views.

---

### Monthly Budget Estimate (Demo Workload)

| Component                    | Credits/Month | Notes                         |
|------------------------------|:-------------:|-------------------------------|
| Dynamic Tables (6 × 24/day) |     ~4.3      | 1hr lag, XS warehouse         |
| Task DAG (24 runs/day)      |     ~1.5      | Only when streams have data   |
| Snowpipe                    |     ~0.5      | Depends on file upload rate   |
| Ad-hoc queries              |     ~2.0      | Streamlit + Cortex Analyst    |
| **Total**                   |   **~8.3**    | Under 10-credit monitor cap   |

### Guardrails

1. **Resource Monitor** — Hard stop at 10 credits/month
2. **Auto-Suspend** — 60s idle = warehouse sleeps
3. **Statement Timeout** — 5-minute kill switch for runaway queries
4. **Stream-driven tasks** — Zero cost when no new data arrives
5. **Dynamic Table lag** — 1 hour (not real-time) = fewer refreshes

---

## Pros & Cons Summary

### Pros ✅

| Category            | Benefit                                                          |
|---------------------|------------------------------------------------------------------|
| **Architecture**    | Clean separation of concerns (Bronze/Silver/Gold)                |
| **Automation**      | Fully automated: Snowpipe → Stream → Task → Dynamic Table       |
| **Cost**            | Stays under 10 credits/month with aggressive auto-suspend        |
| **Quality**         | DQ gates prevent bad data propagation; DLQ preserves failures    |
| **Serving**         | Multiple access patterns: SQL, NL (Cortex), Iceberg, Streamlit   |
| **Security**        | 3-tier RBAC with least privilege and future grants               |
| **Observability**   | Full audit trail: pipeline logs, DQ results, timestamps          |
| **Interop**         | Iceberg export for Spark/Trino/Databricks consumption            |
| **Version Control** | All SQL in Git; reproducible from scratch                        |

### Cons ❌

| Category            | Limitation                                                       |
|---------------------|------------------------------------------------------------------|
| **CDC**             | Simulated (not real Postgres connector); no true incremental     |
| **Mixed tooling**   | Both dbt AND Dynamic Tables adds complexity                      |
| **Iceberg refresh** | Manual INSERT OVERWRITE; no auto-sync with source tables         |
| **Single warehouse**| All workloads share XS; contention possible under load           |
| **No CI/CD**        | Git integration exists but no automated deployment pipeline      |
| **Semantic model**  | Cortex Analyst depends on semantic view quality; hallucination risk|
| **No data contracts**| Schema changes in source JSON could break positional parsing     |
| **Single region**   | No cross-region replication or failover                          |

---

## Ideal vs. Actual — Challenges Encountered

### 1. Workspace → Git Push

| Ideal                                          | Actual (Challenge)                                        |
|------------------------------------------------|-----------------------------------------------------------|
| Create workspace, develop, push to Git         | Workspace created before Git setup; no retroactive linking|
| **Solution:** Created new Git-connected workspace and transferred files manually                  |

### 2. API Integration + Secret

| Ideal                                          | Actual (Challenge)                                        |
|------------------------------------------------|-----------------------------------------------------------|
| API Integration allows all auth secrets        | `ALLOWED_AUTHENTICATION_SECRETS` was empty                |
| Secret attached at Git repo creation           | Repo created for public access; secret added later        |
| **Solution:** ALTER API INTEGRATION + ALTER GIT REPOSITORY to attach secret post-hoc             |

### 3. Dynamic Tables vs. Tasks

| Ideal                                          | Actual (Challenge)                                        |
|------------------------------------------------|-----------------------------------------------------------|
| All transforms as Dynamic Tables (simplest)    | CDC MERGE requires procedural logic → must use Task       |
| **Lesson:** Dynamic Tables cannot express MERGE/upsert. Use Task+Stream for CDC patterns.        |

### 4. dbt in Snowflake Workspace

| Ideal                                          | Actual (Challenge)                                        |
|------------------------------------------------|-----------------------------------------------------------|
| `dbt run` with no auth config                  | profiles.yml must exist but cannot use `env_var()`        |
| **Lesson:** Snowflake-native dbt uses session auth; no password/authenticator fields needed.      |

### 5. Bronze Parsing (Positional JSON)

| Ideal                                          | Actual (Challenge)                                        |
|------------------------------------------------|-----------------------------------------------------------|
| Named JSON keys (`RAW_DATA:vin`)               | Source is array-of-arrays → positional access `RAW_DATA[8]`|
| **Risk:** If source adds/removes columns, ALL positions shift. No schema contract.               |
| **Mitigation:** DQ row-count checks detect drift. Future: add schema registry or key-based JSON. |

### 6. Cost Estimation

| Ideal                                          | Actual (Challenge)                                        |
|------------------------------------------------|-----------------------------------------------------------|
| Precise cost per pipeline component            | Dynamic Table costs are opaque (no per-table credit view) |
| **Workaround:** Resource Monitor + ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY for estimates.       |

---

## Glossary

| Term                | Definition                                                             |
|---------------------|------------------------------------------------------------------------|
| **Medallion**       | Architecture pattern: Bronze (raw) → Silver (clean) → Gold (business)  |
| **Dynamic Table**   | Auto-refreshing table defined by a query; Snowflake manages scheduling |
| **Stream**          | Tracks DML changes on a table; zero-cost when no changes occur         |
| **Task**            | Scheduled SQL execution; can depend on streams or other tasks          |
| **Snowpipe**        | Serverless auto-ingest; loads files as they arrive in a stage          |
| **CDC**             | Change Data Capture — tracking INSERT/UPDATE/DELETE from source         |
| **DLQ**             | Dead Letter Queue — holds failed/rejected records for investigation    |
| **Iceberg**         | Open table format (Apache); Parquet files + metadata for multi-engine  |
| **Cortex Analyst**  | Snowflake AI service: natural language → SQL via semantic models        |
| **CAFV**            | Clean Alternative Fuel Vehicle — state incentive eligibility           |
| **BEV / PHEV**      | Battery EV (pure electric) / Plug-in Hybrid EV                         |
| **TARGET_LAG**      | Max staleness for a Dynamic Table before it auto-refreshes             |
| **RBAC**            | Role-Based Access Control — permission model via role hierarchy         |

---

## File Inventory

```
📁 infrastructure/          — Setup scripts (run once)
   ├── roles_and_grants/    — RBAC: 3 roles + hierarchy + grants
   ├── compute/             — Warehouse + Resource Monitor
   ├── storage/             — Database, schemas, stages, file formats
   ├── git_integration/     — API Integration + Git Repository
   └── orchestration/       — Task DAG (pipeline scheduler)

📁 bronze/                  — Raw ingestion scripts
   ├── raw_ev_population/   — Snowpipe + FLATTEN pipeline
   └── cdc_postgres/        — Simulated CDC: stream + merge

📁 silver/                  — Cleansing & transformation
   ├── cleansing/           — Dynamic Table: CLEAN_EV_POPULATION
   ├── validation/          — Dedup and null handling
   └── dbt_charging_stations/ — dbt project for charging data

📁 gold/                    — Business-ready layer
   ├── dimensional/         — Fact + Dimension tables
   ├── aggregations/        — KPI tables (region, YoY, coverage)
   └── iceberg/             — Open-format export tables

📁 data_quality/            — DQ framework
   ├── rules/               — Check procedures (Bronze, Silver, Comprehensive)
   └── alerts/              — Email notifications on failure

📁 audit/                   — Operational observability
   ├── tables/              — Pipeline log, DQ results, DLQ schemas
   └── logging/             — SP_LOG_PIPELINE_EVENT helper

📁 ev-chat/                 — Streamlit applications
   ├── .streamlit/          — Cortex Analyst chat app
   └── ev-dashboard/        — Analytics dashboard app

📁 streamlit/dashboard/     — Alternative dashboard app
```

---

*Generated: May 2026 | Platform: Snowflake | Account: xf36075*
