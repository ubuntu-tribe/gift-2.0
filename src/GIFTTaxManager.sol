// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";


contract GIFTTaxManager is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    using SafeMathUpgradeable for uint256;

    address public taxOfficer;
    address public beneficiary;

    uint256 public tierOneTaxPercentage;
    uint256 public tierTwoTaxPercentage;
    uint256 public tierThreeTaxPercentage;
    uint256 public tierFourTaxPercentage;
    uint256 public tierFiveTaxPercentage;

    uint256 public tierOneMax;
    uint256 public tierTwoMax;
    uint256 public tierThreeMax;
    uint256 public tierFourMax;

    mapping(address => bool) public isExcludedFromOutboundFees;
    mapping(address => bool) public _isLiquidityPool;

    event UpdateTaxPercentages(
        uint256 tierOneTaxPercentage,
        uint256 tierTwoTaxPercentage,
        uint256 tierThreeTaxPercentage,
        uint256 tierFourTaxPercentage,
        uint256 tierFiveTaxPercentage
    );

    event UpdateTaxTiers(
        uint256 tierOneMax,
        uint256 tierTwoMax,
        uint256 tierThreeMax,
        uint256 tierFourMax
    );

    event NewTaxOfficer(address indexed newTaxOfficer);
    event NewBeneficiary(address indexed newBeneficiary);
    event FeeExclusionSet(
        address indexed account,
        bool isExcludedOutbound,
        bool isExcludedInbound
    );
    event LiquidityPoolSet(address indexed account, bool isPool);

    modifier onlyTaxOfficer() {
        require(msg.sender == taxOfficer, "GIFTTaxManager: Caller is not the tax officer");
        _;
    }

    modifier onlyOwnerOrTaxOfficer() {
        require(
            msg.sender == owner() || msg.sender == taxOfficer,
            "GIFTTaxManager: Caller is not the owner or tax officer"
        );
        _;
    }

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        isExcludedFromOutboundFees[owner()] = true;

        tierOneTaxPercentage = 1618;
        tierTwoTaxPercentage = 1200;
        tierThreeTaxPercentage = 1000;
        tierFourTaxPercentage = 500;
        tierFiveTaxPercentage = 300;

        tierOneMax = 2000 * 10**18;
        tierTwoMax = 10000 * 10**18;
        tierThreeMax = 20000 * 10**18;
        tierFourMax = 200000 * 10**18;
    }

    function isExcludedFromInboundFees(address) public pure returns (bool) {
        return true; // Always return true, exempting all addresses from inbound taxes
    }

    function updateTaxPercentages(
        uint256 _tierOneTaxPercentage,
        uint256 _tierTwoTaxPercentage,
        uint256 _tierThreeTaxPercentage,
        uint256 _tierFourTaxPercentage,
        uint256 _tierFiveTaxPercentage
    ) external onlyOwnerOrTaxOfficer {
        tierOneTaxPercentage = _tierOneTaxPercentage;
        tierTwoTaxPercentage = _tierTwoTaxPercentage;
        tierThreeTaxPercentage = _tierThreeTaxPercentage;
        tierFourTaxPercentage = _tierFourTaxPercentage;
        tierFiveTaxPercentage = _tierFiveTaxPercentage;
        emit UpdateTaxPercentages(
            tierOneTaxPercentage,
            tierTwoTaxPercentage,
            tierThreeTaxPercentage,
            tierFourTaxPercentage,
            tierFiveTaxPercentage
        );
    }

    function updateTaxTiers(
        uint256 _tierOneMax,
        uint256 _tierTwoMax,
        uint256 _tierThreeMax,
        uint256 _tierFourMax
    ) external onlyOwnerOrTaxOfficer {
        tierOneMax = _tierOneMax;
        tierTwoMax = _tierTwoMax;
        tierThreeMax = _tierThreeMax;
        tierFourMax = _tierFourMax;
        emit UpdateTaxTiers(tierOneMax, tierTwoMax, tierThreeMax, tierFourMax);
    }

    function setTaxOfficer(address _newTaxOfficer) external onlyOwner {
        require(
            _newTaxOfficer != address(0),
            "GIFTTaxManager: Cannot set tax officer to address zero"
        );
        taxOfficer = _newTaxOfficer;
        emit NewTaxOfficer(taxOfficer);
    }

    function setBeneficiary(address _newBeneficiary) external onlyOwner {
        require(
            _newBeneficiary != address(0),
            "GIFTTaxManager: Cannot set beneficiary to address zero"
        );
        beneficiary = _newBeneficiary;
        emit NewBeneficiary(beneficiary);
    }

    function setFeeExclusion(
        address _address,
        bool _isExcludedOutbound,
        bool _isExcludedInbound
    ) external onlyOwnerOrTaxOfficer {
        isExcludedFromOutboundFees[_address] = _isExcludedOutbound;
        emit FeeExclusionSet(_address, _isExcludedOutbound, _isExcludedInbound);
    }

    function setLiquidityPool(address _liquidityPool, bool _isPool)
        external
        onlyOwner
    {
        _isLiquidityPool[_liquidityPool] = _isPool;
        emit LiquidityPoolSet(_liquidityPool, _isPool);
    }

    function getTaxTiers() external view returns (uint256, uint256, uint256, uint256) {
        return (tierOneMax, tierTwoMax, tierThreeMax, tierFourMax);
    }

    function getTaxPercentages() external view returns (uint256, uint256, uint256, uint256, uint256) {
        return (tierOneTaxPercentage, tierTwoTaxPercentage, tierThreeTaxPercentage, tierFourTaxPercentage, tierFiveTaxPercentage);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}
}