import type { Doctor } from '../models/doctor.model.js';

export interface Slot {
  /** ISO-8601 instant the appointment starts. */
  startsAt: string;
  /** "09:30" — what the client renders on the chip. */
  label: string;
  available: boolean;
}

export interface Day {
  /** "2026-09-22" */
  date: string;
  weekday: number;
  slots: Slot[];
  openCount: number;
}

function label(minutes: number): string {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
}

function isoDate(day: Date): string {
  return `${day.getUTCFullYear()}-${String(day.getUTCMonth() + 1).padStart(2, '0')}-${String(day.getUTCDate()).padStart(2, '0')}`;
}

/**
 * Expands a doctor's clinic hours into concrete slots, minus what is booked.
 *
 * Generated rather than stored: a stored slot table has to be back-filled
 * forever and goes stale the moment hours change. The booked set is the only
 * thing that needs to be looked up.
 *
 * Slots already in the past are returned as unavailable rather than omitted,
 * so a day the patient is looking at does not silently reflow under them.
 */
export function buildDays(
  doctor: Pick<Doctor, 'workingHours' | 'sessionMinutes'>,
  from: Date,
  dayCount: number,
  bookedInstants: Set<number>,
  now: Date = new Date(),
): Day[] {
  const step = doctor.sessionMinutes || 30;
  const hours = doctor.workingHours;
  const days: Day[] = [];

  for (let offset = 0; offset < dayCount; offset++) {
    const day = new Date(
      Date.UTC(
        from.getUTCFullYear(),
        from.getUTCMonth(),
        from.getUTCDate() + offset,
      ),
    );

    // JS Sunday is 0; the schema and the client both use ISO 1–7.
    const weekday = day.getUTCDay() === 0 ? 7 : day.getUTCDay();
    const open = (hours?.weekdays ?? []).includes(weekday);

    const slots: Slot[] = [];
    if (open) {
      const start = hours?.startMinute ?? 540;
      const end = hours?.endMinute ?? 960;
      const breakStart = hours?.breakStartMinute ?? -1;
      const breakEnd = hours?.breakEndMinute ?? -1;

      for (let minute = start; minute + step <= end; minute += step) {
        const withinBreak = minute >= breakStart && minute < breakEnd;
        if (withinBreak) continue;

        const startsAt = new Date(day.getTime() + minute * 60 * 1000);
        const taken = bookedInstants.has(startsAt.getTime());
        const past = startsAt.getTime() <= now.getTime();

        slots.push({
          startsAt: startsAt.toISOString(),
          label: label(minute),
          available: !taken && !past,
        });
      }
    }

    days.push({
      date: isoDate(day),
      weekday,
      slots,
      openCount: slots.filter((slot) => slot.available).length,
    });
  }

  return days;
}
