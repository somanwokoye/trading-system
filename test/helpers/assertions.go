package helpers

import (
    "math"
    "testing"
    "time"

    "github.com/shopspring/decimal"
    "github.com/stretchr/testify/assert"
)

// AssertDecimalEqual compares decimal values with precision tolerance
func AssertDecimalEqual(t *testing.T, expected, actual decimal.Decimal, tolerance decimal.Decimal) {
    t.Helper()
    diff := expected.Sub(actual).Abs()
    if diff.GreaterThan(tolerance) {
        t.Errorf("Expected %s, got %s (difference: %s, tolerance: %s)",
            expected.String(), actual.String(), diff.String(), tolerance.String())
    }
}

// AssertFloatSliceEqual compares float slices with tolerance
func AssertFloatSliceEqual(t *testing.T, expected, actual []float64, tolerance float64) {
    t.Helper()
    assert.Equal(t, len(expected), len(actual), "Slice lengths must match")

    for i := 0; i < len(expected); i++ {
        if math.Abs(expected[i]-actual[i]) > tolerance {
            t.Errorf("Index %d: expected %f, got %f (tolerance: %f)",
                i, expected[i], actual[i], tolerance)
        }
    }
}

// AssertEventuallyTrue waits for a condition to become true
func AssertEventuallyTrue(t *testing.T, condition func() bool, timeout time.Duration, interval time.Duration) {
    t.Helper()
    deadline := time.Now().Add(timeout)

    for time.Now().Before(deadline) {
        if condition() {
            return
        }
        time.Sleep(interval)
    }

    t.Errorf("Condition did not become true within %v", timeout)
}

// AssertPerformance checks that operation completes within time limit
func AssertPerformance(t *testing.T, operation func(), maxDuration time.Duration) {
    t.Helper()
    start := time.Now()
    operation()
    duration := time.Since(start)

    if duration > maxDuration {
        t.Errorf("Operation took %v, expected less than %v", duration, maxDuration)
    }
}