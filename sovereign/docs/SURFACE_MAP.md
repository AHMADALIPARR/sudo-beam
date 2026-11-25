<!--
Copyright (C) 2026 AHMADALIPARR

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, version 3 of the License.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.

SPDX-License-Identifier: AGPL-3.0-only
-->

# Surface map — sudoplatform (public) -> stubs

Source, 2026-11-24: public org listing
`https://api.github.com/orgs/sudoplatform/repos?per_page=100`
(67 repos; names / language / description only, no code fetched)
and `https://docs.sudoplatform.com/llms.txt` (guide titles only).

No repo was cloned, no file was copied. This map records only
which public SDK family each stub module stands in for.

## Core — implemented as stubs in `control/lib/sudo/`

| Public SDK family (repo pattern) | Stub module | Public operations stubbed |
|---|---|---|
| `sudo-user-*` — User SDK | `Sudo.User` | `register/1`, `sign_in/1`, `sign_out/0`, `get_user/0`, `reset_password/1`, `delete_user/0` |
| `sudo-profiles-*` — Profiles / Sudos | `Sudo.Profiles` | `create_sudo/1`, `list_sudos/1`, `get_sudo/1`, `update_sudo/2`, `delete_sudo/1` |
| `sudo-entitlements-*`, `sudo-entitlements-admin-*` | `Sudo.Entitlements` | `get_entitlements/1`, `redeem_entitlement/2`, `list_entitlement_definitions/1`, `create_entitlement_set/1`, `apply_entitlements_sequence/2`, `get_user_entitlements/1` |
| `sudo-email-*` | `Sudo.Email` | `create_email_address/1`, `list_email_addresses/1`, `list_folders/1`, `send_message/1`, `list_messages/2`, `create_draft/1`, `schedule_send/2`, `create_alias/1`, `block_address/2` |
| `sudo-telephony-*` | `Sudo.Telephony` | `create_phone_number/1`, `list_phone_numbers/1`, `send_message/1`, `list_messages/2`, `subscribe/1` |
| `sudo-virtual-cards-*`, `sudo-virtual-cards-simulator-*`, `sudo-virtual-cards-admin-*` | `Sudo.VirtualCards` | `create_card/1`, `list_cards/1`, `get_card/1`, `update_card/2`, `suspend_card/1`, `list_transactions/2` |
| `sudo-notification-*`, `sudo-notification-web` | `Sudo.Notification` | `register_device/1`, `unregister_device/1`, `list_notifications/1` |
| `sudo-key-manager-*` | `Sudo.KeyManager` | `create_key/1`, `get_key/1`, `delete_key/1`, `rotate_key/1` |
| `sudo-config-manager-*` | `Sudo.ConfigManager` | `get_config/0`, `refresh_config/0` |
| `sudo-api-client-*` | `Sudo.ApiClient` | `request/1` — the single outbound boundary, stubbed |
| `sudo-common-js`, `sudo-common-internal` | `Sudo.Common` | shared `t:result/0`, error types, pagination (`list_input/0`, `page/0`) |
| `sudo-logging-*` | `Sudo.Logging` | `log/2` (local only, no remote sink in stub) |
| `sudo-secure-id-verification-*` | `Sudo.SecureIdVerification` | `start_verification/1`, `get_verification/1`, `cancel_verification/1` |
| `sudo-di-relay-*`, `sudo-di-edge-agent-*` | `Sudo.Relay` | `create_postbox/1`, `list_postboxes/1`, `send_message/1`, `list_messages/2`, `create_connection/1` |
| `sudo-privacy-interaction-*`, `sudo-secure-communications-*`, `sudo-ad-tracker-blocker-*`, `sudo-site-reputation-*`, `sudo-operations-*` | — (not stubbed) | Named here for completeness; no module yet. Add one file per family following `Sudo.Email` as the template. |

## Sample / supporting repos — not stubbed (no SDK surface)

`samples-android`, `samples-ios`, `samples-js`, `web-ui`,
`sudo-di-cloud-agent-example-js`, `sudo-di-edge-agent-sample-*`,
`aws-mobile-appsync-sdk-ios`, `matrix-rust-sdk-swift`.

## Notes on fidelity

- Function names are descriptive English derived from the docs
  guide titles (e.g. "Manage Email Addresses", "Redeeming
  Entitlements"), not vendor method names. Do not treat them as
  exact upstream API names.
- Types are deliberately coarse (`map()`, `binary()`,
  `Sudo.Common.page()`). Tighten a type only when you implement
  that stub against a real, documented request/response shape.
- Goldilocks field: `p = 2^64 - 2^32 + 1 = 18446744069414584321`,
  in `kernels/field_ops.mojo`. That constant is public mathematics,
  not vendor code.
