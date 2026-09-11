# SQL Server 2012 → SQL Server 2025 Migration Runbook

**Approach:** Side-by-side migration (new hardware/OS, new SQL Server 2025 install, data moved via backup/restore or AG)
**Why not in-place:** SQL Server 2025 requires a current 64-bit OS with no version overlap with what SQL Server 2012 typically runs on (Windows Server 2008 R2/2012). A single-hop in-place upgrade across 13 years of releases is not realistic even where technically listed as "supported."

---

## Phase 1 — Discovery & Inventory (Weeks 1–2)

1. **Inventory every SQL Server 2012 instance**
   - Instance name, edition, exact build/CU level, physical vs. VM, core count, memory
   - `SELECT @@VERSION`, `SELECT SERVERPROPERTY('ProductVersion')`, `SELECT SERVERPROPERTY('Edition')`
2. **Inventory databases per instance**
   - Size, compatibility level (should be 110 on native 2012 DBs), recovery model
   - Cross-database dependencies (linked servers, three/four-part names, synonyms)
3. **Inventory dependent objects and services**
   - SQL Agent jobs, SSIS packages/catalogs, SSRS reports/subscriptions, DTS packages (should not exist by now, but verify), Database Mail, replication topology, log shipping, Always On AGs
4. **Inventory logins and security**
   - SQL logins, Windows logins/groups, server roles, orphaned users, linked server credentials, certificates/keys used for TDE or Always Encrypted
5. **Inventory client connectivity**
   - Which apps connect, which driver (`System.Data.SqlClient` vs. `Microsoft.Data.SqlClient`), TLS/encryption settings, connection string formats, drivers on app servers
6. **Inventory third-party tooling**
   - Backup software, monitoring agents, Qlik Replicate or other CDC tools, antivirus exclusions
7. **Run an assessment tool**
   - Microsoft is retiring the Data Migration Assistant (DMA) in favor of a continuous assessment model via **SQL Server enabled by Azure Arc**. Register instances in Azure Arc and use its assessment blade instead of standalone DMA where possible.
   - Flag deprecated features, breaking changes, and unsupported data types (e.g., `text`/`ntext`/`image`, deprecated system views).

**Deliverable:** A spreadsheet/tracking table of instances → databases → dependencies → risk rating (this can slot into the same gaps-and-action-items format you've used for other tracking work).

---

## Phase 2 — Target Environment Design (Weeks 2–3)

1. **Choose target OS**: Windows Server 2022 or 2025 (per SQL Server 2025 hardware/software requirements).
2. **Size hardware/VMs**: CPU, memory, storage tiering (data/log/tempdb separation), based on current utilization plus growth headroom.
3. **Choose edition**: Note Standard Edition in SQL Server 2025 now supports up to 256 GB buffer pool and 4 sockets/32 cores, and Resource Governor is available in Standard — this may change your Enterprise vs. Standard licensing decision versus what you run today.
4. **Decide topology**: Standalone, Always On AG, or FCI. If minimizing downtime is a priority, plan for an AG-based cutover (see Phase 6).
5. **Plan networking**: New instance names, ports, firewall rules, DNS/CNAME strategy for connection-string continuity.
6. **Plan security baseline**: Microsoft Entra integration (deeper in 2025), encryption-by-default expectations, TDE/Always Encrypted key migration.

**Deliverable:** Target architecture diagram and build spec, signed off before any installs happen.

---

## Phase 3 — Build & Prepare (Weeks 3–4)

1. Provision new servers/VMs with the target OS.
2. Install SQL Server 2025, choosing edition/features matching Phase 2 design.
3. Configure tempdb, memory, max degree of parallelism, and other instance-level settings to match (or intentionally improve on) current production standards.
4. Install/configure third-party tooling on the new instance (backup agent, monitoring, Qlik Replicate endpoints if applicable).
5. Set up Microsoft Entra integration and any new authentication requirements.
6. Configure encryption settings — plan explicitly for "Encrypt by Default" behavior change; test app connectivity against it in a lower environment first.

**Deliverable:** Fully built, patched, but empty SQL Server 2025 environment, validated against the System Configuration Checker.

---

## Phase 4 — Pre-Migration Testing (Weeks 4–6)

1. **Restore a copy of each database** to the new 2025 instance in a non-production environment (backup taken on 2012, restored directly — supported since 2012 backups have compat level ≥ 100).
2. **Do NOT bump compatibility level yet.** Leave databases at their source compat level initially so you can isolate "did the upgrade break something" from "did the optimizer change break something."
3. **Run application regression tests** against the restored databases at the old compat level first.
4. **Incrementally raise compatibility level** (110 → 130 → 150 → 170 in steps, or straight to target — your call based on risk tolerance) and re-test after each step, watching for plan regressions.
5. **Use Query Store** to baseline query performance before and after each compat level change.
6. **Validate deprecated feature remediation** identified in Phase 1 (datatype conversions, removed system objects, etc.).
7. **Test client driver compatibility** — confirm apps using older `System.Data.SqlClient` connect successfully or have been updated to `Microsoft.Data.SqlClient` as needed.
8. **Test SSIS/SSRS/Agent jobs** re-deployed to the new environment.
9. **Test backup/restore and monitoring tooling** end-to-end on the new instance.

**Deliverable:** Signed-off test results per database, a documented rollback plan, and a finalized compatibility-level target.

---

## Phase 5 — Cutover Planning (Week 6)

1. Freeze schema/config changes on source 2012 environment ahead of cutover.
2. Schedule a maintenance window; communicate to application owners and stakeholders.
3. Prepare rollback criteria and rollback steps (keep 2012 environment intact and untouched until 2025 is validated in production).
4. Prepare login/job/SSIS/SSRS migration scripts (script logins with SIDs preserved, re-create SQL Agent jobs, redeploy SSIS catalogs, re-point SSRS data sources).
5. Prepare a connection-string/DNS cutover plan (CNAME swap is usually cleanest — avoids touching every app config).

---

## Phase 6 — Cutover Execution

**Option A: Backup/Restore Cutover (simpler, more downtime)**
1. Stop application access to source databases.
2. Take final full + log backups on the 2012 source.
3. Restore to the 2025 target.
4. Apply compatibility level per your Phase 4 conclusions.
5. Migrate logins, jobs, SSIS, SSRS, linked servers.
6. Run smoke tests.
7. Cut over connection strings/DNS.
8. Monitor closely for the first business cycle.

**Option B: Always On AG Cutover (minimal downtime, higher complexity)**
1. Build the new SQL Server 2025 instance as a secondary replica joined to the existing AG (requires an intermediate hop — 2012 cannot directly AG-pair with 2025; you'd typically stage through an already-upgraded intermediate version, or use log shipping instead since 2012 → 2025 AG membership isn't supported).
2. Since direct AG mixing that far apart isn't supported, the realistic minimal-downtime path is: **log shipping** from 2012 primary to the 2025 secondary, or a **transactional replication** push, followed by a brief cutover window to redirect traffic once caught up.
3. Validate the 2025 instance is caught up and consistent.
4. Redirect application traffic during a short planned window.
5. Decommission the 2012 source once validated.

> **Note:** Confirm your specific case — Always On direct mixed-version membership has version-distance limits. For a 2012 → 2025 jump, log shipping or transactional replication to a 2025 secondary, followed by a cutover, is the more realistic "minimal downtime" mechanism rather than a native AG rolling upgrade.

---

## Phase 7 — Post-Migration Validation

1. Verify `SELECT @@VERSION` / `SERVERPROPERTY` on all migrated instances.
2. Verify all databases came online with expected state and compatibility level.
3. Verify Agent jobs are running on schedule.
4. Verify SSIS/SSRS content renders and executes correctly.
5. Verify logins can authenticate and permissions match source.
6. Verify backup jobs and monitoring alerts are active on the new environment.
7. Run a full application regression pass in production.
8. Monitor Query Store / DMVs for plan regressions in the days following cutover — parameter sniffing and cardinality estimator behavior will differ significantly from 2012.

---

## Phase 8 — Decommission & Closeout

1. Keep the 2012 environment in a cold/read-only state for an agreed retention period (e.g., 30 days) as a rollback safety net.
2. After sign-off, decommission the 2012 instance and reclaim hardware/licenses.
3. Document final architecture, lessons learned, and update the gaps/action-items tracker to closed status.
4. Update internal standards/CMDB with new instance details.

---

## Key Risk Areas Specific to This Jump (2012 → 2025)

| Area | Risk | Mitigation |
|---|---|---|
| OS/version overlap | No in-place path realistic | Side-by-side migration only |
| Cardinality estimator changes | Query plan regressions after multiple CE generations | Staged compat-level testing, Query Store baselines |
| Deprecated datatypes/features | Silent breakage post-migration | DMA/Azure Arc assessment in Phase 1 |
| Client driver (`System.Data.SqlClient`) | App connectivity failures | Inventory and test in Phase 1/4 |
| Encrypt-by-default in 2025 | Connection failures for unencrypted apps | Explicit connectivity testing in Phase 4 |
| AG/log shipping version distance | Native AG can't bridge 13 years directly | Use log shipping/replication for minimal-downtime cutover |
| Licensing model change | Standard edition capability expansion may change edition choice | Revisit licensing in Phase 2 |

---

*Prepared for AZ Blue DBA Engineering — SQL Server 2012 → 2025 migration project.*
