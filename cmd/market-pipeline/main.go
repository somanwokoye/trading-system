package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, "Pipeline service healthy")
	})

	log.Printf("Pipeline service starting on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}