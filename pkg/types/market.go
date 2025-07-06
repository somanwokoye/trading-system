package types

import (
    "time"
    "github.com/shopspring/decimal"
)

// Side represents buy or sell side
type Side int8

const (
    Buy Side = iota
    Sell
)

// Tick represents a single trade tick
type Tick struct {
    Symbol    string          `json:"symbol"`
    Price     decimal.Decimal `json:"price"`
    Volume    int64           `json:"volume"`
    Timestamp time.Time       `json:"timestamp"`
    Side      Side            `json:"side"`
}

// OHLCV represents open, high, low, close, volume data
type OHLCV struct {
    Symbol    string          `json:"symbol"`
    Open      decimal.Decimal `json:"open"`
    High      decimal.Decimal `json:"high"`
    Low       decimal.Decimal `json:"low"`
    Close     decimal.Decimal `json:"close"`
    Volume    int64           `json:"volume"`
    Timestamp time.Time       `json:"timestamp"`
    Interval  time.Duration   `json:"interval"`
}

// OrderBookEntry represents a single order book entry
type OrderBookEntry struct {
    Price    decimal.Decimal `json:"price"`
    Quantity decimal.Decimal `json:"quantity"`
}

// OrderBook represents the current order book state
type OrderBook struct {
    Symbol    string           `json:"symbol"`
    Bids      []OrderBookEntry `json:"bids"`
    Asks      []OrderBookEntry `json:"asks"`
    Timestamp time.Time        `json:"timestamp"`
}