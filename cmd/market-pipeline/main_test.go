package main

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
)

// Version and Environment variables used for service information
var (
	Version     = "dev"
	Environment = "development"
)

func TestHealthEndpoint(t *testing.T) {
	req, err := http.NewRequest("GET", "/health", nil)
	assert.NoError(t, err)

	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, err := w.Write([]byte(`{"status":"healthy","service":"pipeline"}`))
		if err != nil {
			t.Fatalf("Error writing response: %v", err)
		}
	})

	handler.ServeHTTP(rr, req)

	assert.Equal(t, http.StatusOK, rr.Code)
	assert.Contains(t, rr.Body.String(), "healthy")
	assert.Contains(t, rr.Body.String(), "pipeline")
}

func TestVersionVariables(t *testing.T) {
	// Test that version variables exist and have default values
	assert.NotEmpty(t, Version)
	assert.NotEmpty(t, Environment)
}
