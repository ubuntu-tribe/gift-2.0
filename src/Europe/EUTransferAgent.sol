// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

/// @title EU TransferAgent for GIFT token
/// @notice Push-only relay with on-chain compliance guards (blacklist, caps, SAR, delays, pause)
contract TransferAgent is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE");
    bytes32 public constant PAUSE_ROLE     = keccak256("PAUSE");
    bytes32 public constant JUDICIAL_ROLE  = keccak256("JUDICIAL");

    IERC20Upgradeable public gift;
    address             public regulatorWallet;

    uint256 public dailyCap;
    uint256 public sarThreshold;
    uint256 public delayThreshold;

    mapping(address => bool)    public blacklisted;
    mapping(address => uint256) public spentToday;
    mapping(address => uint32)  public lastDay;

    struct Deposit { address from; uint128 amount; }
    mapping(bytes32 => Deposit) public deposits;

    enum State { Pending, Frozen, Executed, Confiscated }
    struct Ticket {
        address from;
        address to;
        uint128 amount;
        uint32  created;
        State   state;
    }
    mapping(bytes32 => Ticket) public tickets;
    mapping(bytes32 => bytes32) public hashToTicket;

    event DepositRecorded(bytes32 indexed txHash, address indexed from, uint128 amount);
    event TicketRegistered(bytes32 indexed id, address indexed from, address indexed to, uint128 amount);
    event TransferSuccess(bytes32 indexed id);
    event TransferPending(bytes32 indexed id);
    event TransferFrozen(bytes32 indexed id);
    event TransferConfiscated(bytes32 indexed id);
    event Suspicious(bytes32 indexed id, uint128 amount);
    event Blacklisted(address indexed addr, bool flag, bytes32 reasonHash);
    event Paused(bool paused);

    /// @notice initialize roles, token, regulator and default limits
    function initialize(address _gift, address _regulator) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        gift             = IERC20Upgradeable(_gift);
        regulatorWallet  = _regulator;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(COMPLIANCE_ROLE,    msg.sender);
        _grantRole(PAUSE_ROLE,         msg.sender);
        _grantRole(JUDICIAL_ROLE,      msg.sender);

        dailyCap      = 10_000 * 1e18;
        sarThreshold  = 50_000 * 1e18;
        delayThreshold= 25_000 * 1e18;
    }

    /// @notice collapse deposit + ticket registration into one call
    /// @param txHash         hash of original gift.transfer tx
    /// @param from           sender address
    /// @param to             recipient address
    /// @param amount         amount transferred
    /// @param suspiciousFlag manual override for SAR freeze
    function registerTicket(
        bytes32    txHash,
        address    from,
        address    to,
        uint128    amount,
        bool       suspiciousFlag
    )
        external
        whenNotPaused
        onlyRole(COMPLIANCE_ROLE)
    {
        require(hashToTicket[txHash] == bytes32(0), "ticket exists");

        deposits[txHash] = Deposit(from, amount);
        emit DepositRecorded(txHash, from, amount);

        uint32 today = uint32(block.timestamp / 1 days);
        if (lastDay[from] < today) {
            lastDay[from]   = today;
            spentToday[from]= 0;
        }
        require(spentToday[from] + amount <= dailyCap, "daily cap exceeded");
        spentToday[from] += amount;

        bytes32 ticketId = keccak256(abi.encodePacked(txHash, block.timestamp, from, to));
        hashToTicket[txHash] = ticketId;
        tickets[ticketId] = Ticket(from, to, amount, today, State.Pending);
        emit TicketRegistered(ticketId, from, to, amount);

        if (blacklisted[from] || blacklisted[to]) {
            tickets[ticketId].state = State.Frozen;
            emit TransferFrozen(ticketId);
            return;
        }
        if (suspiciousFlag || amount >= sarThreshold) {
            tickets[ticketId].state = State.Frozen;
            emit Suspicious(ticketId, amount);
            emit TransferFrozen(ticketId);
            return;
        }
        if (amount >= delayThreshold) {
            emit TransferPending(ticketId);
            return;
        }

        tickets[ticketId].state = State.Executed;
        gift.transfer(to, amount);
        emit TransferSuccess(ticketId);
    }

    function execute(bytes32 ticketId) external onlyRole(COMPLIANCE_ROLE) {
        Ticket storage t = tickets[ticketId];
        require(t.state == State.Pending, "not pending");
        t.state = State.Executed;
        gift.transfer(t.to, t.amount);
        emit TransferSuccess(ticketId);
    }

    function freeze(bytes32 ticketId) external onlyRole(JUDICIAL_ROLE) {
        Ticket storage t = tickets[ticketId];
        require(t.state == State.Pending, "not pending");
        t.state = State.Frozen;
        emit TransferFrozen(ticketId);
    }

    function unfreeze(bytes32 ticketId) external onlyRole(JUDICIAL_ROLE) {
        Ticket storage t = tickets[ticketId];
        require(t.state == State.Frozen, "not frozen");
        t.state = State.Pending;
        emit TransferPending(ticketId);
    }

    function confiscate(bytes32 ticketId) external onlyRole(JUDICIAL_ROLE) {
        Ticket storage t = tickets[ticketId];
        require(
            t.state == State.Pending || t.state == State.Frozen,
            "cannot confiscate"
        );
        t.state = State.Confiscated;
        gift.transfer(regulatorWallet, t.amount);
        emit TransferConfiscated(ticketId);
    }

    function setBlacklisted(address usr, bool flag, bytes32 reasonHash)
        external onlyRole(COMPLIANCE_ROLE)
    {
        blacklisted[usr] = flag;
        emit Blacklisted(usr, flag, reasonHash);
    }

    function pause() external onlyRole(PAUSE_ROLE) {
        _pause();
        emit Paused(true);
    }

    function unpause() external onlyRole(PAUSE_ROLE) {
        _unpause();
        emit Paused(false);
    }

    function updateLimits(
        uint256 _dailyCap,
        uint256 _sarThreshold,
        uint256 _delayThreshold
    ) external onlyRole(COMPLIANCE_ROLE) {
        dailyCap       = _dailyCap;
        sarThreshold   = _sarThreshold;
        delayThreshold = _delayThreshold;
    }

    function setRegulator(address _newRegulator) external onlyRole(COMPLIANCE_ROLE) {
        regulatorWallet = _newRegulator;
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
