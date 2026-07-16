// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.26;

interface IPancakeV2Factory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);

    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);
}

/**
 * @title Osiris Investor Token
 * @author Osiris
 *
 * Features:
 * - Name: Osiris Investor Token
 * - Symbol: OSINV
 * - Fixed supply: 10,000,000,000 OSINV
 * - Decimals: 18
 * - Burns 0.1% on every transfer
 * - Normal recipients must wait 24 hours before transferring or selling
 * - Current owner can transfer immediately
 * - Owner can exempt additional addresses
 * - Automatically creates and registers the PancakeSwap V2 OSIR/OSINV pair
 * - The PancakeSwap pair can always send tokens and can never become locked
 *
 * BSC MAINNET VERSION
 */
contract OsirisInvestorToken {
    /*//////////////////////////////////////////////////////////////
                             TOKEN DETAILS
    //////////////////////////////////////////////////////////////*/

    string private constant TOKEN_NAME =
        "Osiris Investor Token";

    string private constant TOKEN_SYMBOL =
        "OSINV";

    uint8 private constant TOKEN_DECIMALS = 18;

    uint256 public constant INITIAL_SUPPLY =
        10_000_000_000 * 10 ** uint256(TOKEN_DECIMALS);

    /**
     * 0.1% burn:
     *
     * amount / 1000 = 0.001 = 0.1%
     */
    uint256 public constant BURN_DIVISOR = 1000;

    /**
     * Tokens must remain in a normal wallet for 24 hours.
     */
    uint256 public constant HOLDING_PERIOD = 1 days;

    /*//////////////////////////////////////////////////////////////
                         BSC MAINNET ADDRESSES
    //////////////////////////////////////////////////////////////*/

    /**
     * Existing Osiris Token, OSIR.
     */
    address public constant OSIR_TOKEN =
        0x9Ca5EeaCF3517F2304244e82226Ae01D410290f2;

    /**
     * Official PancakeSwap V2 Factory on BSC Mainnet.
     */
    address public constant PANCAKE_V2_FACTORY =
        0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;

    /**
     * Official PancakeSwap V2 Router on BSC Mainnet.
     *
     * Stored for informational purposes and frontend integration.
     * The router does not need a transfer-lock exemption.
     */
    address public constant PANCAKE_V2_ROUTER =
        0x10ED43C718714eb63d5aA57B78B54704E256024E;

    /**
     * Automatically created OSIR/OSINV PancakeSwap V2 pair.
     */
    address public immutable osirPair;

    /*//////////////////////////////////////////////////////////////
                              OWNERSHIP
    //////////////////////////////////////////////////////////////*/

    address private _owner;

    /*//////////////////////////////////////////////////////////////
                           BEP-20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 private _totalSupply;

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256))
        private _allowances;

    /*//////////////////////////////////////////////////////////////
                           LOCK STORAGE
    //////////////////////////////////////////////////////////////*/

    /**
     * The time when an address most recently received OSINV.
     *
     * For a normal address, any new receipt resets this timestamp.
     */
    mapping(address => uint256) public lastReceivedAt;

    /**
     * Additional addresses allowed to transfer immediately.
     *
     * The owner and osirPair are handled separately and are always exempt.
     */
    mapping(address => bool) public transferLockExempt;

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 value
    );

    event Approval(
        address indexed tokenOwner,
        address indexed spender,
        uint256 value
    );

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    event TransferLockExemptionUpdated(
        address indexed account,
        bool isExempt
    );

    event OsirPairRegistered(
        address indexed pair,
        address indexed osirToken,
        address indexed osinvToken
    );

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        require(
            msg.sender == _owner,
            "OSINV: caller is not owner"
        );
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        require(
            PANCAKE_V2_FACTORY.code.length > 0,
            "OSINV: factory is not a contract"
        );

        require(
            OSIR_TOKEN.code.length > 0,
            "OSINV: OSIR is not a contract"
        );

        _owner = msg.sender;

        emit OwnershipTransferred(
            address(0),
            msg.sender
        );

        /*
         * Create the OSIR/OSINV pair before minting the supply.
         *
         * The pair initially has zero reserves. Liquidity is added later.
         */
        IPancakeV2Factory factory =
            IPancakeV2Factory(PANCAKE_V2_FACTORY);

        address pair = factory.getPair(
            address(this),
            OSIR_TOKEN
        );

        /*
         * Normally this will always be zero because this OSINV contract
         * has just been deployed.
         */
        if (pair == address(0)) {
            pair = factory.createPair(
                address(this),
                OSIR_TOKEN
            );
        }

        require(
            pair != address(0),
            "OSINV: pair creation failed"
        );

        require(
            pair.code.length > 0,
            "OSINV: invalid pair contract"
        );

        osirPair = pair;

        emit OsirPairRegistered(
            pair,
            OSIR_TOKEN,
            address(this)
        );

        /*
         * Mint the complete fixed supply to the deployer.
         */
        _totalSupply = INITIAL_SUPPLY;
        _balances[msg.sender] = INITIAL_SUPPLY;

        emit Transfer(
            address(0),
            msg.sender,
            INITIAL_SUPPLY
        );
    }

    /*//////////////////////////////////////////////////////////////
                          TOKEN INFORMATION
    //////////////////////////////////////////////////////////////*/

    function name()
        external
        pure
        returns (string memory)
    {
        return TOKEN_NAME;
    }

    function symbol()
        external
        pure
        returns (string memory)
    {
        return TOKEN_SYMBOL;
    }

    function decimals()
        external
        pure
        returns (uint8)
    {
        return TOKEN_DECIMALS;
    }

    function totalSupply()
        external
        view
        returns (uint256)
    {
        return _totalSupply;
    }

    function owner()
        public
        view
        returns (address)
    {
        return _owner;
    }

    /**
     * BEP-20 compatibility function.
     */
    function getOwner()
        external
        view
        returns (address)
    {
        return _owner;
    }

    function balanceOf(
        address account
    )
        public
        view
        returns (uint256)
    {
        return _balances[account];
    }

    function allowance(
        address tokenOwner,
        address spender
    )
        external
        view
        returns (uint256)
    {
        return _allowances[tokenOwner][spender];
    }

    /*//////////////////////////////////////////////////////////////
                          BEP-20 OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function transfer(
        address recipient,
        uint256 amount
    )
        external
        returns (bool)
    {
        _transfer(
            msg.sender,
            recipient,
            amount
        );

        return true;
    }

    function approve(
        address spender,
        uint256 amount
    )
        external
        returns (bool)
    {
        _approve(
            msg.sender,
            spender,
            amount
        );

        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    )
        external
        returns (bool)
    {
        uint256 currentAllowance =
            _allowances[sender][msg.sender];

        require(
            currentAllowance >= amount,
            "OSINV: insufficient allowance"
        );

        _transfer(
            sender,
            recipient,
            amount
        );

        /*
         * Preserve unlimited approval.
         */
        if (currentAllowance != type(uint256).max) {
            unchecked {
                _approve(
                    sender,
                    msg.sender,
                    currentAllowance - amount
                );
            }
        }

        return true;
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    )
        external
        returns (bool)
    {
        _approve(
            msg.sender,
            spender,
            _allowances[msg.sender][spender]
                + addedValue
        );

        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    )
        external
        returns (bool)
    {
        uint256 currentAllowance =
            _allowances[msg.sender][spender];

        require(
            currentAllowance >= subtractedValue,
            "OSINV: allowance below zero"
        );

        unchecked {
            _approve(
                msg.sender,
                spender,
                currentAllowance - subtractedValue
            );
        }

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                       INTERNAL TRANSFER LOGIC
    //////////////////////////////////////////////////////////////*/

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    )
        internal
    {
        require(
            sender != address(0),
            "OSINV: transfer from zero address"
        );

        require(
            recipient != address(0),
            "OSINV: transfer to zero address"
        );

        require(
            amount > 0,
            "OSINV: amount is zero"
        );

        uint256 senderBalance =
            _balances[sender];

        require(
            senderBalance >= amount,
            "OSINV: insufficient balance"
        );

        /*
         * Check the actual token holder, not msg.sender.
         *
         * This prevents bypassing the lock through:
         * - transferFrom()
         * - PancakeSwap Router
         * - Another wallet
         * - Another smart contract
         */
        _requireTransferUnlocked(sender);

        /*
         * Calculate 0.1% burn.
         */
        uint256 burnAmount =
            amount / BURN_DIVISOR;

        uint256 receivedAmount =
            amount - burnAmount;

        unchecked {
            _balances[sender] =
                senderBalance - amount;
        }

        _balances[recipient] +=
            receivedAmount;

        /*
         * The recipient receives amount minus the burn.
         */
        emit Transfer(
            sender,
            recipient,
            receivedAmount
        );

        /*
         * Burn the fee from total supply.
         */
        if (burnAmount > 0) {
            _totalSupply -= burnAmount;

            emit Transfer(
                sender,
                address(0),
                burnAmount
            );
        }

        /*
         * Start or reset the 24-hour timer for every normal recipient.
         *
         * Never record a timer for:
         * - The OSIR/OSINV pair
         * - The current owner
         * - Owner-approved exempt addresses
         */
        if (!_isTransferLockExempt(recipient)) {
            lastReceivedAt[recipient] =
                block.timestamp;
        }
    }

    function _requireTransferUnlocked(
        address sender
    )
        internal
        view
    {
        /*
         * The following can always transfer:
         *
         * 1. Current owner
         * 2. OSIR/OSINV PancakeSwap pair
         * 3. Addresses explicitly exempted by owner
         */
        if (_isTransferLockExempt(sender)) {
            return;
        }

        uint256 receivedTime =
            lastReceivedAt[sender];

        require(
            receivedTime != 0,
            "OSINV: receipt timestamp missing"
        );

        require(
            block.timestamp >=
                receivedTime + HOLDING_PERIOD,
            "OSINV: wait 24 hours before transfer"
        );
    }

    function _approve(
        address tokenOwner,
        address spender,
        uint256 amount
    )
        internal
    {
        require(
            tokenOwner != address(0),
            "OSINV: approve from zero address"
        );

        require(
            spender != address(0),
            "OSINV: approve to zero address"
        );

        _allowances[tokenOwner][spender] =
            amount;

        emit Approval(
            tokenOwner,
            spender,
            amount
        );
    }

    /*//////////////////////////////////////////////////////////////
                       EXEMPTION MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allows the owner to exempt or unexempt an address.
     *
     * An exempt address can sell or transfer immediately.
     *
     * The PancakeSwap pair is permanently exempt and cannot be changed
     * through this function.
     */
    function setTransferLockExempt(
        address account,
        bool exempt
    )
        external
        onlyOwner
    {
        require(
            account != address(0),
            "OSINV: zero address"
        );

        require(
            account != osirPair,
            "OSINV: pair is permanently exempt"
        );

        require(
            account != _owner,
            "OSINV: owner is always exempt"
        );

        transferLockExempt[account] =
            exempt;

        /*
         * When removing an exemption from a wallet that has tokens,
         * begin a new 24-hour holding period.
         *
         * This prevents the address from being unexempted and then
         * transferring immediately using an old or missing timestamp.
         */
        if (
            !exempt &&
            _balances[account] > 0
        ) {
            lastReceivedAt[account] =
                block.timestamp;
        }

        emit TransferLockExemptionUpdated(
            account,
            exempt
        );
    }

    /**
     * @notice Add multiple exempt addresses.
     *
     * Limited to 100 addresses to prevent excessive gas use.
     */
    function addTransferLockExemptBatch(
        address[] calldata accounts
    )
        external
        onlyOwner
    {
        require(
            accounts.length <= 100,
            "OSINV: too many addresses"
        );

        for (
            uint256 i = 0;
            i < accounts.length;
            i++
        ) {
            address account =
                accounts[i];

            require(
                account != address(0),
                "OSINV: zero address"
            );

            require(
                account != osirPair,
                "OSINV: pair already exempt"
            );

            require(
                account != _owner,
                "OSINV: owner already exempt"
            );

            transferLockExempt[account] =
                true;

            emit TransferLockExemptionUpdated(
                account,
                true
            );
        }
    }

    function isTransferLockExempt(
        address account
    )
        external
        view
        returns (bool)
    {
        return _isTransferLockExempt(
            account
        );
    }

    function _isTransferLockExempt(
        address account
    )
        internal
        view
        returns (bool)
    {
        return
            account == _owner ||
            account == osirPair ||
            transferLockExempt[account];
    }

    /*//////////////////////////////////////////////////////////////
                            LOCK DETAILS
    //////////////////////////////////////////////////////////////*/

    function unlockTime(
        address account
    )
        public
        view
        returns (uint256)
    {
        if (_isTransferLockExempt(account)) {
            return 0;
        }

        uint256 receivedTime =
            lastReceivedAt[account];

        if (receivedTime == 0) {
            return 0;
        }

        return
            receivedTime + HOLDING_PERIOD;
    }

    function remainingLockTime(
        address account
    )
        external
        view
        returns (uint256)
    {
        if (_isTransferLockExempt(account)) {
            return 0;
        }

        uint256 accountUnlockTime =
            unlockTime(account);

        if (
            accountUnlockTime == 0 ||
            block.timestamp >= accountUnlockTime
        ) {
            return 0;
        }

        return
            accountUnlockTime -
            block.timestamp;
    }

    function canTransfer(
        address account
    )
        external
        view
        returns (bool)
    {
        if (_isTransferLockExempt(account)) {
            return true;
        }

        uint256 receivedTime =
            lastReceivedAt[account];

        return
            receivedTime != 0 &&
            block.timestamp >=
                receivedTime + HOLDING_PERIOD;
    }

    /*//////////////////////////////////////////////////////////////
                         OWNERSHIP MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function transferOwnership(
        address newOwner
    )
        external
        onlyOwner
    {
        require(
            newOwner != address(0),
            "OSINV: new owner is zero"
        );

        address previousOwner =
            _owner;

        require(
            newOwner != previousOwner,
            "OSINV: already owner"
        );

        _owner = newOwner;

        /*
         * The former owner becomes a normal wallet unless it was
         * separately included in transferLockExempt.
         */
        if (
            !transferLockExempt[previousOwner] &&
            _balances[previousOwner] > 0
        ) {
            lastReceivedAt[previousOwner] =
                block.timestamp;
        }

        emit OwnershipTransferred(
            previousOwner,
            newOwner
        );
    }

    function renounceOwnership()
        external
        onlyOwner
    {
        address previousOwner =
            _owner;

        /*
         * Once ownership is renounced, exemptions cannot be changed.
         */
        _owner = address(0);

        if (
            !transferLockExempt[previousOwner] &&
            _balances[previousOwner] > 0
        ) {
            lastReceivedAt[previousOwner] =
                block.timestamp;
        }

        emit OwnershipTransferred(
            previousOwner,
            address(0)
        );
    }
}
