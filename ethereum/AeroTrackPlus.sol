// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title AeroTrackPlus — Aircraft Spare Parts Contract with Certified Manufacturer Access Control
/// @notice Extends AeroTrack with a strict whitelist: only addresses approved by the contract
///         owner are permitted to manufacture (register) parts on the blockchain.
/// @dev Deployed on Remix VM (Osaka EVM). Demonstrates role-based access control in Solidity.
contract AeroTrackPlus {

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
        uint256    serialNumber;      // Unique identifier
        string     partName;          // e.g., "Boeing 737 Landing Gear"
        address    manufacturer;      // Certified manufacturer address
        string     manufacturerName;  // Certified company name (e.g., "Boeing")
        address    currentOwner;      // Current owner (starts as manufacturer)
        PartStatus status;            // Active or Retired
        bool       exists;            // Guard flag
    }

    // ─────────────────────────────────────────────
    //  State Variables
    // ─────────────────────────────────────────────

    /// @notice The address that deployed the contract (super-admin)
    address public owner;

    /// @notice Registry of all spare parts, keyed by serial number
    mapping(uint256 => Part) public parts;

    /// @notice Maintenance history for each part, keyed by serial number
    mapping(uint256 => string[]) public maintenanceLogs;

    /// @notice Whitelist of certified manufacturer addresses
    mapping(address => bool) public certifiedManufacturers;

    /// @notice Company names associated with certified manufacturers
    mapping(address => string) public manufacturerNames;

    // ─────────────────────────────────────────────
    //  Events
    // ─────────────────────────────────────────────

    event ManufacturerApproved(
        address indexed manufacturer,
        string companyName
    );

    event ManufacturerRevoked(
        address indexed manufacturer
    );

    event PartManufactured(
        uint256 indexed serialNumber,
        address indexed manufacturer,
        string manufacturerName,
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

    /// @dev Restricts to the contract deployer (owner)
    modifier onlyOwner() {
        require(msg.sender == owner, "AeroTrackPlus: Not the contract owner");
        _;
    }

    /// @dev Restricts to addresses in the certified manufacturers whitelist
    modifier onlyCertifiedManufacturer() {
        require(
            certifiedManufacturers[msg.sender],
            "Not a certified manufacturer"
        );
        _;
    }

    /// @dev Ensures the part with given serial number is registered
    modifier partMustExist(uint256 serialNumber) {
        require(parts[serialNumber].exists, "AeroTrackPlus: Part does not exist");
        _;
    }

    /// @dev Restricts to the current owner of the part
    modifier onlyCurrentOwner(uint256 serialNumber) {
        require(
            msg.sender == parts[serialNumber].currentOwner,
            "AeroTrackPlus: Caller is not the current owner"
        );
        _;
    }

    // ─────────────────────────────────────────────
    //  Constructor
    // ─────────────────────────────────────────────

    constructor() {
        owner = msg.sender;
    }

    // ─────────────────────────────────────────────
    //  Access Control Functions (Owner Only)
    // ─────────────────────────────────────────────

    /// @notice Certify an address as an approved manufacturer
    /// @dev Only the contract owner (deployer) can call this
    /// @param manufacturer The Ethereum address to certify
    /// @param companyName  The official company name (e.g., "Boeing", "Airbus")
    function approveManufacturer(address manufacturer, string calldata companyName)
        external
        onlyOwner
    {
        require(manufacturer != address(0), "AeroTrackPlus: Invalid address");
        require(bytes(companyName).length > 0, "AeroTrackPlus: Company name cannot be empty");

        certifiedManufacturers[manufacturer] = true;
        manufacturerNames[manufacturer] = companyName;

        emit ManufacturerApproved(manufacturer, companyName);
    }

    /// @notice Revoke certification from a manufacturer
    /// @dev Only the contract owner can call this
    /// @param manufacturer The address whose certification is being revoked
    function revokeManufacturer(address manufacturer)
        external
        onlyOwner
    {
        require(certifiedManufacturers[manufacturer], "AeroTrackPlus: Address is not certified");

        certifiedManufacturers[manufacturer] = false;
        // Note: manufacturerNames entry is kept for historical reference

        emit ManufacturerRevoked(manufacturer);
    }

    /// @notice Check if an address is a certified manufacturer
    /// @param manufacturer The address to check
    /// @return certified True if the address is certified
    /// @return companyName The company name on record (empty if not certified)
    function isManufacturerCertified(address manufacturer)
        external
        view
        returns (bool certified, string memory companyName)
    {
        certified = certifiedManufacturers[manufacturer];
        companyName = manufacturerNames[manufacturer];
    }

    // ─────────────────────────────────────────────
    //  Core Functions (Manufacturer Operations)
    // ─────────────────────────────────────────────

    /// @notice Register a new aircraft spare part on the blockchain
    /// @dev Caller MUST be a certified manufacturer (whitelist enforced)
    /// @param serialNumber Unique numeric identifier for the part
    /// @param partName     Human-readable description of the part
    function manufacturePart(uint256 serialNumber, string calldata partName)
        external
        onlyCertifiedManufacturer
    {
        require(!parts[serialNumber].exists, "AeroTrackPlus: Part already registered");
        require(bytes(partName).length > 0, "AeroTrackPlus: Part name cannot be empty");

        string memory mfrName = manufacturerNames[msg.sender];

        parts[serialNumber] = Part({
            serialNumber:     serialNumber,
            partName:         partName,
            manufacturer:     msg.sender,
            manufacturerName: mfrName,
            currentOwner:     msg.sender,
            status:           PartStatus.Active,
            exists:           true
        });

        emit PartManufactured(serialNumber, msg.sender, mfrName, partName);
    }

    /// @notice Transfer ownership of a spare part to a new address
    /// @param serialNumber The part's unique serial number
    /// @param newOwner     The Ethereum address of the new owner
    function transferPart(uint256 serialNumber, address newOwner)
        external
        partMustExist(serialNumber)
        onlyCurrentOwner(serialNumber)
    {
        require(newOwner != address(0), "AeroTrackPlus: New owner cannot be zero address");
        require(newOwner != msg.sender,  "AeroTrackPlus: Cannot transfer to yourself");

        address previousOwner = parts[serialNumber].currentOwner;
        parts[serialNumber].currentOwner = newOwner;

        emit PartTransferred(serialNumber, previousOwner, newOwner);
    }

    /// @notice Append a maintenance note to a spare part's history
    /// @dev Only the current owner OR the original manufacturer may log maintenance
    /// @param serialNumber The part's unique serial number
    /// @param note         Description of the maintenance performed
    function logMaintenance(uint256 serialNumber, string calldata note)
        external
        partMustExist(serialNumber)
    {
        require(
            msg.sender == parts[serialNumber].currentOwner ||
            msg.sender == parts[serialNumber].manufacturer,
            "AeroTrackPlus: Only owner or manufacturer can log maintenance"
        );
        require(bytes(note).length > 0, "AeroTrackPlus: Maintenance note cannot be empty");

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
    /// @return The Part struct with all part data
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

    /// @notice Check whether a part with the given serial number is registered
    /// @param serialNumber The part's unique serial number
    /// @return True if part exists, false otherwise
    function partExists(uint256 serialNumber) external view returns (bool) {
        return parts[serialNumber].exists;
    }
}
