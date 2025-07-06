package helpers

import (
	"context"
	"database/sql"
	"fmt"
	"testing"

	_ "github.com/lib/pq"
	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/wait"
)

// TestDatabase manages test database lifecycle
type TestDatabase struct {
	container testcontainers.Container
	db        *sql.DB
	dsn       string
}

// NewTestDatabase creates a new test database using testcontainers
func NewTestDatabase(t *testing.T) *TestDatabase {
	t.Helper()

	req := testcontainers.ContainerRequest{
		Image:        "postgres:15",
		ExposedPorts: []string{"5432/tcp"},
		Env: map[string]string{
			"POSTGRES_DB":       "trading_test",
			"POSTGRES_USER":     "test_user",
			"POSTGRES_PASSWORD": "test_password",
		},
		WaitingFor: wait.ForListeningPort("5432/tcp"),
	}

	ctx := context.Background()
	container, err := testcontainers.GenericContainer(ctx, testcontainers.GenericContainerRequest{
		ContainerRequest: req,
		Started:          true,
	})
	if err != nil {
		t.Fatalf("Failed to start test database: %v", err)
	}

	host, err := container.Host(ctx)
	if err != nil {
		t.Fatalf("Failed to get container host: %v", err)
	}

	port, err := container.MappedPort(ctx, "5432")
	if err != nil {
		t.Fatalf("Failed to get container port: %v", err)
	}

	dsn := fmt.Sprintf("postgres://test_user:test_password@%s:%s/trading_test?sslmode=disable",
		host, port.Port())

	db, err := sql.Open("postgres", dsn)
	if err != nil {
		t.Fatalf("Failed to connect to test database: %v", err)
	}

	// Run migrations or setup scripts here
	if err := setupTestSchema(db); err != nil {
		t.Fatalf("Failed to setup test schema: %v", err)
	}

	return &TestDatabase{
		container: container,
		db:        db,
		dsn:       dsn,
	}
}

// DSN returns the database connection string
func (td *TestDatabase) DSN() string {
	return td.dsn
}

// DB returns the database connection
func (td *TestDatabase) DB() *sql.DB {
	return td.db
}

// Cleanup closes the database and stops the container
func (td *TestDatabase) Cleanup(t *testing.T) {
	t.Helper()

	if td.db != nil {
		td.db.Close()
	}

	if td.container != nil {
		ctx := context.Background()
		if err := td.container.Terminate(ctx); err != nil {
			t.Logf("Failed to terminate test database container: %v", err)
		}
	}
}

// ResetTables truncates all tables for clean test state
func (td *TestDatabase) ResetTables(t *testing.T) {
	t.Helper()

	tables := []string{"ticks", "ohlcv", "strategies", "backtest_results"}
	for _, table := range tables {
		_, err := td.db.Exec(fmt.Sprintf("TRUNCATE TABLE %s CASCADE", table))
		if err != nil {
			t.Fatalf("Failed to truncate table %s: %v", table, err)
		}
	}
}

func setupTestSchema(db *sql.DB) error {
	// Create test tables
	schema := `
    CREATE TABLE IF NOT EXISTS ticks (
        id SERIAL PRIMARY KEY,
        symbol VARCHAR(20) NOT NULL,
        price DECIMAL(20,8) NOT NULL,
        volume BIGINT NOT NULL,
        timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
        side SMALLINT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS ohlcv (
        id SERIAL PRIMARY KEY,
        symbol VARCHAR(20) NOT NULL,
        open_price DECIMAL(20,8) NOT NULL,
        high_price DECIMAL(20,8) NOT NULL,
        low_price DECIMAL(20,8) NOT NULL,
        close_price DECIMAL(20,8) NOT NULL,
        volume BIGINT NOT NULL,
        timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
        interval_minutes INTEGER NOT NULL
    );

    CREATE INDEX IF NOT EXISTS idx_ticks_symbol_timestamp ON ticks(symbol, timestamp);
    CREATE INDEX IF NOT EXISTS idx_ohlcv_symbol_timestamp ON ohlcv(symbol, timestamp);
    `

	_, err := db.Exec(schema)
	return err
}
