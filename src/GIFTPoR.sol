// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Importing necessary components from OpenZeppelin's upgradeable contracts library.
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// Declaring the contract, inheriting from OpenZeppelin's Initializable, AccessControlUpgradeable, and UUPSUpgradeable to enable upgradeability and access control.
contract GIFTPoR is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    // Variable to keep track of reserves.
    uint256 public GIFT_reserve;

    // Structure to represent a vault with a name and an amount.
    struct Vault {
        uint256 id;
        string name;
        uint256 amount;
    }

    struct ReserveAllowance {
        uint256 reserveId;
        uint256 allowance;
    }

    // Mapping to store PhysicalVaultReserves by vault ID
    mapping(address => uint256[]) public minterReserves;
    mapping(address => mapping(uint256 => uint256)) public mintAllowances;

    // Array to store multiple vaults and Vaults by ID.
    Vault[] public vaults;

    mapping(uint256 => Vault) public vaultsById;
    mapping(address => bool) public auditors;
    mapping(address => bool) public admins;
    mapping(address => bool) public minters;

    // Variable to keep track of the next vault ID.
    // A new variable nextVaultId is introduced to keep track of the next available vault ID.
    // It is initialized to 1 in the initialize function.
    uint256 public nextVaultId;

    // **Add new struct and mapping after existing variables**
    struct PhysicalVaultReserve {
        uint256 id;
        string name;
        uint256 amount;
    }

    mapping(uint256 => PhysicalVaultReserve) public physicalVaultsById;

    uint256[50] private __gap;


    // Events for logging actions within the contract.
    event UpdateReserve(uint256 GIFT_reserve, address indexed sender);
    event SetMintAllowance(
        address indexed minter,
        uint256 reserveId,
        uint256 allowance
    );
    event VaultAdded(uint256 indexed vaultId, string name);
    event AuditorAdded(address indexed auditor);
    event AuditorRemoved(address indexed auditor);
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);
    event VaultCreated(
        uint256 vaultId,
        string vaultName,
        uint256 amountAdded,
        uint256 totalAmount
    );
    event VaultUpdated(
        uint256 vaultId,
        string vaultName,
        uint256 amountAdded,
        uint256 totalAmount,
        string comment
    );
    event VaultUpdatedaftermint(
        uint256 vaultId,
        string vaultName,
        uint256 amountAdded,
        uint256 totalAmount
    );
    // Event for moving supply between vaults
    event MoveSupply(
        uint256 indexed fromVaultId,
        uint256 indexed toVaultId,
        uint256 amount,
        string comment,
        address indexed auditor
    );
    // Event emitted when supply is added to PhysicalVaultReserve
    event PhysicalVaultSupplyAdded(
        uint256 indexed vaultId,
        string vaultName,
        uint256 amountAdded,
        uint256 totalAmount,
        string comment,
        address indexed auditor
    );

    // Event emitted when supply is removed from PhysicalVaultReserve
    event PhysicalVaultSupplyRemoved(
        uint256 indexed vaultId,
        string vaultName,
        uint256 amountRemoved,
        uint256 totalAmount,
        string comment,
        address indexed auditor
    );

    // Initialization function to replace the constructor
    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        // Grants roles to the message sender and a specified upgrader.
        auditors[msg.sender] = true;
        admins[msg.sender] = true;
        minters[msg.sender] = true;

        // Initialize the next vault ID to 1.
        nextVaultId = 1;
    }

    // Modifier to restrict access to functions that only auditors can call.
    // Ensures the caller is an auditor by checking the auditors mapping.
    modifier onlyAuditor() {
        require(auditors[msg.sender], "Caller is not an auditor");
        _;
    }
    // Modifier to restrict access to functions that only admins can call.
    // Ensures the caller is an admin by checking the admins mapping.
    modifier onlyAdmin() {
        require(admins[msg.sender], "Caller is not an admin");
        _;
    }
    // Modifier to restrict access to functions that only minters can call.
    // Ensures the caller is a minter by checking the minters mapping.
    modifier onlyMinter() {
        require(minters[msg.sender], "Caller is not a minter");
        _;
    }

    // Function to add a new auditor.
    // Only the contract owner can call this function.
    // Adds the provided address to the auditors list and emits the AuditorAdded event.
    function addAuditor(address _auditor) external onlyOwner {
        auditors[_auditor] = true;
        emit AuditorAdded(_auditor);
    }

    // Function to remove an auditor.
    // Only the contract owner can call this function.
    // Removes the provided address from the auditors list and emits the AuditorRemoved event.
    function removeAuditor(address _auditor) external onlyOwner {
        auditors[_auditor] = false;
        emit AuditorRemoved(_auditor);
    }

    // Function to add a new admin.
    // Only the contract owner can call this function.
    // Adds the provided address to the admins list and emits the AdminAdded event.
    function addAdmin(address _admin) external onlyOwner {
        admins[_admin] = true;
        emit AdminAdded(_admin);
    }

    // Function to remove an admin.
    // Only the contract owner can call this function.
    // Removes the provided address from the admins list and emits the AdminRemoved event.
    function removeAdmin(address _admin) external onlyOwner {
        admins[_admin] = false;
        emit AdminRemoved(_admin);
    }

    // Internal function to authorize upgrades to a new implementation contract.
    // Only admins can authorize upgrades.
    // This function is required for upgradeability using OpenZeppelin's UUPS pattern.
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyAdmin
    {}

    // Function to add a new vault.
    // Only admins can add new vaults.
    // The function creates a vault with the given name and initializes its amount to 0.
    // The vault is added to the vaults array, and the next vault ID is incremented.
    // Emits a VaultCreated event.
    function addVault(string memory _name) public onlyAdmin {
        uint256 vaultId = nextVaultId;
        Vault memory newVault = Vault({id: vaultId, name: _name, amount: 0});
        vaults.push(newVault);
        vaultsById[vaultId] = newVault;
        nextVaultId++;

        // Initialize the PhysicalVaultReserve for this vault
        PhysicalVaultReserve memory newPhysicalVault = PhysicalVaultReserve({
            id: vaultId,
            name: _name,
            amount: 0
        });

        physicalVaultsById[vaultId] = newPhysicalVault;

        emit VaultCreated(vaultId, _name, 0, 0);
    }

    // Function to retrieve the state of a specific vault by ID.
    // Returns the vault's name, ID, and current balance.
    // Requires a valid vault ID, otherwise it reverts with an error.
    function getReserveState(uint256 _vaultId)
        public
        view
        returns (
            string memory reserveName,
            uint256 reserveId,
            uint256 balance
        )
    {
        require(_vaultId > 0 && _vaultId < nextVaultId, "Invalid vault ID");
        Vault memory vault = vaultsById[_vaultId];
        return (vault.name, vault.id, vault.amount);
    }

    // @dev Updates the amount in a vault.
    //A comment is required to describe the purpose of the update.

    // @param _vaultId The ID of the vault to be updated.
    //@param _amountAdded The amount to be added to the vault.
    //@param comment A string comment explaining the reason for the update.

    function updateVault(
        uint256 _vaultId,
        uint256 _amountAdded,
        string memory comment
    ) public onlyAuditor {
        require(_vaultId > 0 && _vaultId < nextVaultId, "Invalid vault ID");

        Vault storage vault = vaultsById[_vaultId];
        require(bytes(vault.name).length > 0, "Vault does not exist");

        vault.amount += _amountAdded;
        vaultsById[_vaultId].amount = vault.amount;
        // Update the physical vault reserve amount
        physicalVaultsById[_vaultId].amount += _amountAdded;

        GIFT_reserve += _amountAdded;

        emit VaultUpdated(
            _vaultId,
            vault.name,
            _amountAdded,
            vault.amount,
            comment
        );
        emit UpdateReserve(GIFT_reserve, msg.sender);
    }

    /**
     * @dev Function to add supply to the PhysicalVaultReserve of a vault.
     * This function increases the physical amount stored in the vault.
     * Requires a comment explaining the reason for the addition.
     *
     * @param vaultId The ID of the vault to which the amount will be added.
     * @param amount The amount to be added to the physical vault reserve.
     * @param comment A string comment explaining the reason for the addition.
     */
    function SupplyGold(
        uint256 vaultId,
        uint256 amount,
        string memory comment
    ) public onlyAuditor {
        // Validate that the vault exists
        require(vaultId > 0 && vaultId < nextVaultId, "Invalid vault ID");

        // Fetch the physical vault
        PhysicalVaultReserve storage physicalVault = physicalVaultsById[
            vaultId
        ];

        // Ensure the vault exists
        require(
            bytes(physicalVault.name).length > 0,
            "Physical vault does not exist"
        );

        // Add the amount to the physical vault reserve
        physicalVault.amount += amount;

        // Emit an event logging the addition
        emit PhysicalVaultSupplyAdded(
            vaultId,
            physicalVault.name,
            amount,
            physicalVault.amount,
            comment,
            msg.sender
        );
    }

    /**
     * @dev Function to remove supply from the PhysicalVaultReserve of a vault.
     * This function decreases the physical amount stored in the vault.
     * Requires a comment explaining the reason for the removal.
     *
     * @param vaultId The ID of the vault from which the amount will be removed.
     * @param amount The amount to be removed from the physical vault reserve.
     * @param comment A string comment explaining the reason for the removal.
     */
    function RedeemGold(
        uint256 vaultId,
        uint256 amount,
        string memory comment
    ) public onlyAuditor {
        // Validate that the vault exists
        require(vaultId > 0 && vaultId < nextVaultId, "Invalid vault ID");

        // Fetch the physical vault
        PhysicalVaultReserve storage physicalVault = physicalVaultsById[
            vaultId
        ];

        // Ensure the vault exists
        require(
            bytes(physicalVault.name).length > 0,
            "Physical vault does not exist"
        );

        // Ensure the vault has enough amount to redeem
        require(
            physicalVault.amount >= amount,
            "Insufficient physical reserve balance"
        );

        // Subtract the amount from the physical vault reserve
        physicalVault.amount -= amount;

        // Emit an event logging the removal
        emit PhysicalVaultSupplyRemoved(
            vaultId,
            physicalVault.name,
            amount,
            physicalVault.amount,
            comment,
            msg.sender
        );
    }

    /**
     * @dev Function to move an amount from one vault to another.
     * This function does not change the total reserve, only shifts funds between vaults.
     * It requires a comment explaining the reason for the transfer.
     *
     * @param fromVaultId The ID of the vault from which the amount will be moved.
     * @param toVaultId The ID of the vault to which the amount will be moved.
     * @param amount The amount to be transferred between the vaults.
     * @param comment A string comment explaining the reason for the transfer.
     */
    function moveSupply(
        uint256 fromVaultId,
        uint256 toVaultId,
        uint256 amount,
        string memory comment
    ) external onlyAuditor {
        // Validate that both vaults exist
        require(
            fromVaultId > 0 && fromVaultId < nextVaultId,
            "Invalid from vault ID"
        );
        require(
            toVaultId > 0 && toVaultId < nextVaultId,
            "Invalid to vault ID"
        );

        // Fetch both vaults
        Vault storage fromVault = vaultsById[fromVaultId];
        Vault storage toVault = vaultsById[toVaultId];

        // Ensure the from vault has enough balance
        require(
            fromVault.amount >= amount,
            "Insufficient balance in from vault"
        );

        // Move the amount from vault 1 to vault 2
        fromVault.amount -= amount;
        toVault.amount += amount;

        PhysicalVaultReserve storage physicalFromVault = physicalVaultsById[
            fromVaultId
        ];
        PhysicalVaultReserve storage physicalToVault = physicalVaultsById[
            toVaultId
        ];

        // Ensure the from physical vault has enough balance
        require(
            physicalFromVault.amount >= amount,
            "Insufficient physical balance in from vault"
        );

        // Move the amount in the physical vault reserves
        physicalFromVault.amount -= amount;
        physicalToVault.amount += amount;

        // Emit an event logging the move, including the comment
        emit MoveSupply(fromVaultId, toVaultId, amount, comment, msg.sender);
    }

    // Function to retrieve the total number of vaults and the total reserve amount.
    // Returns the total number of vaults and the total reserve amount in the system.
    function getTotalReserves()
        public
        view
        returns (uint256 totalReserves, uint256 totalAmount)
    {
        totalReserves = nextVaultId - 1; // Assuming vaultIds start from 1
        totalAmount = GIFT_reserve;
        return (totalReserves, totalAmount);
    }

    // Function to retrieve the total reserve amount in the system.
    // Returns the total reserve without referencing specific vaults.
    function retrieveReserve() public view returns (uint256) {
        return GIFT_reserve;
    }

    // Function to add a new minter.
    // Only admins can add minters.
    // The function adds the provided address to the minters list and emits the MinterAdded event.

    function addMinter(address minter) public onlyAdmin {
        minters[minter] = true;
        emit MinterAdded(minter);
    }

    // Function to remove a minter.
    // Only admins can remove minters.
    // The function removes the provided address from the minters list and emits the MinterRemoved event.

    function removeMinter(address minter) public onlyAdmin {
        minters[minter] = false;
        emit MinterRemoved(minter);
    }

    // Function to set the minting allowance for a specific minter and reserve.
    // Only admins can set minting allowances.
    // If the reserve is not already assigned to the minter, it is added to their list.
    // The allowance is set in the mintAllowances mapping and the SetMintAllowance event is emitted.

    function setMintingAllowance(
        address minter,
        uint256 reserveId,
        uint256 allowance
    ) external onlyAdmin {
        require(reserveId > 0 && reserveId < nextVaultId, "Invalid reserve ID");

        // Check if the reserve is already assigned to the minter
        bool reserveExists = false;
        for (uint256 i = 0; i < minterReserves[minter].length; i++) {
            if (minterReserves[minter][i] == reserveId) {
                reserveExists = true;
                break;
            }
        }

        // If the reserve doesn't exist for this minter, add it
        if (!reserveExists) {
            minterReserves[minter].push(reserveId);
        }

        // Set the allowance for this minter and reserve
        mintAllowances[minter][reserveId] = allowance;

        emit SetMintAllowance(minter, reserveId, allowance);
    }

    // Function to get the list of reserves and allowances for a specific minter.
    // Returns an array of ReserveAllowance structures containing reserve IDs and their respective allowances.

    function getMinterReservesAndAllowances(address minter)
        public
        view
        returns (ReserveAllowance[] memory)
    {
        uint256[] memory reserves = minterReserves[minter];
        ReserveAllowance[] memory reserveAllowances = new ReserveAllowance[](
            reserves.length
        );

        for (uint256 i = 0; i < reserves.length; i++) {
            uint256 reserveId = reserves[i];
            uint256 allowance = mintAllowances[minter][reserveId];
            reserveAllowances[i] = ReserveAllowance(reserveId, allowance);
        }

        return reserveAllowances;
    }

    // Function to check if an account is a registered minter.
    // Returns true if the account is a minter, false otherwise.
    function isMinter(address account) public view returns (bool) {
        return minters[account];
    }

    // Function to update the reserve balance of a vault after minting.
    // Only minters can update the reserve after minting.
    // The function decreases the vault's balance by the minted amount and emits the VaultUpdated event.

    function updateReserveAfterMint(uint256 _vaultId, uint256 _amount)
        external
        onlyMinter
    {
        require(_vaultId > 0 && _vaultId < nextVaultId, "Invalid vault ID");
        Vault storage vault = vaultsById[_vaultId];
        require(vault.amount >= _amount, "Insufficient reserve balance");

        vault.amount -= _amount;

        emit VaultUpdatedaftermint(_vaultId, vault.name, _amount, vault.amount);
    }
}