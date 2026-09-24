# Medico API

Node backend for the Medico patient app — authentication, the doctor
directory, availability and booking.

Express 5 · TypeScript · MongoDB (Mongoose) · JWT access + rotating refresh
tokens.

## Running it

```bash
cp .env.example .env          # then fill in the two secrets
npm install
npm run seed                  # 6 doctors + a demo patient and two conversations
npm run dev                   # http://localhost:4000
```

Generate the secrets with:

```bash
node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"
```

Seeded sign-in: `ada@example.com` / `medico1234`.

```bash
npm test          # 30 tests, needs a MongoDB on 127.0.0.1:27017
npm run typecheck
npm run build && npm start
```

## Endpoints

All under `/api/v1`. Authenticated routes take `Authorization: Bearer <access token>`.

### Auth
| Method | Path | Notes |
|---|---|---|
| POST | `/auth/sign-up` | → session |
| POST | `/auth/sign-in` | → session; locks after 5 failures |
| POST | `/auth/refresh` | rotates the refresh token |
| POST | `/auth/sign-out` | revokes one refresh token |
| POST | `/auth/sign-out-everywhere` | revokes all of them |
| POST | `/auth/password-reset/request` | always 200, never says if the email exists |
| POST | `/auth/password-reset/confirm` | single-use token, 30-minute life |
| GET | `/auth/me` | the signed-in patient |

### Directory
| Method | Path | Notes |
|---|---|---|
| GET | `/doctors` | `?specialty=Cardiology&q=moore&page=1&perPage=20` |
| GET | `/doctors/specialties` | derived from the directory, never a second list |
| GET | `/doctors/:id` | |
| GET | `/doctors/:id/availability` | `?from=ISO&days=7` |

### Messages
| Method | Path | Notes |
|---|---|---|
| GET | `/threads` | `?unread=true`; newest activity first, doctor populated |
| POST | `/threads` | `{ subject, body, aboutDoctorId? }` → the thread |
| GET | `/threads/:id/messages` | the thread and its messages, oldest first |
| POST | `/threads/:id/messages` | `{ body }` |
| POST | `/threads/:id/read` | marks the clinic's messages read |

### The patient's own account
| Method | Path | Notes |
|---|---|---|
| GET | `/me` | the profile, plus saved/upcoming/unread counts |
| PATCH | `/me` | `{ name }` — email is deliberately not changeable |
| POST | `/me/password` | `{ currentPassword, newPassword }`; ends every other session |
| DELETE | `/me` | `{ password }` — irreversible, cascades, frees booked slots |

### Appointments & saved doctors
| Method | Path | Notes |
|---|---|---|
| POST | `/appointments` | `{ doctorId, startsAt, reason? }` |
| GET | `/appointments` | `?status=booked&when=upcoming` |
| POST | `/appointments/:id/cancel` | |
| GET·PUT·DELETE | `/me/favourites[/:doctorId]` | |

## Error contract

Every failure is `{ "error": { "code", "message", "details"? } }`. The `code`
values mirror `AuthFailure` in `lib/features/auth/data/auth_service.dart` — the
Flutter client switches on them to decide what to *offer* the patient, so
`account_locked` is what puts a "Reset password" button under the error banner.
**Renaming a code is a breaking API change.**

`invalid_credentials` · `account_locked` · `email_taken` · `validation_failed` ·
`unauthorized` · `forbidden` · `not_found` · `slot_taken` · `slot_in_past` ·
`rate_limited` · `unknown`

Messages are written to be shown to a patient as-is: they say what happened and
what to do next.

## The client

The Flutter app in `lib/` talks to this server and to nothing else. The pieces
worth knowing about:

| Where | What it does |
|---|---|
| `lib/core/api/api_client.dart` | Every request. Attaches the access token, turns the error envelope into a typed `ApiException`, and refreshes-and-replays on a 401. |
| `lib/core/auth/session_controller.dart` | Who is signed in. One object, so a token rotated by a background request and the name in the greeting cannot disagree. |
| `lib/features/auth/data/http_auth_service.dart` | `/auth/*`, and the one place an error `code` becomes something a screen can answer. |
| `lib/features/doctors/data/*_repository.dart` | The directory, availability, saved doctors, booking and cancelling. |
| `lib/features/appointments/` | What the patient has booked — upcoming, past and cancelled, with a cancel that gives the slot back. |
| `lib/features/doctors/presentation/saved_doctors_screen.dart` | The doctors they kept, with an undo on every removal. |
| `lib/features/messages/` | Conversations with the practice, and one thread read and replied to. |
| `lib/features/profile/` | The account: name, password, sign out, and deleting it. |
| `lib/app/app_scope.dart` | Hands those to the screens. A screen names what it needs; a test passes a fake. |

Point it somewhere else at build time:

```bash
flutter run --dart-define=MEDICO_API_BASE_URL=https://api.example.com/api/v1
```

The default is `http://localhost:4000/api/v1`, except on the Android emulator,
where it is `http://10.0.2.2:4000/api/v1` — `localhost` there is the emulator.
iOS needs `NSAllowsLocalNetworking` to reach a plain-HTTP local server, which
is already in `ios/Runner/Info.plist`.

**A refresh token lives in `shared_preferences`, which is not secure storage.**
It is revocable and rotates on every use, so a stolen one is detectable and
killable in a way a password is not — but the Keychain is where it belongs. The
swap is one class: `PrefsSessionStore`.

## The decisions worth knowing

**A conversation is with the practice, not with a doctor.** `aboutDoctorId` is
what a thread is *about* — the appointment it concerns — and never who is
obliged to answer it. A thread addressed to a named consultant implies that
consultant is reading it, which no clinic can promise, and that is the kind of
promise that ends with someone's chest pain sitting unread over a weekend. The
client says so on the screen, above the keyboard, with the number to call
instead.

**Deleting an account asks for the password again.** The session alone is not
enough for the one action in the app that cannot be undone — a phone is
unlocked and in somebody else's hand often enough. The delete cascades through
messages, threads, appointments and tokens before the user row, children first,
so a failure halfway leaves nothing orphaned and nothing signed-into. Deleting
the appointments also hands the slots back: the index that prevents double
booking is partial on `status: 'booked'`, so removing the row reopens the time.

There is a `TODO(retention)` on it. A real practice usually *cannot* erase
clinical history on request — appointments and messages carry statutory
retention — so this would become "close the account, keep the record, make it
unreachable". That is a policy decision, not a code one.

**Doctor portraits are bundled, not hosted.** `photoUrl` holds an asset path
like `assets/images/doctors/moore.png`, so the directory draws with no image
requests at all and works offline. The field takes an `https://` URL just as
happily — `MedicoAvatar` renders either and falls back to the doctor's initials
when neither loads — for the day the practice has photographs of its own.

**A thread carries its own last message.** `lastMessageAt`, `lastMessagePreview`
and `unreadForPatient` are copies of facts that live in the messages
collection. Drawing ten rows without them is ten more queries, and the list
screen shows exactly these three things per row.

**Double booking is prevented by the database, not by application code.** A
partial unique index on `(doctorId, startsAt)` where `status: 'booked'` is the
referee. Checking "is this slot free?" and then inserting is two operations, and
two patients tapping Confirm in the same instant both pass the check. There is a
test that fires ten simultaneous bookings at one slot and asserts exactly one
row survives. The index is *partial* so cancelling frees the slot again. A second
index stops one patient holding two appointments at the same time.

**Slots are generated, not stored.** A stored slot table has to be back-filled
forever and goes stale the moment a doctor's hours change. `src/utils/slots.ts`
expands clinic hours on read and subtracts what is booked.

**Passwords use Node's built-in scrypt.** bcrypt and argon2 are both fine and
both need a native build that breaks on some machines and CI images. For a
service that must come up reliably, no install step was worth more than the
marginal difference in hardness. Parameters are stored with the hash
(`scrypt$1$salt$hash`) so they can be raised later without invalidating anyone.

**Refresh tokens are opaque and stored hashed.** A JWT refresh token is
self-validating, which is exactly the wrong property — it cannot be revoked
before it expires. These are random strings; only a SHA-256 is kept, so a
database dump is not a set of working sessions. They rotate on every use, and
**a retired token coming back revokes the entire chain** — replay is the signal
that a token has been copied, and the honest client and the thief are
indistinguishable at that point.

**Sign-in does the same work whether or not the account exists.** An early
return on an unknown email leaks which addresses are registered patients, and
the timing difference alone is a disclosure. Password reset is the same: the
response is identical either way, which is what makes the app's "If there is a
Medico account for that address" honest rather than a white lie.

**Nothing logs a request body.** Sign-in bodies contain passwords and this is a
health app.

## Not built yet

- **Mail.** `password-reset/request` returns `devToken` outside production so
  the flow is testable; wire a transactional provider and delete that field.
  See `TODO(mail)` in `src/modules/auth/auth.service.ts`.
- **SSO.** The app shows Google and Apple buttons; neither has a backend route.
  They need provider token verification, not a password path.
- **Time zones.** Slots are computed in UTC. A real clinic has a local
  timezone and the client renders in the device's — fine while they agree,
  wrong the moment a clinic is not in UTC.
- ~~**The Flutter client still runs on mock data.**~~ Done. The app signs in,
  browses the directory, saves doctors and books appointments against this
  server. See "The client" above.
