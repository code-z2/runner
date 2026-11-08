import { describe, expect, test } from "bun:test";
import { checkEligibility, maxAmountCents, parseActivity, type Activity } from "../src/eligibility";
import { HttpError } from "../src/http";

const now = 1_800_000_000;

function run(overrides: Partial<Activity> = {}): Activity {
  return {
    id: "run-1",
    startedAt: now - 3600,
    endedAt: now - 1800,
    activeSeconds: 1800,
    distanceM: 5120,
    kmSplitsS: [350, 352, 348, 351, 349],
    steps: 5400,
    ...overrides,
  };
}

function reason(activity: Activity): string | null {
  try {
    checkEligibility(activity, now);
    return null;
  } catch (error) {
    return (error as HttpError).code;
  }
}

describe("checkEligibility", () => {
  test("accepts a normal 5 km run", () => {
    expect(reason(run())).toBeNull();
  });

  test("rejects runs under 2.5 km", () => {
    expect(reason(run({ distanceM: 2400, kmSplitsS: [350, 350] }))).toBe("too_short");
  });

  test("requires one split per full km", () => {
    expect(reason(run({ kmSplitsS: [350, 350, 350, 350] }))).toBe("bad_splits");
  });

  test("rejects splits that add up to more than the active time", () => {
    expect(reason(run({ activeSeconds: 1700, kmSplitsS: [350, 350, 350, 350, 350] }))).toBe("bad_splits");
  });

  test("rejects a split faster than 2:30 per km", () => {
    expect(reason(run({ kmSplitsS: [140, 352, 348, 351, 349] }))).toBe("pace_out_of_range");
  });

  test("rejects a split slower than 20:00 per km", () => {
    expect(
      reason(run({ startedAt: now - 9000, activeSeconds: 7200, kmSplitsS: [1300, 352, 348, 351, 349], steps: 20000 })),
    ).toBe("pace_out_of_range");
  });

  test("rejects step rates outside 100 to 230 per minute", () => {
    expect(reason(run({ steps: 2000 }))).toBe("cadence_out_of_range");
    expect(reason(run({ steps: 8000 }))).toBe("cadence_out_of_range");
  });

  test("rejects more than 30 minutes of pauses", () => {
    expect(reason(run({ startedAt: now - 5700 }))).toBe("too_many_pauses");
  });

  test("rejects runs that ended more than 6 hours ago", () => {
    expect(reason(run({ startedAt: now - 25000, endedAt: now - 23200 }))).toBe("too_old");
  });

  test("rejects runs that end in the future", () => {
    expect(reason(run({ startedAt: now - 1000, endedAt: now + 800 }))).toBe("in_future");
  });
});

describe("maxAmountCents", () => {
  test("pays 50 cents per km, capped at 500", () => {
    expect(maxAmountCents(2500)).toBe(125);
    expect(maxAmountCents(5120)).toBe(256);
    expect(maxAmountCents(10000)).toBe(500);
    expect(maxAmountCents(42195)).toBe(500);
  });
});

describe("parseActivity", () => {
  const valid = {
    id: "8a4e2c1d-1111-4f00-9c00-000000000001",
    started_at: now - 3600,
    ended_at: now - 1800,
    active_seconds: 1800,
    distance_m: 5120,
    km_splits_s: [350, 352, 348, 351, 349],
    steps: 5400,
  };

  test("reads a valid activity", () => {
    expect(parseActivity(valid).distanceM).toBe(5120);
  });

  test("rejects active time longer than the run", () => {
    expect(() => parseActivity({ ...valid, active_seconds: 4000 })).toThrow("invalid_active_seconds");
  });

  test("rejects missing steps", () => {
    expect(() => parseActivity({ ...valid, steps: null })).toThrow("invalid_steps");
  });

  test("rejects non-integer splits", () => {
    expect(() => parseActivity({ ...valid, km_splits_s: [350.5, 350, 350, 350, 350] })).toThrow("invalid_km_splits_s");
  });
});
