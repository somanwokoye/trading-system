package helpers

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestLoadPriceSlice(t *testing.T) {
	prices := CreateTestPriceSlice(10, 100.0, 0.5)

	assert.Len(t, prices, 10)
	assert.Greater(t, prices[0], 90.0) // Should be around 100 with some variance
	assert.Less(t, prices[0], 110.0)
}

func TestGenerateTestTicks(t *testing.T) {
	ticks := GenerateTestTicks(5, 45000.0, 100.0)

	assert.Len(t, ticks, 5)

	for _, tick := range ticks {
		assert.Equal(t, "BTCUSDT", tick.Symbol)
		assert.Greater(t, tick.Volume, int64(0))
		assert.False(t, tick.Timestamp.IsZero())
	}
}

func TestCreateSimpleOHLCV(t *testing.T) {
	ohlcv := CreateSimpleOHLCV("BTCUSDT", 3, 45000.0)

	require.Len(t, ohlcv, 3)

	for i, bar := range ohlcv {
		assert.Equal(t, "BTCUSDT", bar.Symbol)
		assert.True(t, bar.High.GreaterThanOrEqual(bar.Open))
		assert.True(t, bar.High.GreaterThanOrEqual(bar.Close))
		assert.True(t, bar.Low.LessThanOrEqual(bar.Open))
		assert.True(t, bar.Low.LessThanOrEqual(bar.Close))

		if i > 0 {
			// Each bar should be 1 hour after the previous
			expectedTime := ohlcv[i-1].Timestamp.Add(time.Hour)
			assert.Equal(t, expectedTime, bar.Timestamp)
		}
	}
}
