# Persistent casino public release review

Prepared October 8, 2026. Public-release work is authorized by the user's request to push the update for everyone. Paid hosting has not been approved. The candidate stays on `casino-persistent-render`, with the published casino client disabled, until the audited release gates pass.

## Current evidence

- Production remains `main` at `76b5c90bb5402da1165f3f0c8b3175b7aafe454b`; the served site is v0.10.4. Production Supabase `puvjfhwxigxjpsvdwrwf` is in us-east-1, with `tables` version 12. The read-only baseline found one open legacy Blackjack table and one seat. Recheck immediately before migration; preserve that table, wallet, ledger and history.
- Isolated staging `nxsqerlpqdzrjwqxhsdz` is in us-west-2. Render `palisade-casino-staging` runs on Free/Oregon, service `srv-db3tn82j9qps73fe2t30`. Its deployed runtime at the capacity check was `897e1eb437b5e8fdb719d5f96c8e2c9c11e4db1a`, Node 22.17.0; staging Edge `tables` version 5 has the shared adapter and metrics repair.
- Real six-browser continuity and all seven managed games previously passed on runtime `70556d6`. Those results remain tied to that deployment. New client seat synchronization and cash-out fixes need deployment-specific verification.
- The repaired runtime `731e6f7` has since deployed successfully (Render `dep-db408h942hec73f9n8pg`, 1m46s, Node 22.17.0). Four managed backend suites, the local six-browser test and all 35 table-sheet cases pass. The repeated live six-browser check passes on that runtime and isolated site build `dcb1195fa6`, with no browser errors or new worker errors. All-game live/capacity/fault tests must still repeat on the paid candidate.
- The paced, real-Auth capacity attempt admitted 60 accounts in 10 rooms but failed during the table setup: one client received `Movement queue exceeded`; subsequent stopped input and socket closures ended the run. It did not complete its 120-second smoke period or the two-hour acceptance gate. The harness uses 49 walking/chatting users and 11 seated table/cabinet users; standing spectator API peeks and network shaping are not included.
- At full admission, process CPU was about 15.0% of one core, exceeding the Free instance's nominal 0.1-core allocation and the required 25% headroom. RSS was about 102 MB and measured tick p95 about 1.65 ms. These are short-run observations, not a steady-state certification or Render-normalized CPU readings.
- After cleanup, all 20 closed staging tables balance, all 61 reserved test wallets match their ledger, and zero seats remain. Admissions and new wagers are paused; recovery stays enabled. Financial rows and operation receipts are retained.

See the [execution evidence](../evidence/persistent-casino-2026-10-08/README.md) and [audited work order](persistent-casino-render-work-order.md) for the detailed gates and historical failures.

## Paid hosting proposal

Render's current dashboard offers `0.5c-512mb` at **$7/month**, with 0.5 CPU and 512 MB RAM. It is the smallest always-on candidate. Its capacity is **unverified**; no paid tier is certified by the Free test.

1. Temporarily upgrade the existing isolated staging service to that $7/month instance. Run the two-hour capacity test, idle/recovery/audit checks and active-player deployment tests. Limit temporary staging compute to **$1 total** before a new approval; compute is prorated by the second. At $7/month, one day is approximately $0.23. Downgrade or suspend paid staging after verification, only once accepted obligations drain.
2. If that instance passes all release gates, create one production service, proposed name `palisade-casino`, in **Virginia**, matching production Supabase's us-east-1 region. Keep Hobby workspace and one instance. Ongoing compute is **$7/month**, plus applicable tax and usage charges. Paid staging and production briefly overlap; two instances cost $14/month equivalent during that overlap, prorated, rather than two permanent subscriptions.
3. Hobby includes **5 GB/month outbound bandwidth shared by the workspace**. Public-internet overage is **$0.15/GB**; WebSocket responses and service-initiated external database traffic both count. This is not a fixed $7 total bill. For example, 100 GB total monthly outbound usage would add $14.25 bandwidth, for $21.25 compute plus bandwidth before tax. That is an example, not a forecast.
4. Bound the capacity run to 1.8 GB of outgoing WebSocket application payload, check actual provider usage before and after it, and stop if remaining allowance is insufficient. Payload counters omit platform/TCP/TLS overhead and external database traffic; provider billing can lag. No artificial traffic is used to prevent Free sleep.

The dashboard's latest displayed usage was 12 MB / 5 GB, 2.15 / 750 Free instance hours, four pipeline minutes, and $0 accrued/projected. It showed no card on file. These readings can lag recent load traffic.

Sources checked October 8: [Render bandwidth](https://render.com/docs/outbound-bandwidth), [Render billing/proration FAQ](https://render.com/docs/faq), [Free limitations](https://render.com/docs/free), and the service's [compute screen](https://dashboard.render.com/web/srv-db3tn82j9qps73fe2t30/compute).

## Gates required before the public switch

- Repeat the real six-browser and all-game staging checks against the final commit, including rapid sit/stand, shared Hold'em cash-out, accepted retry/history and wallet reconciliation.
- Pass the actual two-hour 60-client test with at least 25% CPU/RAM headroom, stable memory, bounded movement/send queues, worker deadlines and recorded database/egress metrics. Separately measure the specified 150 ms RTT, jitter/loss profile and slow/flood clients; the current harness does not certify those conditions.
- Measure active-client Render replacement and hard-stop recovery, including platform old/new overlap, lease fencing, already accepted decisions and departed obligations. Preserve private-card redaction under those failures.
- Complete live invitation/code/full-room/cached-client, token refresh/logout/account switch, database interruption, idle/no-client phases and the next naturally scheduled daily books boundary. Do not create a premature current-day books row to manufacture an audit pass.
- Finish the required viewport, touch/controller, reduced-motion, pending/error/maintenance/reconnect UI evidence and short recordings. Local recordings do not substitute for a live restart recording.

An upgraded server alone does not waive these gates. If the $7 instance fails, stop and present the measured reason and next cost before selecting a larger plan.

## Production deployment sequence

1. Refresh production's migration/function/legacy-seat baseline. Review the additive `20261008133818_persistent_casino_world.sql`; apply only that migration to existing production. Never apply the full staging restore to production. Preserve ongoing legacy tables.
2. Deploy the compatible shared `tables` bundle. Keep managed admission/new wagers off and recovery on. Verify grants/RLS and old cached/legacy request compatibility before any public switch.
3. Create the proposed Virginia production service with Node 22.17.0, `cd dev/render && npm ci --omit=dev`, `cd dev/render && npm start`, `/healthz` and `/readyz`, one paid instance and automatic deploy off for the rollout. Set production Supabase URL and the exact GitHub Pages origin. Use the service-specific secret only on the server; the user enters it through Render's environment controls. Never put a server key in Git, browser config, test output or the release report.
4. Verify the deployed source commit, SDK/wire/layout/storage versions, authority leases, directory and idle recovery. Use an explicitly selected existing test account allowlist for production checks without synthetic wallet funding, load tests or chaos against production.
5. Build the public client with the verified production service URL and production publishable configuration. Verify CSP and generated assets, update build/cache/status together, merge the reviewed candidate to main and verify the actual GitHub Pages publication.
6. Enable public admissions/new wagers in a controlled step. Verify a real public join, continuity after the first player leaves, accepted action receipts, reconnect and rolling reconciliation. Record the served site hash, Render commit/deploy ID, migration state and Edge version.

## Rollback and approvals

Pause new admissions/new wagers first; retain compatible recovery, accepted-request replay, cash-out/history and all ledger/receipt/room data. Let accepted hands and non-cancellable craps obligations settle. Reconcile before retiring a service. Never reset wallets, truncate tables or turn a managed room into P2P under the same identity.

The next approval is specifically the temporary staging compute budget above and one ongoing $7/month production instance with the stated bandwidth charges. Card entry remains a user handoff. Production server-secret sharing is a separate action-time security step naming that secret and its destination; its value must never be retrieved by this task. No workspace Pro subscription, database plan upgrade, autoscaling, paid disk, larger instance or unlimited test spend is included.
