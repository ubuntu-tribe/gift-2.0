// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./IReserveConsumerV3.sol";

contract GIFT is
    Initializable,
    ERC20Upgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    IReserveConsumerV3
{
    using SafeMathUpgradeable for uint256;

address public supplyController;
address public beneficiary;
address public accessControl;
address public reserveConsumer; // Keep this for compatibility, even if unused

mapping(address => bool) public _isExcludedFromFees; // Keep old naming
mapping(address => bool) public _isLiquidityPool; // Keep old naming

uint256 public tierOneTaxPercentage;
uint256 public tierTwoTaxPercentage;
uint256 public tierThreeTaxPercentage;
uint256 public tierFourTaxPercentage;
uint256 public tierFiveTaxPercentage;

uint256 public tierOneMax;
uint256 public tierTwoMax;
uint256 public tierThreeMax;
uint256 public tierFourMax;

// New state variables
AggregatorV3Interface private reserveFeed;
mapping(address => bool) public isExcludedFromOutboundFees;
mapping(address => bool) public isExcludedFromInboundFees;
mapping(address => bool) public isManager;
mapping(address => uint256) public nonces;

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

    event NewSupplyController(address indexed newSupplyController);
    event NewBeneficiary(address indexed newBeneficiary);
    event DelegateTransfer(
        address sender,
        address delegator,
        address receiver,
        uint256 amount
    );
    event FeeExclusionSet(
        address indexed account,
        bool isExcludedOutbound,
        bool isExcludedInbound
    );
    event LiquidityPoolSet(address indexed account, bool isPool);
    event ManagerUpdated(address indexed manager, bool isManager);

    modifier onlySupplyController() {
        require(
            msg.sender == supplyController,
            "GIFT: Caller is not the supply controller"
        );
        _;
    }

    modifier onlyManager() {
        require(isManager[msg.sender], "GIFT: Caller is not a manager");
        _;
    }

    function initialize(
        address _accessControl,
        address _aggregatorInterface,
        address _initialHolder
    ) external reinitializer(2) {
        __ERC20_init("GIFT", "GIFT");
        __Pausable_init();
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        accessControl = _accessControl;
        reserveFeed = AggregatorV3Interface(_aggregatorInterface);

        isExcludedFromOutboundFees[owner()] = true;
        isExcludedFromInboundFees[owner()] = true;

        tierOneTaxPercentage = 1618;
        tierTwoTaxPercentage = 1200;
        tierThreeTaxPercentage = 1000;
        tierFourTaxPercentage = 500;
        tierFiveTaxPercentage = 300;

        tierOneMax = 2000 * 10**18;
        tierTwoMax = 10000 * 10**18;
        tierThreeMax = 20000 * 10**18;
        tierFourMax = 200000 * 10**18;

        _mint(_initialHolder, 1000 * 10**18);
    }

    function computeTax(uint256 _transferAmount) public view returns (uint256) {
        uint256 taxPercentage;

        if (_transferAmount <= tierOneMax) {
            taxPercentage = tierOneTaxPercentage;
        } else if (_transferAmount <= tierTwoMax) {
            taxPercentage = tierTwoTaxPercentage;
        } else if (_transferAmount <= tierThreeMax) {
            taxPercentage = tierThreeTaxPercentage;
        } else if (_transferAmount <= tierFourMax) {
            taxPercentage = tierFourTaxPercentage;
        } else {
            taxPercentage = tierFiveTaxPercentage;
        }

        return _transferAmount.mul(taxPercentage).div(100000);
    }

    function getChainID() public view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    function delegateTransferProof(
        bytes32 token,
        address delegator,
        address spender,
        uint256 amount,
        uint256 networkFee
    ) public view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    getChainID(),
                    token,
                    amount,
                    delegator,
                    spender,
                    networkFee
                )
            );
    }

    function updateTaxPercentages(
        uint256 _tierOneTaxPercentage,
        uint256 _tierTwoTaxPercentage,
        uint256 _tierThreeTaxPercentage,
        uint256 _tierFourTaxPercentage,
        uint256 _tierFiveTaxPercentage
    ) external onlyOwner {
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
    ) external onlyOwner {
        tierOneMax = _tierOneMax;
        tierTwoMax = _tierTwoMax;
        tierThreeMax = _tierThreeMax;
        tierFourMax = _tierFourMax;
        emit UpdateTaxTiers(tierOneMax, tierTwoMax, tierThreeMax, tierFourMax);
    }

    function setSupplyController(address _newSupplyController)
        external
        onlyOwner
    {
        require(
            _newSupplyController != address(0),
            "GIFT: Cannot set supply controller to address zero"
        );
        supplyController = _newSupplyController;
        emit NewSupplyController(supplyController);
    }

    function setBeneficiary(address _newBeneficiary) external onlyOwner {
        require(
            _newBeneficiary != address(0),
            "GIFT: Cannot set beneficiary to address zero"
        );
        beneficiary = _newBeneficiary;
        emit NewBeneficiary(beneficiary);
    }

    function setFeeExclusion(
        address _address,
        bool _isExcludedOutbound,
        bool _isExcludedInbound
    ) external onlyOwner {
        isExcludedFromOutboundFees[_address] = _isExcludedOutbound;
        isExcludedFromInboundFees[_address] = _isExcludedInbound;
        emit FeeExclusionSet(_address, _isExcludedOutbound, _isExcludedInbound);
    }

    function setLiquidityPool(address _liquidityPool, bool _isPool)
        external
        onlyOwner
    {
        _isLiquidityPool[_liquidityPool] = _isPool;
        emit LiquidityPoolSet(_liquidityPool, _isPool);
    }

       /**
    * old version left for backwards compatibility
    */
    function increaseSupply(uint256 _value) public onlySupplyController returns (bool success) {
        _mint(supplyController, _value);
        return true;
    }

    function increaseSupplynew(address _userAddress, uint256 _value)
        external
        onlySupplyController
        returns (bool)
    {
        _mint(_userAddress, _value);
        return true;
    }

    function redeemGold(address _userAddress, uint256 _value)
        external
        onlySupplyController
        returns (bool)
    {
        _burn(_userAddress, _value);
        return true;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setManager(address _manager, bool _isManager) external onlyOwner {
        isManager[_manager] = _isManager;
        emit ManagerUpdated(_manager, _isManager);
    }

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        whenNotPaused
        returns (bool)
    {
        return _transferGIFTnew(_msgSender(), recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override whenNotPaused returns (bool) {
        bool success = _transferGIFTnew(sender, recipient, amount);
        uint256 currentAllowance = allowance(sender, _msgSender());
        require(
            currentAllowance >= amount,
            "GIFT: Transfer amount exceeds allowance"
        );
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }
        return success;
    }

    function recoverSigner(bytes32 message, bytes memory signature)
        internal
        pure
        returns (address)
    {
        require(signature.length == 65, "GIFT: Invalid signature length");
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
        if (v < 27) v += 27;
        require(v == 27 || v == 28, "GIFT: Invalid signature 'v' value");
        return
            ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19Ethereum Signed Message:\n32",
                        message
                    )
                ),
                v,
                r,
                s
            );
    }

    function delegateTransfer(
        bytes memory signature,
        address delegator,
        address recipient,
        uint256 amount,
        uint256 networkFee
    ) external whenNotPaused onlyManager returns (bool) {
        bytes32 message = keccak256(
            abi.encodePacked(
                this,
                delegator,
                recipient,
                amount,
                networkFee,
                nonces[delegator]++
            )
        );
        address signer = recoverSigner(message, signature);
        require(signer == delegator, "GIFT: Invalid signature");

        _transfer(delegator, msg.sender, networkFee);
        bool success = _transferGIFTnew(delegator, recipient, amount);
        emit DelegateTransfer(msg.sender, delegator, recipient, amount);
        return success;
    }

    function _transferGIFTnew(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual returns (bool) {
        uint256 tax = 0;
        // Check for outbound fees (sender perspective)
        if (
            !isExcludedFromOutboundFees[sender] && !_isLiquidityPool[recipient]
        ) {
            uint256 outboundTax = computeTax(amount);
            tax += outboundTax;
            _transfer(sender, beneficiary, outboundTax);
        }

        // Check for inbound fees (recipient perspective)
        if (!isExcludedFromInboundFees[recipient] && !_isLiquidityPool[sender]) {
            uint256 inboundTax = computeTax(amount - tax); // Calculate tax on remaining amount
            tax += inboundTax;
            _transfer(sender, beneficiary, inboundTax);
        }

        // Transfer the remaining amount after taxes
        _transfer(sender, recipient, amount - tax);
        return true;
    }

    function mintgiftwithreservechecks(address account, uint256 amount)
        internal
    {
        require(account != address(0), "GIFT: Mint to the zero address");

        (
            uint80 roundId,
            int256 answer,
            ,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = reserveFeed.latestRoundData();
        require(
            answer > 0 && updatedAt != 0 && answeredInRound >= roundId,
            "GIFT: Invalid reserve data"
        );

        uint256 reserves = uint256(answer);
        uint256 totalSupplyAfterMint = totalSupply() + amount;

        require(
            totalSupplyAfterMint <= reserves,
            "GIFT: Total supply would exceed reserves"
        );

        _mint(account, amount);
    }

    // IReserveConsumerV3 implementation
    function getLatestReserve() external view override returns (int256) {
        (, int256 reserve, , , ) = reserveFeed.latestRoundData();
        return reserve;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}


    function decimals()
        public
        view
        virtual
        override(ERC20Upgradeable, IReserveConsumerV3)
        returns (uint8)
    {
        return super.decimals();
    }
}
