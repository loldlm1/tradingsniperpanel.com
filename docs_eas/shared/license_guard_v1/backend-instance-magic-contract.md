# Backend Instance Magic Contract

Implemented additive contract for upgraded EAs that need per-chart trade ownership.
This contract keeps the existing license lane for entitlement, online seat,
heartbeat, and request sharing, while assigning a backend-issued runtime
`magic_number` to each EA chart instance.

## Contract Summary
- Legacy EAs keep using lane magic from `POST /api/v1/licenses/verify`.
- Upgraded EAs use the lane only for authorization and request sharing.
- Upgraded runtime trade identity is `broker_account + ea_id + instance_id -> magic_number`.
- Numeric magic values are signed-32-bit-safe positive integers: `1..2147483647`.
- Numeric magic values are unique per broker account across upgraded instances, including different EA IDs.
- Missing or invalid backend magic is fail-closed; live EAs must not generate local/random fallback magic.

## Endpoint
`POST /api/v1/licenses/instance_magic`

Required request fields:
- `source`
- `email`
- `ea_id`
- `license_key`
- `broker_account.company`
- `broker_account.account_number`
- `broker_account.account_type`
- `instance_id`

Example request:
```json
{
  "source": "trading_sniper_floor",
  "email": "user@example.com",
  "ea_id": "pandora_box",
  "license_key": "ENCRYPTED_KEY",
  "broker_account": {
    "company": "Broker Ltd",
    "account_number": 12345678,
    "account_type": "real"
  },
  "instance_id": "pandora_box_7W8S2K5NQ4H9"
}
```

Success response:
```json
{
  "ok": true,
  "instance_id": "pandora_box_7W8S2K5NQ4H9",
  "magic_number": 490123456,
  "trade_identity_scope": "instance"
}
```

Known errors:
- `401`: `invalid_source`, `invalid_key`, `trial_disabled`
- `404`: `user_not_found`, `ea_not_found`, `license_not_found`, `broker_account_not_found`
- `409`: `lane_session_required`
- `422`: `invalid_payload`, `expired`, `missing_instance_id`, `invalid_instance_id`
- `429`: `rate_limited`
- `500`: `internal_error`

## Instance ID Rules
- Opaque EA-generated string.
- Max length: 64 ASCII characters.
- Allowed characters: `A-Z`, `a-z`, `0-9`, `_`, `-`.
- Stable for the same chart instance across restart/recompile.
- Unique enough that two charts do not intentionally share it.
- Must not contain account numbers, license tokens, API keys, broker credentials, emails, proprietary strategy settings, or other sensitive data.

## Runtime Sequence
1. Run existing lane verify/authorization.
2. Resolve or generate the local stable chart `instance_id`.
3. Call `POST /api/v1/licenses/instance_magic`.
4. Validate the returned signed-32-bit-safe positive `magic_number`.
5. Set `g_magic_number` and `CTrade.SetExpertMagicNumber()` from instance magic.
6. Report daily results with the same instance magic.

Call cadence:
- Call after lane authorization is healthy and the local instance magic cache is missing, invalid, or tied to a changed identity.
- Do not call every heartbeat timer tick.
- Followers may call `instance_magic` for their own `instance_id` without becoming heartbeat leaders.
- `lane_session_required` should ask the lane leader to verify/refresh, then retry with backoff.

## Daily Results
- Legacy daily results may use lane magic from `POST /api/v1/licenses/verify`.
- Upgraded daily results use instance magic from `POST /api/v1/licenses/instance_magic`.
- EA deal filtering remains `DEAL_MAGIC == magic_number`.
- Backend dedupe remains one result per UTC day for `broker_account + ea_id + magic_number`.
- Unallocated or invalid magic returns `invalid_magic_number`.

## Rollout Rules
- Deploy backend support first.
- Pandora Box (`ea_id=pandora_box`) is the first production EA target.
- Validate staging/demo with two Pandora Box charts on the same broker account.
- Same `instance_id` must return the same magic on restart.
- Different instance IDs on the same broker account must return different magic values.
- Daily results must be accepted with instance magic and rejected for unallocated magic.
- Upgrade production charts only when flat, or keep the previous EA version managing legacy-magic positions until they close.
- Roll out future EAs by adopting the same shared contract after Pandora Box validation.

## Support And Privacy
- Do not log license keys, encrypted keys, API secrets, broker credentials, raw request bodies, or private customer/billing data.
- Treat `instance_id` as opaque; prefer a truncated or hashed fingerprint in logs.
- Support-safe fields are internal license/broker/EA row IDs, normalized broker identity, numeric `magic_number`, and the `instance_id` fingerprint.
