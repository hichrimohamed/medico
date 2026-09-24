# Product

## Register

product

## Users

Patients using Medico on their own phone. They are at home, in a waiting room, or in bed — often one-handed, sometimes unwell, occasionally anxious about what they are about to read. They are not power users and will not return often enough to build muscle memory, so every screen has to be legible cold.

The job on the auth surface is narrow and unglamorous: get back into the account with as little friction as possible, so they can book, reschedule, or check an appointment and look at their records. Nobody wants to be on the login screen. Success is measured in how fast it disappears.

## Product Purpose

Medico is a patient-facing mobile app (Flutter, iOS + Android) for managing appointments and personal health records with a care provider. The auth flow is the front door: it has to feel safe enough to hand over credentials to, and quick enough not to be the reason someone gives up on booking.

Success looks like: a first-time visitor understands what the app is within two seconds of the screen appearing; a returning patient signs in without reading anything; nobody is ever stuck on an error they cannot act on.

## Brand Personality

**Calm, clinical, human.** The voice is plain and second-person — "Sign in to manage your appointments", not "Access your healthcare portal". No exclamation marks, no wellness-speak, no cheerleading. Errors state what happened and what to do next, and never blame the patient.

Emotionally the target is *reassurance*: this is a real, careful institution that will not lose your data, staffed by people. The illustrated artwork carries the human half; the interface carries the careful half by being quiet, consistent, and predictable.

## Anti-references

- **Consumer fintech energy.** Gradient blobs, oversized rounded everything, playful microcopy, confetti. Health is not a game.
- **Hospital-portal brutalism.** Dense gray forms, system-default controls, 1998 table layouts, jargon labels ("MRN", "Patient Portal Access").
- **Wellness-app softness.** Pastel gradients, thin display serifs, meditation-app vagueness, motivational copy.
- **Decoration without function.** Glass cards, drop shadows for their own sake, page-load choreography that makes a patient wait to type.

## Design Principles

1. **The form is the product.** The artwork sets the tone; it never competes with the input the patient came to fill in. Below tablet width it yields.
2. **Legible cold, one-handed, at arm's length.** Verified contrast, real touch targets, no text smaller than it has to be. An unwell patient in bad light is the design target, not a designer at a 5K display.
3. **Never a dead end.** Every error names a next action. Every failure state keeps what the patient already typed.
4. **Earned familiarity over invention.** Standard form controls, standard autofill, standard keyboard behaviour. Novelty on an auth screen is a bug.
5. **Motion reports state, nothing else.** Loading, focus, validation, disclosure. No entrance choreography.

## Accessibility & Inclusion

- **WCAG 2.2 AA.** Body text ≥ 4.5:1, placeholders held to the same bar (not the muted-gray default), interactive boundaries ≥ 3:1.
- Touch targets ≥ 48dp with real spacing between them.
- Full platform autofill and password-manager support; the OS keyboard is never fought.
- Semantic labels on every control and on the decorative artwork (marked decorative, not narrated).
- Text scaling to 200% must not clip or overflow any auth screen.
- Reduced-motion honoured system-wide: every transition degrades to an instant state change.
- Colour is never the only signal — errors carry an icon and text, not just a red border.
