// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./GIFTTaxManager.sol";

contract GIFT is
    Initializable,
    ERC20Upgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using SafeMathUpgradeable for uint256;

    address public supplyController;
    address public supplyManager;

    AggregatorV3Interface private reserveFeed;
    GIFTTaxManager public taxManager;

    mapping(address => bool) public isManager;
    mapping(address => uint256) public nonces;


    event NewSupplyController(address indexed newSupplyController);
    event NewSupplyManager(address indexed newSupplyManager);
    event TaxManagerUpdated(address indexed newTaxManager);
    event DelegateTransfer(
        address sender,
        address delegator,
        address receiver,
        uint256 amount
    );

    event ManagerUpdated(address indexed manager, bool isManager);

    modifier onlySupplyController() {
        require(
            msg.sender == supplyController,
            "GIFT: Caller is not the supply controller"
        );
        _;
    }

    modifier onlySupplyManager() {
        require(
            msg.sender == supplyManager,
            "GIFT: Caller is not the supply manager"
        );
        _;
    }

    modifier onlyManager() {
        require(isManager[msg.sender], "GIFT: Caller is not a manager");
        _;
    }

    function initialize(address _aggregatorInterface, address _initialHolder, address _taxManager)
        public
        reinitializer(2)
    {
        __ERC20_init("GIFT", "GIFT");
        __Pausable_init();
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        taxManager = GIFTTaxManager(_taxManager);      
        reserveFeed = AggregatorV3Interface(_aggregatorInterface);

        _mint(_initialHolder, 1000 * 10**18);
    }

function computeTaxUsingManager(uint256 _transferAmount) internal view returns (uint256) {
    uint256 taxPercentage;
    (uint256 tierOneMax, uint256 tierTwoMax, uint256 tierThreeMax, uint256 tierFourMax) = taxManager.getTaxTiers();
    (uint256 tierOneTax, uint256 tierTwoTax, uint256 tierThreeTax, uint256 tierFourTax, uint256 tierFiveTax) = taxManager.getTaxPercentages();

    if (_transferAmount <= tierOneMax) {
        taxPercentage = tierOneTax;
    } else if (_transferAmount <= tierTwoMax) {
        taxPercentage = tierTwoTax;
    } else if (_transferAmount <= tierThreeMax) {
        taxPercentage = tierThreeTax;
    } else if (_transferAmount <= tierFourMax) {
        taxPercentage = tierFourTax;
    } else {
        taxPercentage = tierFiveTax;
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

    function setSupplyManager(address _newSupplyManager) external onlyOwner {
        require(
            _newSupplyManager != address(0),
            "GIFT: Cannot set supply manager to address zero"
        );
        supplyManager = _newSupplyManager;
        emit NewSupplyManager(supplyManager);
    }

    /**
     * Minting and Burn functions
     */

    function inflateSupply(uint256 _value)
        external
        onlySupplyManager
        returns (bool)
    {
        _mint(supplyManager, _value);
        return true;
    }

    function increaseSupply(address _userAddress, uint256 _value)
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
        return _transferGIFT(_msgSender(), recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override whenNotPaused returns (bool) {
        bool success = _transferGIFT(sender, recipient, amount);
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
        bool success = _transferGIFT(delegator, recipient, amount);
        emit DelegateTransfer(msg.sender, delegator, recipient, amount);
        return success;
    }
 
    function _transferGIFT(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual returns (bool) {
        uint256 tax = 0;
        // Check for outbound fees (sender perspective)
        if (
            !taxManager.isExcludedFromOutboundFees(sender) && !taxManager._isLiquidityPool(recipient)
        ) {
            uint256 outboundTax = computeTaxUsingManager(amount);
            tax += outboundTax;
            _transfer(sender, taxManager.beneficiary(), outboundTax);
        }

        // Check for inbound fees (recipient perspective)
        if (
            !taxManager.isExcludedFromInboundFees(recipient) && !taxManager._isLiquidityPool(sender)
        ) {
            uint256 inboundTax = computeTaxUsingManager(amount - tax); // Calculate tax on remaining amount
            tax += inboundTax;
            _transfer(sender, taxManager.beneficiary(), inboundTax);
        }

        // Transfer the remaining amount after taxes
        _transfer(sender, recipient, amount - tax);
        return true;
    }

    function setTaxManager(address _newTaxManager) external onlyOwner {
    require(_newTaxManager != address(0), "GIFT: New tax manager cannot be the zero address");
    taxManager = GIFTTaxManager(_newTaxManager);
    emit TaxManagerUpdated(_newTaxManager);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    function decimals()
        public
        view
        virtual
        override(ERC20Upgradeable)
        returns (uint8)
    {
        return super.decimals();
    }
}
