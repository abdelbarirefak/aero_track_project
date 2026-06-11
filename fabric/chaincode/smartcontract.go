package main

import (
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// ─────────────────────────────────────────────────────────────────────────────
//  Smart Contract Definition
// ─────────────────────────────────────────────────────────────────────────────

// SmartContract provides functions for managing aviation spare parts
type SmartContract struct {
	contractapi.Contract
}

// ─────────────────────────────────────────────────────────────────────────────
//  Data Models
// ─────────────────────────────────────────────────────────────────────────────

// SparePart describes all attributes of an aviation spare part on the ledger.
// Includes all fields added by the student exercises.
type SparePart struct {
	ID              string   `json:"ID"`
	Name            string   `json:"name"`
	Manufacturer    string   `json:"manufacturer"`
	Owner           string   `json:"owner"`
	IsGenuine       bool     `json:"isGenuine"`
	ProductionDate  string   `json:"productionDate"`  // Exercise 1
	MaintenanceLogs []string `json:"maintenanceLogs"` // Exercise 10
}

// HistoryQueryResult holds one record from a part's history on the ledger.
// Used by Exercise 3: GetPartHistory.
type HistoryQueryResult struct {
	TxID      string    `json:"txId"`
	Timestamp time.Time `json:"timestamp"`
	IsDelete  bool      `json:"isDelete"`
	Value     *SparePart `json:"value"`
}

// ─────────────────────────────────────────────────────────────────────────────
//  Ledger Initialization
// ─────────────────────────────────────────────────────────────────────────────

// InitLedger seeds the blockchain with a set of pre-registered spare parts.
// Updated in Exercise 1 to include production dates and maintenance logs.
func (s *SmartContract) InitLedger(ctx contractapi.TransactionContextInterface) error {
	parts := []SparePart{
		{
			ID:              "part1",
			Name:            "Brake Pad",
			Manufacturer:    "Brembo",
			Owner:           "Factory",
			IsGenuine:       true,
			ProductionDate:  "2024-01-15", // Exercise 1
			MaintenanceLogs: []string{},   // Exercise 10
		},
		{
			ID:              "part2",
			Name:            "Oil Filter",
			Manufacturer:    "Bosch",
			Owner:           "Factory",
			IsGenuine:       true,
			ProductionDate:  "2024-03-20", // Exercise 1
			MaintenanceLogs: []string{},   // Exercise 10
		},
		{
			ID:              "part3",
			Name:            "Landing Gear Strut",
			Manufacturer:    "Boeing",
			Owner:           "Factory",
			IsGenuine:       true,
			ProductionDate:  "2024-06-01", // Exercise 1
			MaintenanceLogs: []string{},   // Exercise 10
		},
	}

	for _, part := range parts {
		partJSON, err := json.Marshal(part)
		if err != nil {
			return err
		}
		err = ctx.GetStub().PutState(part.ID, partJSON)
		if err != nil {
			return fmt.Errorf("failed to put %s to world state: %v", part.ID, err)
		}
	}

	return nil
}

// ─────────────────────────────────────────────────────────────────────────────
//  Core CRUD Operations
// ─────────────────────────────────────────────────────────────────────────────

// CreatePart adds a new spare part to the ledger.
// Updated in Exercise 1 to accept productionDate.
// Updated in Exercise 11 to enforce MSP-based access control.
func (s *SmartContract) CreatePart(
	ctx contractapi.TransactionContextInterface,
	id string,
	name string,
	manufacturer string,
	owner string,
	productionDate string, // Exercise 1
) error {

	// ── Exercise 11: Access Control — Only Org1MSP may create parts ──
	mspID, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		return fmt.Errorf("failed to get client MSP ID: %v", err)
	}
	if mspID != "Org1MSP" {
		return fmt.Errorf("unauthorized: only Org1MSP members can create parts, got %s", mspID)
	}

	// Check if part already exists
	exists, err := s.PartExists(ctx, id)
	if err != nil {
		return err
	}
	if exists {
		return fmt.Errorf("the part %s already exists", id)
	}

	part := SparePart{
		ID:              id,
		Name:            name,
		Manufacturer:    manufacturer,
		Owner:           owner,
		IsGenuine:       true,
		ProductionDate:  productionDate,  // Exercise 1
		MaintenanceLogs: []string{},      // Exercise 10 — initialize as empty slice
	}

	partJSON, err := json.Marshal(part)
	if err != nil {
		return err
	}

	return ctx.GetStub().PutState(id, partJSON)
}

// ReadPart returns the part stored in the world state with the given ID.
func (s *SmartContract) ReadPart(ctx contractapi.TransactionContextInterface, id string) (*SparePart, error) {
	partJSON, err := ctx.GetStub().GetState(id)
	if err != nil {
		return nil, fmt.Errorf("failed to read from world state: %v", err)
	}
	if partJSON == nil {
		return nil, fmt.Errorf("the part %s does not exist", id)
	}

	var part SparePart
	err = json.Unmarshal(partJSON, &part)
	if err != nil {
		return nil, err
	}

	return &part, nil
}

// TransferPart updates the owner field of the part with the given ID.
func (s *SmartContract) TransferPart(
	ctx contractapi.TransactionContextInterface,
	id string,
	newOwner string,
) error {
	part, err := s.ReadPart(ctx, id)
	if err != nil {
		return err
	}

	part.Owner = newOwner
	partJSON, err := json.Marshal(part)
	if err != nil {
		return err
	}

	return ctx.GetStub().PutState(id, partJSON)
}

// PartExists returns true when a part with the given ID exists in the world state.
func (s *SmartContract) PartExists(ctx contractapi.TransactionContextInterface, id string) (bool, error) {
	partJSON, err := ctx.GetStub().GetState(id)
	if err != nil {
		return false, fmt.Errorf("failed to read from world state: %v", err)
	}
	return partJSON != nil, nil
}

// ─────────────────────────────────────────────────────────────────────────────
//  Exercise 2: Delete Part
// ─────────────────────────────────────────────────────────────────────────────

// DeletePart removes a spare part from the ledger permanently.
// Once deleted, the part ID can be reused for a new registration.
func (s *SmartContract) DeletePart(ctx contractapi.TransactionContextInterface, id string) error {
	exists, err := s.PartExists(ctx, id)
	if err != nil {
		return err
	}
	if !exists {
		return fmt.Errorf("the part %s does not exist", id)
	}

	return ctx.GetStub().DelState(id)
}

// ─────────────────────────────────────────────────────────────────────────────
//  Exercise 3: Part History
// ─────────────────────────────────────────────────────────────────────────────

// GetPartHistory returns the full modification history of a spare part.
// It iterates the key history from the Fabric ledger and returns a JSON array
// of HistoryQueryResult entries, one per transaction.
func (s *SmartContract) GetPartHistory(
	ctx contractapi.TransactionContextInterface,
	id string,
) ([]HistoryQueryResult, error) {
	resultsIterator, err := ctx.GetStub().GetHistoryForKey(id)
	if err != nil {
		return nil, fmt.Errorf("failed to get history for key %s: %v", id, err)
	}
	defer resultsIterator.Close()

	var results []HistoryQueryResult

	for resultsIterator.HasNext() {
		historyData, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		var record HistoryQueryResult
		record.TxID = historyData.TxId
		record.IsDelete = historyData.IsDelete

		// Convert protobuf timestamp to Go time.Time
		record.Timestamp = historyData.Timestamp.AsTime()

		// Parse the part value (nil if this was a delete)
		if historyData.Value != nil && !historyData.IsDelete {
			var part SparePart
			err = json.Unmarshal(historyData.Value, &part)
			if err != nil {
				return nil, err
			}
			record.Value = &part
		} else {
			record.Value = nil
		}

		results = append(results, record)
	}

	return results, nil
}

// ─────────────────────────────────────────────────────────────────────────────
//  Exercise 10: Maintenance Log
// ─────────────────────────────────────────────────────────────────────────────

// AddMaintenanceLog appends a maintenance event message to the part's history.
// It reads the current part state, appends the message, and puts the updated
// state back onto the ledger — creating a new transaction record.
func (s *SmartContract) AddMaintenanceLog(
	ctx contractapi.TransactionContextInterface,
	id string,
	message string,
) error {
	part, err := s.ReadPart(ctx, id)
	if err != nil {
		return err
	}

	if message == "" {
		return fmt.Errorf("maintenance message cannot be empty")
	}

	// Append the new maintenance message
	part.MaintenanceLogs = append(part.MaintenanceLogs, message)

	// Serialize and store updated part state
	partJSON, err := json.Marshal(part)
	if err != nil {
		return err
	}

	return ctx.GetStub().PutState(id, partJSON)
}

// ─────────────────────────────────────────────────────────────────────────────
//  Main Entry Point
// ─────────────────────────────────────────────────────────────────────────────

func main() {
	chaincode, err := contractapi.NewChaincode(&SmartContract{})
	if err != nil {
		log.Panicf("Error creating AeroTrack chaincode: %v", err)
	}

	if err := chaincode.Start(); err != nil {
		log.Panicf("Error starting AeroTrack chaincode: %v", err)
	}
}
