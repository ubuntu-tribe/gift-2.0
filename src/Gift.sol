// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";


contract GIFT is ERC20Upgradeable, OwnableUpgradeable, PausableUpgradeable {
    using SafeMathUpgradeable for uint256;

    address public supplyController;
    address public beneficiary;
    address public reserveConsumer;

    mapping(address => bool) public isExcludedFromOutboundFees;
    mapping(address => bool) public isExcludedFromInboundFees;
    mapping(address => bool) public isLiquidityPool;

    uint256[5] public taxTiers;
    uint256[5] public taxPercentages;

    uint256 public constant MAX_TAX_PERCENTAGE = 20_000; // 20%
    uint256 public lastReserveCheck;
    uint256 public reserveCheckPeriod;


    event TaxUpdated(uint256[5] tiers, uint256[5] percentages);
    event SupplyControllerSet(address indexed newSupplyController);
    event BeneficiarySet(address indexed newBeneficiary);
    event FeeExclusionSet(address indexed account, bool isExcludedOutbound, bool isExcludedInbound);
    event LiquidityPoolSet(address indexed account, bool isPool);
    event ReserveConsumerSet(address indexed newReserveConsumer);
    event ReserveCheckPeriodSet(uint256 newPeriod);




    modifier onlySupplyController() {
        require(msg.sender == supplyController, "GIFT: caller is not the supplyController");
        _;
    }

    modifier checkReserves() {
        if (block.timestamp >= lastReserveCheck.add(reserveCheckPeriod)) {
            _checkReserves();
        }
        _;
    }



    function initialize(
        string memory name,
        string memory symbol,
        address _supplyController,
        address _beneficiary,
        address _reserveConsumer,
        address _initialHolder
    ) external initializer {
        __ERC20_init(name, symbol);
        __Ownable_init(msg.sender);
        __Pausable_init();
        
        supplyController = _supplyController;
        beneficiary = _beneficiary;
        reserveConsumer = _reserveConsumer;


        
        // Initialize tax tiers and percentages
        taxTiers = [1000 ether, 5000 ether, 10000 ether, 50000 ether, type(uint256).max];
        taxPercentages = [1000, 800, 600, 400, 200]; // 1%, 0.8%, 0.6%, 0.4%, 0.2%
        
        reserveCheckPeriod = 1 days;

        super._mint(_initialHolder, 1000 * 10**18);
    }



        /**
     * @dev ID of the executing chain
     * @return uint value
     */
    function getChainID() public view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }


    function setTaxParameters(uint256[5] memory _tiers, uint256[5] memory _percentages) external onlyOwner {
        require(_tiers[4] == type(uint256).max, "GIFT: Last tier must be max");
        for (uint i = 0; i < 5; i++) {
            require(_percentages[i] <= MAX_TAX_PERCENTAGE, "GIFT: Tax percentage too high");
            if (i > 0) require(_tiers[i] > _tiers[i-1], "GIFT: Tiers must be in ascending order");
        }
        taxTiers = _tiers;
        taxPercentages = _percentages;
        emit TaxUpdated(_tiers, _percentages);
    }



    function setSupplyController(address _newSupplyController) external onlyOwner {
        supplyController = _newSupplyController;
        emit SupplyControllerSet(_newSupplyController);
    }

    function setBeneficiary(address _newBeneficiary) external onlyOwner {
        beneficiary = _newBeneficiary;
        emit BeneficiarySet(_newBeneficiary);
    }

    function setFeeExclusion(address _address, bool _isExcludedOutbound, bool _isExcludedInbound) external onlyOwner {
        isExcludedFromOutboundFees[_address] = _isExcludedOutbound;
        isExcludedFromInboundFees[_address] = _isExcludedInbound;
        emit FeeExclusionSet(_address, _isExcludedOutbound, _isExcludedInbound);
    }


    function setLiquidityPool(address _address, bool _isPool) external onlyOwner {
        isLiquidityPool[_address] = _isPool;
        emit LiquidityPoolSet(_address, _isPool);
    }

    function setReserveConsumer(address _newReserveConsumer) external onlyOwner {
        reserveConsumer = _newReserveConsumer;
        emit ReserveConsumerSet(_newReserveConsumer);
    }

    function setReserveCheckPeriod(uint256 _newPeriod) external onlyOwner {
        reserveCheckPeriod = _newPeriod;
        emit ReserveCheckPeriodSet(_newPeriod);
    }


    function increaseSupply(address _to, uint256 _amount) external onlySupplyController checkReserves {
        _mint(_to, _amount);
    }

    /**
    * allows supply controller to burn tokens from an address when they want to redeem
    * their tokens for gold
    */
    function redeemGold(address _userAddress, uint256 _value) public onlySupplyController returns (bool success) {
        _burn(_userAddress, _value);
        return true;
    }

    function burnFrom(address _account, uint256 _amount) external {
        uint256 currentAllowance = allowance(_account, msg.sender);
        require(currentAllowance >= _amount, "GIFT: burn amount exceeds allowance");
        unchecked {
            _approve(_account, msg.sender, currentAllowance - _amount);
        }
        _burn(_account, _amount);
    }


    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function transfer(address recipient, uint256 amount) public virtual override whenNotPaused checkReserves returns (bool) {
        return _transferGIFT(_msgSender(), recipient, amount);
    }


    function transferFrom(address sender, address recipient, uint256 amount) public virtual override whenNotPaused checkReserves returns (bool) {
        uint256 currentAllowance = allowance(sender, _msgSender());
        require(currentAllowance >= amount, "GIFT: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }
        return _transferGIFT(sender, recipient, amount);
    }

    function _transferGIFT(address sender, address recipient, uint256 amount) internal virtual returns (bool) {
        if (isExcludedFromOutboundFees[sender] || isExcludedFromInboundFees[recipient] || isLiquidityPool[sender]) {
            _transfer(sender, recipient, amount);
        } else {
            uint256 tax = _computeTax(amount);
            _transfer(sender, beneficiary, tax);
            _transfer(sender, recipient, amount.sub(tax));
        }
        return true;
    }


    function _computeTax(uint256 _amount) internal view returns (uint256) {
        for (uint i = 0; i < 5; i++) {
            if (_amount <= taxTiers[i]) {
                return _amount.mul(taxPercentages[i]).div(100000);
            }
        }
        revert("GIFT: Invalid amount");
    }

    function _checkReserves() internal {
        if (reserveConsumer != address(0)) {
            (bool success, bytes memory data) = reserveConsumer.staticcall(abi.encodeWithSignature("getReserves()"));
            require(success, "GIFT: Failed to check reserves");
            uint256 reserves = abi.decode(data, (uint256));
            require(totalSupply() <= reserves, "GIFT: Insufficient reserves");
        }
        lastReserveCheck = block.timestamp;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {
        require(!paused(), "GIFT: token transfer while paused");
        // Silence unused parameter warnings
        from;
        to;
        amount;

    }

    function transferAdminControl(address newAdmin) external onlyOwner {
        require(newAdmin != address(0), "GIFT: New admin cannot be the zero address");
        transferOwnership(newAdmin);
    }

    function renounceAdminControl() external onlyOwner {
        renounceOwnership();
    }
}
