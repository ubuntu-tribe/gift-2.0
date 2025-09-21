// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./GIFTPoR.sol";
import "./GIFT.sol";
import "./GIFTBatchRegistry.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract MintingUpgradeable is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    GIFTPoR public giftpor;
    GIFT    public gift;
    GIFTBatchRegistry public registry;

    bool public registryEnforced;                      // when true, all mints require proofs
    mapping(uint256 => bool) public allowedBatches;    // optional allowlist

    event RegistrySet(address indexed registry);
    event RegistryEnforced(bool on);
    event BatchAllowed(uint256 indexed batchId, bool on);
    event TokensMinted(address indexed to, uint256 amount, uint256 reserveId, uint256 batchId, bytes32 leafHash);

    // ---- Init / UUPS ----

    function initialize(address giftPoR_, address giftToken_, address registry_) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        giftpor = GIFTPoR(giftPoR_);
        gift    = GIFT(giftToken_);
        if (registry_ != address(0)) {
            registry = GIFTBatchRegistry(registry_);
        }
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    // ---- Admin wiring ----

    function setRegistry(address registry_) external onlyOwner {
        registry = GIFTBatchRegistry(registry_);
        emit RegistrySet(registry_);
    }

    function enforceRegistry(bool on) external onlyOwner {
        registryEnforced = on;
        emit RegistryEnforced(on);
    }

    function allowBatch(uint256 batchId, bool on) external onlyOwner {
        allowedBatches[batchId] = on;
        emit BatchAllowed(batchId, on);
    }

    // ---- Core mint with proof ----

    function mintWithProof(
        address to,
        uint256 amount,
        GIFTBatchRegistry.LeafInput calldata leaf,
        bytes32[] calldata proof
    ) external {
        require(giftpor.isMinter(msg.sender), "Minting: caller not PoR minter");
        require(amount > 0, "Minting: amount=0");
        require(registryEnforced, "Minting: registry not enforced");
        require(allowedBatches[leaf.batchId], "Minting: batch not allowed");

        // 1) Reserve & allowance checks in PoR
        GIFTPoR.ReserveAllowance[] memory ras = giftpor.getMinterReservesAndAllowances(msg.sender);
        uint256 allowance = _findAllowance(ras, leaf.reserveId);
        require(allowance >= amount, "Minting: exceeds allowance");

        (, , uint256 reserveBalance) = giftpor.getReserveState(leaf.reserveId);
        require(reserveBalance >= amount, "Minting: insufficient reserve");

        // 2) Registry consume (locks provenance)
        (bytes32 leafHash, bool ok) = registry.verifyLeaf(leaf, proof);
        require(ok, "Minting: bad proof");
        registry.consume(leaf, proof, amount, to);

        // 3) Mint ERC20
        gift.increaseSupply(to, amount);

        // 4) Update PoR accounting
        giftpor.setMintingAllowance(msg.sender, leaf.reserveId, allowance - amount);
        giftpor.updateReserveAfterMint(leaf.reserveId, amount);

        emit TokensMinted(to, amount, leaf.reserveId, leaf.batchId, leafHash);
    }

    // ---- Temporary migration path (optional) ----

    function mint(address to, uint256 amount, uint256 reserveId) external {
        require(!registryEnforced, "Minting: proof required");

        require(giftpor.isMinter(msg.sender), "Minting: caller not PoR minter");
        require(amount > 0, "Minting: amount=0");

        GIFTPoR.ReserveAllowance[] memory ras = giftpor.getMinterReservesAndAllowances(msg.sender);
        uint256 allowance = _findAllowance(ras, reserveId);
        require(allowance >= amount, "Minting: exceeds allowance");

        (, , uint256 reserveBalance) = giftpor.getReserveState(reserveId);
        require(reserveBalance >= amount, "Minting: insufficient reserve");

        gift.increaseSupply(to, amount);
        giftpor.setMintingAllowance(msg.sender, reserveId, allowance - amount);
        giftpor.updateReserveAfterMint(reserveId, amount);

        emit TokensMinted(to, amount, reserveId, 0, bytes32(0));
    }

    // ---- Admin passthroughs you used before ----

    function burnFrom(address account, uint256 amount) external {
        require(msg.sender == giftpor.owner(), "Minting: only PoR owner can burn");
        gift.redeemGold(account, amount);
    }

    function updatePoR(address newPoR) external {
        require(msg.sender == giftpor.owner(), "Minting: only PoR owner");
        giftpor = GIFTPoR(newPoR);
    }

    function getAdmin() external view returns (address) {
        return giftpor.owner();
    }

    function changeAdmin(address newAdmin) external {
        require(msg.sender == giftpor.owner(), "Minting: only PoR owner");
        require(newAdmin != address(0), "Minting: zero");
        giftpor.transferOwnership(newAdmin);
    }

    // ---- Helpers ----

    function _findAllowance(GIFTPoR.ReserveAllowance[] memory ras, uint256 reserveId) internal pure returns (uint256) {
        for (uint256 i = 0; i < ras.length; i++) {
            if (ras[i].reserveId == reserveId) return ras[i].allowance;
        }
        revert("Minting: reserve not assigned");
    }
}
