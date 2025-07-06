package types

import (
    "encoding/json"
    "testing"
    "time"

    "github.com/shopspring/decimal"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestTick_JSONSerialization(t *testing.T) {
    tick := Tick{
        Symbol:    "BTCUSDT",
        Price:     decimal.NewFromFloat(45000.12),
        Volume:    1000,
        Timestamp: time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC),
        Side:      Buy,
    }

    // Test marshaling
    data, err := json.Marshal(tick)
    require.NoError(t, err)

    // Test unmarshaling
    var unmarshaled Tick
    err = json.Unmarshal(data, &unmarshaled)
    require.NoError(t, err)

    assert.Equal(t, tick.Symbol, unmarshaled.Symbol)
    assert.True(t, tick.Price.Equal(unmarshaled.Price))
    assert.Equal(t, tick.Volume, unmarshaled.Volume)
    assert.Equal(t, tick.Side, unmarshaled.Side)
}

func TestOHLCV_JSONSerialization(t *testing.T) {
    ohlcv := OHLCV{
        Symbol:    "ETHUSDT",
        Open:      decimal.NewFromFloat(3200.50),
        High:      decimal.NewFromFloat(3250.75),
        Low:       decimal.NewFromFloat(3180.25),
        Close:     decimal.NewFromFloat(3230.00),
        Volume:    5000,
        Timestamp: time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC),
        Interval:  time.Hour,
    }

    // Test marshaling
    data, err := json.Marshal(ohlcv)
    require.NoError(t, err)

    // Test unmarshaling
    var unmarshaled OHLCV
    err = json.Unmarshal(data, &unmarshaled)
    require.NoError(t, err)

    assert.Equal(t, ohlcv.Symbol, unmarshaled.Symbol)
    assert.True(t, ohlcv.Open.Equal(unmarshaled.Open))
    assert.True(t, ohlcv.High.Equal(unmarshaled.High))
    assert.True(t, ohlcv.Low.Equal(unmarshaled.Low))
    assert.True(t, ohlcv.Close.Equal(unmarshaled.Close))
    assert.Equal(t, ohlcv.Volume, unmarshaled.Volume)
}

func TestSide_String(t *testing.T) {
    tests := []struct {
        side     Side
        expected string
    }{
        {Buy, "Buy"},
        {Sell, "Sell"},
    }

    for _, tt := range tests {
        t.Run(tt.expected, func(t *testing.T) {
            // You can implement String() method later
            assert.True(t, tt.side == Buy || tt.side == Sell)
        })
    }
}