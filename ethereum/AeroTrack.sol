// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title AeroTrack — Aircraft Spare Parts Provenance Contract (Basic Version)
/// @notice Tracks aviation spare parts: registration, ownership transfer, and maintenance logs.
/// @dev Deployed on Remix VM (Osaka EVM) for demonstration purposes.
contract AeroTrack {

    // ─────────────────────────────────────────────
    //  Enumerations
    // ─────────────────────────────────────────────

    /// @notice Lifecycle status of a spare part
    enum PartStatus { Active, Retired }

    // ─────────────────────────────────────────────
    //  Data Structures
    // ─────────────────────────────────────────────

    /// @notice On-chain representation of an aircraft spare part
    struct Part {
        uint256    serialNumber;   // Unique identifier for the part
        string     partName;       // Human-readable name (e.g., "Boeing 737 Landing Gear")
        address    manufacturer;   // Address that originally registered the part
        address    currentOwner;   // Current owner (starts as manufacturer)
        PartStatus status;         // Active or Retired
        bool       exists;         // Guard flag to verify part was registered
    }

    // ─────────────────────────────────────────────
    //  State Variables
    // ─────────────────────────────────────────────

    /// @notice The address that deployed the contract
    address public owner;

    /// @notice Registry of all spare parts, keyed by serial number
    mapping(uint256 => Part) public parts;

    /// @notice Maintenance history for each part, keyed by serial number
    mapping(uint256 => string[]) public maintenanceLogs;

    // ─────────────────────────────────────────────
    //  Events
    // ─────────────────────────────────────────────

    event PartManufactured(
        uint256 indexed serialNumber,
        address indexed manufacturer,
        string partName
    );

    event PartTransferred(
        uint256 indexed serialNumber,
        address indexed from,
        address indexed to
    );

    event MaintenanceLogged(
        uint256 indexed serialNumber,
        address loggedBy,
        string note
    );

    // ─────────────────────────────────────────────
    //  Modifiers
    // ─────────────────────────────────────────────

    /// @dev Restricts caller to the contract deployer
    modifier onlyOwner() {
        require(msg.sender == owner, "AeroTrack: Not the contract owner");
        _;
    }

    /// @dev Ensures the part with given serial number exists
    modifier partMustExist(uint256 serialNumber) {
        require(parts[serialNumber].exists, "AeroTrack: Part does not exist");
        _;
    }

    /// @dev Restricts to the current owner of the part
    modifier onlyCurrentOwner(uint256 serialNumber) {
        require(
            msg.sender == parts[serialNumber].currentOwner,
            "AeroTrack: Caller is not the current owner"
        );
        _;
    }

    // ─────────────────────────────────────────────
    //  Constructor
    // ─────────────────────────────────────────────

    constructor() {
        owner = msg.sender;
        emit PartManufactured(0, msg.sender, "AeroTrack contract initialized");
    }

    // ─────────────────────────────────────────────
    //  Core Functions
    // ─────────────────────────────────────────────

    /// @notice Register a new aircraft spare part on the blockchain
    /// @param serialNumber Unique numeric identifier for the part
    /// @param partName     Human-readable description of the part
    function manufacturePart(uint256 serialNumber, string calldata partName) external {
        require(!parts[serialNumber].exists, "AeroTrack: Part already registered");
        require(bytes(partName).length > 0, "AeroTrack: Part name cannot be empty");

        parts[serialNumber] = Part({
            serialNumber: serialNumber,
            partName:     partName,
            manufacturer: msg.sender,
            currentOwner: msg.sender,
            status:       PartStatus.Active,
            exists:       true
        });

        emit PartManufactured(serialNumber, msg.sender, partName);
    }

    /// @notice Transfer ownership of a spare part to a new address
    /// @param serialNumber The part's unique serial number
    /// @param newOwner     The address of the new owner
    function transferPart(uint256 serialNumber, address newOwner)
        external
        partMustExist(serialNumber)
        onlyCurrentOwner(serialNumber)
    {
        require(newOwner != address(0), "AeroTrack: New owner cannot be zero address");
        require(newOwner != msg.sender,  "AeroTrack: Cannot transfer to yourself");

        address previousOwner = parts[serialNumber].currentOwner;
        parts[serialNumber].currentOwner = newOwner;

        emit PartTransferred(serialNumber, previousOwner, newOwner);
    }

    /// @notice Append a maintenance note to a spare part's history
    /// @dev Only the current owner OR the original manufacturer may log maintenance
    /// @param serialNumber The part's unique serial number
    /// @param note         Description of the maintenance activity
    function logMaintenance(uint256 serialNumber, string calldata note)
        external
        partMustExist(serialNumber)
    {
        require(
            msg.sender == parts[serialNumber].currentOwner ||
            msg.sender == parts[serialNumber].manufacturer,
            "AeroTrack: Only owner or manufacturer can log maintenance"
        );
        require(bytes(note).length > 0, "AeroTrack: Maintenance note cannot be empty");

        maintenanceLogs[serialNumber].push(note);

        emit MaintenanceLogged(serialNumber, msg.sender, note);
    }

    /// @notice Retire a spare part, marking it as no longer in service
    /// @param serialNumber The part's unique serial number
    function retirePart(uint256 serialNumber)
        external
        partMustExist(serialNumber)
        onlyCurrentOwner(serialNumber)
    {
        parts[serialNumber].status = PartStatus.Retired;
    }

    // ─────────────────────────────────────────────
    //  View / Query Functions
    // ─────────────────────────────────────────────

    /// @notice Retrieve the full data record of a spare part
    /// @param serialNumber The part's unique serial number
    /// @return The Part struct containing all part data
    function getPart(uint256 serialNumber)
        external
        view
        partMustExist(serialNumber)
        returns (Part memory)
    {
        return parts[serialNumber];
    }

    /// @notice Retrieve all maintenance log entries for a part
    /// @param serialNumber The part's unique serial number
    /// @return Array of maintenance note strings
    function getMaintenanceLogs(uint256 serialNumber)
        external
        view
        partMustExist(serialNumber)
        returns (string[] memory)
    {
        return maintenanceLogs[serialNumber];
    }

    /// @notice Check whether a part with the given serial number exists
    /// @param serialNumber The part's unique serial number
    /// @return True if part is registered, false otherwise
    function partExists(uint256 serialNumber) external view returns (bool) {
        return parts[serialNumber].exists;
    }
}
