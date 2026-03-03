---
trigger: always_on
---

# Project Rules: Rails Architecture & Deployment Stability

## 1. Coding Standards (Zeitwerk Compliance)
**Context:** Rails production uses `eager_load`. Naming mismatches cause boot failures (504 errors).
- **Rule:** Ruby constants MUST match file paths 1:1.
  - `app/controllers/api/v1/feedbacks_controller.rb` -> `class Api::V1::FeedbacksController`
  - **FORBIDDEN:** Defining extra modules inside the file (e.g., `module Feedbacks; class FeedbacksController`) that do not match the directory structure.
- **Rule:** When creating controllers inheriting from `Api::V1::BaseController`, ensure `app/controllers/api/v1/base_controller.rb` exists.
- **Rule:** Do NOT use `before_action` for authentication unless the method (e.g., `authenticate_user!`) is confirmed to exist in the inheritance chain.

## 2. Infrastructure Context (Puma & Nginx)
**Context:** App runs via Capistrano + Systemd + Puma + Nginx Reverse Proxy.
- **Rule:** Puma MUST bind to `127.0.0.1` or a Unix Socket. NEVER bind to `0.0.0.0` (public internet).
- **Rule:** Ignore `HTTP parse error (SSL to non-SSL)` logs in Puma; these are port scanner noise, not the cause of crashes.

## 3. Deployment Safety Protocol
**Instruction:** Before suggesting a deployment command or merging code:
1. Remind user to run: `RAILS_ENV=production bin/rails zeitwerk:check`
2. Remind user to run: `RAILS_ENV=production bin/rails runner 'puts :boot_ok'`
3. IF user reports "504 Gateway Time-out":
   - Priority 1: Check `puma.stdout.log` for `NameError` / `Uninitialized constant`.
   - Priority 2: Verify Rails boot status locally.
   - Priority 3: Check Nginx logs.

## 4. ActiveAdmin View Context & Helper Inclusion
**Context:** ActiveAdmin's view DSL (`index`, `show`, `form`, `csv`) runs inside an isolated Arbre rendering context. Custom Helper methods defined in `app/helpers/` (e.g., data masking, formatting methods) are NOT automatically available in this context.
- **Rule:** In ActiveAdmin resource files (`app/admin/*.rb`), if ANY custom Helper method is used (e.g., `sensitive_field`), you **MUST** explicitly declare `helper YourCustomHelper` inside the resource's `controller do ... end` block.
  - **✅ Correct:**
    ```ruby
    ActiveAdmin.register User do
      controller do
        helper SensitiveFieldHelper # <--- MUST explicitly include
      end
      
      index do
        column(:phone) { |u| sensitive_field(u.phone, mask_method: :mask_phone, admin_user: current_admin_user) }
      end
    end
    ```
  - **❌ FORBIDDEN:**
    Calling `sensitive_field` directly inside `index` or `show` blocks without including the helper in the `controller` block. This passes syntax checks and boot checks, but triggers `NoMethodError` at page render time causing a 500 crash.
- **Why this matters:** Unlike Zeitwerk boot errors (caught by Rule 1 & 3), this error only surfaces at **runtime during page rendering**. `zeitwerk:check` and `boot_ok` will NOT catch it.