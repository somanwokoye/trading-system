package helpers

import (
    "encoding/json"
    "math/rand"
    "os"
    "path/filepath"
    "testing"
    "time"

    "github.com/shopspring/decimal"
    "github.com/somanwokoye/trading-system/pkg/types"
)

// LoadMarketDataFixture loads test market data from JSON
func LoadMarketDataFixture(t *testing.T, filename string) []types.Tick {
    t.Helper()

    path := filepath.Join("../../testdata/fixtures", filename)
    data, err := os.ReadFile(path)
    if err != nil {
        t.Fatalf("Failed to load fixture %s: %v", filename, err)
    }

    var ticks []types.Tick
    if err := json.Unmarshal(data, &ticks); err != nil {
        t.Fatalf("Failed to unmarshal fixture %s: %v", filename, err)
    }

    return ticks
}

// LoadExpectedResults loads expected calculation results
func LoadExpectedResults(t *testing.T, filename string) map[string]interface{} {
    t.Helper()

    path := filepath.Join("../../testdata/expected", filename)
    data, err := os.ReadFile(path)
    if err != nil {
        t.Fatalf("Failed to load expected results %s: %v", filename, err)
    }

    var results map[string]interface{}
    if err := json.Unmarshal(data, &results); err != nil {
        t.Fatalf("Failed to unmarshal expected results %s: %v", filename, err)
    }

    return results
}

// GenerateTestTicks creates test tick data for specific scenarios
func GenerateTestTicks(count int, startPrice float64, volatility float64) []types.Tick {
    ticks := make([]types.Tick, count)
    price := startPrice

    for i := 0; i < count; i++ {
        // Simple price walk with volatility
        change := (rand.Float64() - 0.5) * volatility
        price += change

        ticks[i] = types.Tick{
            Symbol:    "BTCUSDT",
            Price:     decimal.NewFromFloat(price),
            Volume:    int64(rand.Intn(1000) + 100),
            Timestamp: time.Now().Add(time.Duration(i) * time.Second),
            Side:      types.Buy,
        }
    }

    return ticks
}

// CreateSimpleOHLCV creates basic OHLCV data for testing
func CreateSimpleOHLCV(symbol string, count int, startPrice float64) []types.OHLCV {
    ohlcv := make([]types.OHLCV, count)
    baseTime := time.Now().Truncate(time.Hour)

    for i := 0; i < count; i++ {
        price := startPrice + float64(i)*10 // Simple price increment

        ohlcv[i] = types.OHLCV{
            Symbol:    symbol,
            Open:      decimal.NewFromFloat(price),
            High:      decimal.NewFromFloat(price + 5),
            Low:       decimal.NewFromFloat(price - 3),
            Close:     decimal.NewFromFloat(price + 2),
            Volume:    int64(1000 + rand.Intn(500)),
            Timestamp: baseTime.Add(time.Duration(i) * time.Hour),
            Interval:  time.Hour,
        }
    }

    return ohlcv
}

// LoadPriceSlice loads a simple slice of prices for indicator testing
func LoadPriceSlice(t *testing.T, filename string) []float64 {
    t.Helper()

    path := filepath.Join("../../testdata/fixtures", filename)
    data, err := os.ReadFile(path)
    if err != nil {
        t.Fatalf("Failed to load price data %s: %v", filename, err)
    }

    var prices []float64
    if err := json.Unmarshal(data, &prices); err != nil {
        t.Fatalf("Failed to unmarshal price data %s: %v", filename, err)
    }

    return prices
}

// CreateTestPriceSlice generates a simple price series for testing
func CreateTestPriceSlice(count int, startPrice float64, trend float64) []float64 {
    prices := make([]float64, count)

    for i := 0; i < count; i++ {
        // Linear trend with some randomness
        randomComponent := (rand.Float64() - 0.5) * 0.01 * startPrice
        trendComponent := trend * float64(i)
        prices[i] = startPrice + trendComponent + randomComponent
    }

    return prices
}