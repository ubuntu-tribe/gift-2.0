// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// @notice Proof-of-Reserve (PoR) ledger for physical vault balances + minting allowances.
contract GIFTPoR is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    uint256 public GIFT_reserve;

    struct Vault {
        uint256 id;
        string name;
        uint256 amount;
    }

    struct ReserveAllowance {
        uint256 reserveId;
        uint256 allowance;
    }

    mapping(address => uint256[]) public minterReserves;
    mapping(address => mapping(uint256 => uint256)) public mintAllowances;

    Vault[] public vaults;

    mapping(uint256 => Vault) public vaultsById;
    mapping(address => bool) public auditors;
    mapping(address => bool) public admins;
    mapping(address => bool) public minters;

    uint256 public nextVaultId;

    struct PhysicalVaultReserve {
        uint256 id;
        string name;
        uint256 amount;
    }

    mapping(uint256 => PhysicalVaultReserve) public physicalVaultsById;

    uint256[50] private __gap;

    event UpdateReserve(uint256 GIFT_reserve, address indexed sender);
    event SetMintAllowance(address indexed minter, uint256 reserveId, uint256 allowance);
    event VaultAdded(uint256 indexed vaultId, string name);
    event AuditorAdded(address indexed auditor);
    event AuditorRemoved(address indexed auditor);
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);
    event VaultCreated(uint256 vaultId, string vaultName, uint256 amountAdded, uint256 totalAmount);
    event VaultUpdated(
        uint256 vaultId,
        string vaultName,
        uint256 amountAdded,
        uint256 totalAmount,
        string comment
    );
    event VaultUpdatedaftermint(uint256 vaultId, string vaultName, uint256 amountAdded, uint256 totalAmount);
    event MoveSupply(
        uint256 indexed fromVaultId,
        uint256 indexed toVaultId,
        uint256 amount,
        string comment,
        address indexed auditor
    );
    event PhysicalVaultSupplyAdded(
        uint256 indexed vaultId,
        string vaultName,
        uint256 amountAdded,
        uint256 totalAmount,
        string comment,
        address indexed auditor
    );
    event PhysicalVaultSupplyRemoved(
        uint256 indexed vaultId,
        string vaultName,
        uint256 amountRemoved,
        uint256 totalAmount,
        string comment,
        address indexed auditor
    );

    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();

        auditors[msg.sender] = true;
        admins[msg.sender] = true;
        minters[msg.sender] = true;

        nextVaultId = 1;
    }

    modifier onlyAuditor() {
        require(auditors[msg.sender], "Caller is not an auditor");
        _;
    }

    modifier onlyAdmin() {
        require(admins[msg.sender], "Caller is not an admin");
        _;
    }

    modifier onlyMinter() {
        require(minters[msg.sender], "Caller is not a minter");
        _;
    }

    function addAuditor(address _auditor) external onlyOwner {
        auditors[_auditor] = true;
        emit AuditorAdded(_auditor);
    }

    function removeAuditor(address _auditor) external onlyOwner {
        auditors[_auditor] = false;
        emit AuditorRemoved(_auditor);
    }

    function addAdmin(address _admin) external onlyOwner {
        admins[_admin] = true;
        emit AdminAdded(_admin);
    }

    function removeAdmin(address _admin) external onlyOwner {
        admins[_admin] = false;
        emit AdminRemoved(_admin);
    }

    function _authorizeUpgrade(address) internal override onlyAdmin {}

    function addVault(string memory _name) public onlyAdmin {
        uint256 vaultId = nextVaultId;
        Vault memory newVault = Vault({id: vaultId, name: _name, amount: 0});
        vaults.push(newVault);
        vaultsById[vaultId] = newVault;
        nextVaultId++;

        PhysicalVaultReserve memory newPhysicalVault = PhysicalVaultReserve({
            id: vaultId,
            name: _name,
            amount: 0
        });

        physicalVaultsById[vaultId] = newPhysicalVault;

        emit VaultCreated(vaultId, _name, 0, 0);
    }

    function getReserveState(uint256 _vaultId)
        public
        view
        returns (string memory reserveName, uint256 reserveId, uint256 balance)
    {
        require(_vaultId > 0 && _vaultId < nextVaultId, "Invalid vault ID");
        Vault memory vault = vaultsById[_vaultId];
        return (vault.name, vault.id, vault.amount);
    }

    function updateVault(uint256 _vaultId, uint256 _amountAdded, string memory comment) public onlyAuditor {
        require(_vaultId > 0 && _vaultId < nextVaultId, "Invalid vault ID");

        Vault storage vault = vaultsById[_vaultId];
        require(bytes(vault.name).length > 0, "Vault does not exist");

        vault.amount += _amountAdded;
        vaultsById[_vaultId].amount = vault.amount;
        physicalVaultsById[_vaultId].amount += _amountAdded;

        GIFT_reserve += _amountAdded;

        emit VaultUpdated(_vaultId, vault.name, _amountAdded, vault.amount, comment);
        emit UpdateReserve(GIFT_reserve, msg.sender);
    }

    function SupplyGold(uint256 vaultId, uint256 amount, string memory comment) public onlyAuditor {
        require(vaultId > 0 && vaultId < nextVaultId, "Invalid vault ID");

        PhysicalVaultReserve storage physicalVault = physicalVaultsById[vaultId];

        require(bytes(physicalVault.name).length > 0, "Physical vault does not exist");

        physicalVault.amount += amount;

        emit PhysicalVaultSupplyAdded(
            vaultId,
            physicalVault.name,
            amount,
            physicalVault.amount,
            comment,
            msg.sender
        );
    }

    function RedeemGold(uint256 vaultId, uint256 amount, string memory comment) public onlyAuditor {
        require(vaultId > 0 && vaultId < nextVaultId, "Invalid vault ID");

        PhysicalVaultReserve storage physicalVault = physicalVaultsById[vaultId];

        require(bytes(physicalVault.name).length > 0, "Physical vault does not exist");

        require(physicalVault.amount >= amount, "Insufficient physical reserve balance");

        physicalVault.amount -= amount;

        emit PhysicalVaultSupplyRemoved(
            vaultId,
            physicalVault.name,
            amount,
            physicalVault.amount,
            comment,
            msg.sender
        );
    }

    function moveSupply(
        uint256 fromVaultId,
        uint256 toVaultId,
        uint256 amount,
        string memory comment
    ) external onlyAuditor {
        require(fromVaultId > 0 && fromVaultId < nextVaultId, "Invalid from vault ID");
        require(toVaultId > 0 && toVaultId < nextVaultId, "Invalid to vault ID");

        Vault storage fromVault = vaultsById[fromVaultId];
        Vault storage toVault = vaultsById[toVaultId];

        require(fromVault.amount >= amount, "Insufficient balance in from vault");

        fromVault.amount -= amount;
        toVault.amount += amount;

        PhysicalVaultReserve storage physicalFromVault = physicalVaultsById[fromVaultId];
        PhysicalVaultReserve storage physicalToVault = physicalVaultsById[toVaultId];

        require(physicalFromVault.amount >= amount, "Insufficient physical balance in from vault");

        physicalFromVault.amount -= amount;
        physicalToVault.amount += amount;

        emit MoveSupply(fromVaultId, toVaultId, amount, comment, msg.sender);
    }

    function getTotalReserves() public view returns (uint256 totalReserves, uint256 totalAmount) {
        totalReserves = nextVaultId - 1;
        totalAmount = GIFT_reserve;
        return (totalReserves, totalAmount);
    }

    function retrieveReserve() public view returns (uint256) {
        return GIFT_reserve;
    }

    function addMinter(address minter) public onlyAdmin {
        minters[minter] = true;
        emit MinterAdded(minter);
    }

    function removeMinter(address minter) public onlyAdmin {
        minters[minter] = false;
        emit MinterRemoved(minter);
    }

    function setMintingAllowance(address minter, uint256 reserveId, uint256 allowance) external onlyAdmin {
        require(reserveId > 0 && reserveId < nextVaultId, "Invalid reserve ID");

        bool reserveExists = false;
        for (uint256 i = 0; i < minterReserves[minter].length; i++) {
            if (minterReserves[minter][i] == reserveId) {
                reserveExists = true;
                break;
            }
        }

        if (!reserveExists) {
            minterReserves[minter].push(reserveId);
        }

        mintAllowances[minter][reserveId] = allowance;

        emit SetMintAllowance(minter, reserveId, allowance);
    }

    function getMinterReservesAndAllowances(address minter) public view returns (ReserveAllowance[] memory) {
        uint256[] memory reserves = minterReserves[minter];
        ReserveAllowance[] memory reserveAllowances = new ReserveAllowance[](reserves.length);

        for (uint256 i = 0; i < reserves.length; i++) {
            uint256 reserveId = reserves[i];
            uint256 allowance = mintAllowances[minter][reserveId];
            reserveAllowances[i] = ReserveAllowance(reserveId, allowance);
        }

        return reserveAllowances;
    }

    function isMinter(address account) public view returns (bool) {
        return minters[account];
    }

    function updateReserveAfterMint(uint256 _vaultId, uint256 _amount) external onlyMinter {
        require(_vaultId > 0 && _vaultId < nextVaultId, "Invalid vault ID");
        Vault storage vault = vaultsById[_vaultId];
        require(vault.amount >= _amount, "Insufficient reserve balance");

        vault.amount -= _amount;

        emit VaultUpdatedaftermint(_vaultId, vault.name, _amount, vault.amount);
    }
}



