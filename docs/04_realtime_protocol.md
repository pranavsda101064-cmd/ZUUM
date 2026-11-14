# Zuum Real-time Protocol (WebSocket)

Transport: `wss://<host>/ws/{topic}/?token=<access>` (Django Channels + Redis).
All messages JSON. Server → client messages carry `type`; client → server messages
carry `type` and are validated against a whitelist (unknown types rejected).

## Connection lifecycle

1. Connect with current JWT in query (browser WS cannot set headers) or
   `Sec-WebSocket-Protocol` on mobile.
2. Server validates token, subscribes the socket to authorized channel groups only.
3. On disconnect: client reconnects with exponential backoff
   (0.5s → 1s → 2s → 5s → 10s → 30s cap, jitter ±20%), resends `resume` if it had
   a subscription with a `last_event_id`.
4. Server sends `{"type":"hello","server_time":"..."}` on accept.
5. Heartbeat: server pings every 30 s; client must respond (app-level `pong` too).

## Topics & authorization

| Topic | Who subscribes | Groups |
|---|---|---|
| `customer/{user_id}` | that customer | notifications, offers summary |
| `booking/{booking_id}` | customer of booking, assigned driver, staff | status, location, events |
| `driver/{user_id}` | that driver | offers, reassignments, payouts |

Staff sockets additionally join `admin:ops` server-side (server-side only, not a URL
clients can request) — enforced by role claim.

## Message catalogue

### Server → client

```jsonc
{"type":"hello","server_time":"2026-11-12T10:00:00Z"}
{"type":"pong"}
{"type":"booking.status","booking_id":"uuid","status":"ASSIGNED",
 "from":"SEARCHING","at":"...","data":{ /* booking snapshot */ }}
{"type":"booking.offer","booking_id":"uuid","offer_id":"uuid",
 "expires_in_s":15,"pickup":{...},"drop":{...},"fare_paise":23400,
 "service_category":"sedan"}                      // → driver topic
{"type":"booking.offer.expired","offer_id":"uuid"}
{"type":"booking.driver_location","booking_id":"uuid",
 "lat":12.97,"lng":77.59,"heading":210,"speed_mps":8.2,"recorded_at":"..."}
{"type":"booking.eta","booking_id":"uuid","eta_seconds":240,"distance_m":1800}
{"type":"booking.assigned_driver","booking_id":"uuid","driver":{...},"vehicle":{...}}
{"type":"booking.cancelled","booking_id":"uuid","by":"customer","reason":"..."}
{"type":"booking.completed","booking_id":"uuid","fare_paise":23400,
 "payment_state":"paid"}
{"type":"customer.notification","id":"uuid","type":"promo|payout|system",
 "title":"..","body":"..","data":{}}
{"type":"error","code":"..","message":"..","ref":".."}
```

### Client → server

```jsonc
{"type":"pong"}
{"type":"resume","last_event_id":"..."}           // after reconnect
{"type":"booking.location",                        // driver only, throttled
 "lat":..,"lng":..,"heading":..,"speed_mps":..,"recorded_at":"...",
 "booking_id": "uuid" | null}
{"type":"driver.status","online":true|false}       // driver only
```

Location uplink rules (server-enforced, client implements the policy):
- 5 s min interval while on an active trip; 15 s while available; 60 s while
  online outside service geofence; **no sends while stationary >90 s**.
- Server drops out-of-order/old `recorded_at` (last-point-wins per driver).
- Batch window: client may buffer ≤5 pings (max 60 s) when offline, flush on reconnect.

## Ordering & delivery

- Every server event carries `event_id` (monotonic per connection-scope sequence
  stored in Redis, 24 h TTL) — client dedupes and uses it for `resume`.
- Status transitions are **authoritative and ordered per booking**: client applies
  only if `from` matches its current state; on mismatch it requests a REST snapshot
  (`GET /bookings/{id}`).
- Location is best-effort (coalesced); status events are reliable (buffered until
  ack via `resume`, or dropped after TTL).

## Reconnect states in UI

`connected` → `reconnecting (attempt n)` → `offline (show last snapshot)`.
Tracking screen shows a subtle banner; never blocks the user from cancelling.
