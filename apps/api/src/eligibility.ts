import { HttpError, integerField, type Json } from "./http";

export const MIN_DISTANCE_M = 2500;
export const MAX_AGE_S = 6 * 3600;
export const CLOCK_SKEW_S = 60;
export const MAX_PAUSE_S = 30 * 60;
export const MIN_PACE_S_PER_KM = 150;
export const MAX_PACE_S_PER_KM = 1200;
export const MIN_STEPS_PER_MIN = 100;
export const MAX_STEPS_PER_MIN = 230;
export const MAX_AMOUNT_CENTS = 500;
export const CLAIM_WINDOW_S = 2 * 3600;
export const GAP_S = 4 * 3600;

const ACTIVITY_ID = /^[A-Za-z0-9-]{1,64}$/;
const MAX_TIMESTAMP = 4102444800;
const MAX_DISTANCE_M = 500000;

export interface Activity {
  id: string;
  startedAt: number;
  endedAt: number;
  activeSeconds: number;
  distanceM: number;
  kmSplitsS: number[];
  steps: number;
}

export function parseActivity(value: unknown): Activity {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new HttpError(400, "invalid_activity");
  }
  const body = value as Json;
  if (typeof body.id !== "string" || !ACTIVITY_ID.test(body.id)) {
    throw new HttpError(400, "invalid_id");
  }
  const splits = body.km_splits_s;
  if (
    !Array.isArray(splits) ||
    splits.length > MAX_DISTANCE_M / 1000 ||
    !splits.every((split) => Number.isSafeInteger(split) && split > 0)
  ) {
    throw new HttpError(400, "invalid_km_splits_s");
  }
  const activity: Activity = {
    id: body.id,
    startedAt: integerField(body, "started_at", 0, MAX_TIMESTAMP),
    endedAt: integerField(body, "ended_at", 0, MAX_TIMESTAMP),
    activeSeconds: integerField(body, "active_seconds", 1, MAX_TIMESTAMP),
    distanceM: integerField(body, "distance_m", 0, MAX_DISTANCE_M),
    kmSplitsS: splits as number[],
    steps: integerField(body, "steps", 0, 10_000_000),
  };
  if (activity.startedAt >= activity.endedAt) {
    throw new HttpError(400, "invalid_ended_at");
  }
  if (activity.activeSeconds > activity.endedAt - activity.startedAt) {
    throw new HttpError(400, "invalid_active_seconds");
  }
  return activity;
}

const paceInRange = (secondsPerKm: number): boolean =>
  secondsPerKm >= MIN_PACE_S_PER_KM && secondsPerKm <= MAX_PACE_S_PER_KM;

export function checkEligibility(activity: Activity, now: number): void {
  if (activity.endedAt > now + CLOCK_SKEW_S) {
    throw new HttpError(422, "in_future");
  }
  if (activity.endedAt < now - MAX_AGE_S) {
    throw new HttpError(422, "too_old");
  }
  if (activity.distanceM < MIN_DISTANCE_M) {
    throw new HttpError(422, "too_short");
  }
  const fullKm = Math.floor(activity.distanceM / 1000);
  if (activity.kmSplitsS.length !== fullKm) {
    throw new HttpError(422, "bad_splits");
  }
  const splitTotal = activity.kmSplitsS.reduce((total, split) => total + split, 0);
  if (splitTotal > activity.activeSeconds) {
    throw new HttpError(422, "bad_splits");
  }
  if (activity.endedAt - activity.startedAt - activity.activeSeconds > MAX_PAUSE_S) {
    throw new HttpError(422, "too_many_pauses");
  }
  const averagePace = activity.activeSeconds / (activity.distanceM / 1000);
  if (!activity.kmSplitsS.every(paceInRange) || !paceInRange(averagePace)) {
    throw new HttpError(422, "pace_out_of_range");
  }
  const stepsPerMinute = activity.steps / (activity.activeSeconds / 60);
  if (stepsPerMinute < MIN_STEPS_PER_MIN || stepsPerMinute > MAX_STEPS_PER_MIN) {
    throw new HttpError(422, "cadence_out_of_range");
  }
}

export function maxAmountCents(distanceM: number): number {
  return Math.min(MAX_AMOUNT_CENTS, Math.floor(distanceM / 20));
}
