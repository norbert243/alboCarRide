# ============================================================
# 🚦 PHASE 4 – Driver Telemetry & Analytics Dashboard (Audit)
# ============================================================
# PURPOSE:
# Validate and ensure full integration of Driver Dashboard v2 with the
# live Supabase RPC `get_driver_dashboard()` response.
# This script must **NOT** refactor, replace, or modify existing
# operational systems without explicit permission.
#
# 🧠 IMPORTANT SCOPE RULE:
# RooCode must adhere to this project's rule:
#   ⚠️ DO NOT CHANGE what is already working without explicit permission.
#
# ============================================================

## ✅ AUDIT GOALS
1. Verify that `DriverDashboardV2` widget is present under:
   `lib/screens/home/driver_dashboard_v2.dart`

2. Confirm it correctly calls:
   ```dart
   Supabase.instance.client.rpc('get_driver_dashboard', params: {'p_driver_id': driverId});
   ```

3. Ensure it correctly reads from the JSON returned fields:

   ```
   driver_id, wallet_balance, rating,
   completed_trips, today_earnings, weekly_earnings, recent_trips
   ```

4. Verify that:

   * UI refreshes every 10 seconds
   * Errors are caught via try/catch
   * Loading state is handled with CircularProgressIndicator
   * Pull-to-refresh calls `_fetchDashboard()` again

5. If not already visible on driver home:

   * Import and display `DriverDashboardV2` inside `home_page.dart` or `driver_home_page.dart`
   * Pass the current driver's Supabase ID (`supabase.auth.currentUser!.id`) as the `driverId` argument

6. Do **not** modify any working business logic (auth, trips, sessions).

---

## ✅ EXPECTED RESULTS AFTER AUDIT

* The Driver Dashboard v2 appears in the driver's main dashboard screen.
* Displays live data synced from `get_driver_dashboard`.
* Refreshes automatically and manually.
* No null field errors.
* No schema or field mismatch warnings.

---

## 🧾 TEST DRIVER FOR VERIFICATION

Use this known working ID for local verification:

```
2c1454d6-a53a-40ab-b3d9-2d367a8eab57
```

---

## ✅ OUTPUT FORMAT (for RooCode)

After completion, RooCode should output a JSON audit summary:

```json
{
  "dashboard_widget_found": true,
  "rpc_matched": true,
  "field_mapping_verified": true,
  "ui_auto_refresh_verified": true,
  "null_safety_verified": true,
  "widget_visible_on_home": true,
  "status": "Phase 4 Dashboard Verified"
}