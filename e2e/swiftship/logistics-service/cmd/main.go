package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"

	"golang.org/x/crypto/ssh"
	"golang.org/x/net/http2"
)

// VULN-SEED: imported to demonstrate CVE-2025-22869 and CVE-2023-44487
var (
	_ *ssh.ServerConfig // golang.org/x/crypto/ssh — CVE-2025-22869
	_ *http2.Server     // golang.org/x/net/http2  — CVE-2023-44487
)

type HealthResponse struct {
	Status  string `json:"status"`
	Service string `json:"service"`
}

type Shipment struct {
	ShipmentID  string `json:"shipment_id"`
	Status      string `json:"status"`
	Origin      string `json:"origin"`
	Destination string `json:"destination"`
	EtaDays     int    `json:"eta_days"`
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(HealthResponse{Status: "UP", Service: "logistics-service"})
}

func shipmentHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	shipmentID := r.URL.Query().Get("id")
	if shipmentID == "" {
		shipmentID = "SHP-20240001"
	}
	json.NewEncoder(w).Encode(Shipment{
		ShipmentID:  shipmentID,
		Status:      "in_transit",
		Origin:      "London Heathrow",
		Destination: "New York JFK",
		EtaDays:     2,
	})
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8084"
	}

	http.HandleFunc("/health", healthHandler)
	http.HandleFunc("/shipments", shipmentHandler)

	fmt.Printf("SwiftShip logistics-service listening on :%s\n", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
