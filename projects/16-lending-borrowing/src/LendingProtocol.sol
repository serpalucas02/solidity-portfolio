// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/utils/Pausable.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./interfaces/IAggregator.sol";

/**
 * @title LendingProtocol
 * @author Lucas Serpa
 * @dev Collateralized lending protocol in the style of Aave / Compound:
 *      - Deposit a token as collateral and borrow another against it
 *      - Collateral and debt are valued in USD via Chainlink price feeds,
 *        normalizing each token's decimals to a common 18-decimal scale
 *      - Positions become liquidatable when their collateral ratio drops
 *        below the liquidation threshold
 *      - Supports gasless deposits authorized by off-chain ECDSA signatures
 */
contract LendingProtocol is ReentrancyGuard, Pausable, Ownable {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // Structs
    struct User {
        uint256 totalDeposited;
        uint256 totalBorrowed;
        uint256 lastUpdateTime;
        bool isActive;
    }

    struct Market {
        IERC20 token;
        uint256 totalSupply;
        uint256 totalBorrow;
        uint256 supplyRate;
        uint256 borrowRate;
        uint256 collateralFactor;
        bool isActive;
    }

    struct SignatureData {
        uint256 nonce;
        uint256 deadline;
        bytes signature;
    }

    // State variables
    mapping(address => User) public users;
    mapping(address => mapping(address => uint256)) public deposits; // user => token => amount
    mapping(address => mapping(address => uint256)) public borrows; // user => token => amount
    mapping(address => Market) public markets; // token => Market
    mapping(address => uint256) public nonces; // user => nonce
    mapping(address => IAggregator) public priceFeeds; // token => Chainlink price feed

    address[] public supportedTokens;
    uint256 public constant LIQUIDATION_THRESHOLD = 8000; // 80% in basis points
    uint256 public constant LIQUIDATION_PENALTY = 500; // 5% in basis points
    uint256 public constant BASIS_POINT = 10000;
    uint256 private constant PRICE_FEED_DECIMALS = 8; // Chainlink USD feeds use 8 decimals

    // Events
    event MarketAdded(address indexed token, uint256 collateralFactor);
    event MarketUpdated(address indexed token, uint256 collateralFactor);
    event Deposited(
        address indexed user,
        address indexed token,
        uint256 amount
    );
    event Withdrawn(
        address indexed user,
        address indexed token,
        uint256 amount
    );
    event Borrowed(address indexed user, address indexed token, uint256 amount);
    event Repaid(address indexed user, address indexed token, uint256 amount);
    event Liquidated(
        address indexed liquidator,
        address indexed borrower,
        address indexed token,
        uint256 amount
    );
    event RatesUpdated(
        address indexed token,
        uint256 supplyRate,
        uint256 borrowRate
    );
    event PriceFeedSet(address indexed token, address indexed priceFeed);

    // Modifiers
    modifier onlyActiveMarket(address token_) {
        require(
            markets[token_].isActive,
            "LendingProtocol: market is not active"
        );
        _;
    }

    /**
     * @dev Validates the signature deadline and nonce, then consumes the nonce
     *      after the function body runs (so it can't be replayed).
     */
    modifier onlyValidSignature(SignatureData calldata sigData_) {
        require(
            block.timestamp <= sigData_.deadline,
            "LendingProtocol: signature expired"
        );
        require(
            nonces[msg.sender] == sigData_.nonce,
            "LendingProtocol: invalid nonce"
        );
        _;
        nonces[msg.sender]++;
    }

    constructor() Ownable(msg.sender) {}

    /**
     * @notice List a new token as a lending/borrowing market
     * @dev Reverts if the market already exists. Each market still needs a price
     *      feed set via setPriceFeed before borrows/withdrawals can be valued.
     * @param token_ The ERC20 token to list
     * @param collateralFactor_ Borrowable fraction of this collateral, in basis points (0-10000)
     * @param supplyRate_ Initial supply interest rate, in basis points
     * @param borrowRate_ Initial borrow interest rate, in basis points
     */
    function addMarket(
        address token_,
        uint256 collateralFactor_,
        uint256 supplyRate_,
        uint256 borrowRate_
    ) external onlyOwner {
        require(token_ != address(0), "LendingProtocol: token is zero");
        require(
            collateralFactor_ > 0 && collateralFactor_ <= BASIS_POINT,
            "LendingProtocol: invalid collateral factor"
        );
        require(
            supplyRate_ > 0 && supplyRate_ <= BASIS_POINT,
            "LendingProtocol: invalid supply rate"
        );
        require(
            borrowRate_ > 0 && borrowRate_ <= BASIS_POINT,
            "LendingProtocol: invalid borrow rate"
        );
        require(
            !markets[token_].isActive,
            "LendingProtocol: market already exists"
        );

        // Lo que podríamos hacer acá es utilizar el abiEncodePacked para crear los marketIds y guardarlo en vez del token

        markets[token_] = Market({
            token: IERC20(token_),
            totalSupply: 0,
            totalBorrow: 0,
            supplyRate: supplyRate_,
            borrowRate: borrowRate_,
            collateralFactor: collateralFactor_,
            isActive: true
        });

        supportedTokens.push(token_);

        emit MarketAdded(token_, collateralFactor_);
    }

    /**
     * @notice Update an existing market's collateral factor and interest rates
     * @param token_ The market token
     * @param collateralFactor_ New collateral factor, in basis points (0-10000)
     * @param supplyRate_ New supply interest rate, in basis points
     * @param borrowRate_ New borrow interest rate, in basis points
     */
    function updateMarket(
        address token_,
        uint256 collateralFactor_,
        uint256 supplyRate_,
        uint256 borrowRate_
    ) external onlyOwner onlyActiveMarket(token_) {
        require(token_ != address(0), "LendingProtocol: token is zero");
        require(
            collateralFactor_ > 0 && collateralFactor_ <= BASIS_POINT,
            "LendingProtocol: invalid collateral factor"
        );
        require(
            supplyRate_ > 0 && supplyRate_ <= BASIS_POINT,
            "LendingProtocol: invalid supply rate"
        );
        require(
            borrowRate_ > 0 && borrowRate_ <= BASIS_POINT,
            "LendingProtocol: invalid borrow rate"
        );

        markets[token_].collateralFactor = collateralFactor_;
        markets[token_].supplyRate = supplyRate_;
        markets[token_].borrowRate = borrowRate_;

        emit MarketUpdated(token_, collateralFactor_);
        emit RatesUpdated(token_, supplyRate_, borrowRate_);
    }

    /**
     * @notice Set the Chainlink price feed used to value a token
     * @dev The feed must report the token's price in USD (8 decimals).
     * @param token_ The market token
     * @param priceFeed_ The Chainlink aggregator address for token_/USD
     */
    function setPriceFeed(
        address token_,
        address priceFeed_
    ) external onlyOwner {
        require(priceFeed_ != address(0), "LendingProtocol: price feed is zero");
        priceFeeds[token_] = IAggregator(priceFeed_);
        emit PriceFeedSet(token_, priceFeed_);
    }

    /**
     * @notice Deposit tokens into a market, as collateral or as lending liquidity
     * @dev Pulls the tokens via transferFrom, so the caller must approve first.
     * @param token_ The market token to deposit
     * @param amount_ Amount to deposit, in the token's own decimals
     */
    function deposit(
        address token_,
        uint256 amount_
    ) external nonReentrant whenNotPaused onlyActiveMarket(token_) {
        require(token_ != address(0), "LendingProtocol: token is zero");
        require(amount_ > 0, "LendingProtocol: amount must be greater than 0");
        require(
            markets[token_].isActive,
            "LendingProtocol: market is not active"
        );

        IERC20(token_).safeTransferFrom(msg.sender, address(this), amount_);

        deposits[msg.sender][token_] += amount_;
        users[msg.sender].totalDeposited += amount_;
        users[msg.sender].lastUpdateTime = block.timestamp;
        users[msg.sender].isActive = true;
        markets[token_].totalSupply += amount_;

        emit Deposited(msg.sender, token_, amount_);
    }

    /**
     * @notice Withdraw deposited tokens, as long as the position stays healthy
     * @dev Reverts if the withdrawal would push the collateral ratio below the
     *      liquidation threshold (checked via canWithdraw).
     * @param token_ The market token to withdraw
     * @param amount_ Amount to withdraw, in the token's own decimals
     */
    function withdraw(
        address token_,
        uint256 amount_
    ) external nonReentrant whenNotPaused onlyActiveMarket(token_) {
        require(token_ != address(0), "LendingProtocol: token is zero");
        require(amount_ > 0, "LendingProtocol: amount must be greater than 0");
        require(
            deposits[msg.sender][token_] >= amount_,
            "LendingProtocol: insufficient balance"
        );
        require(
            canWithdraw(msg.sender, token_, amount_),
            "LendingProtocol: cannot withdraw"
        );

        deposits[msg.sender][token_] -= amount_;
        users[msg.sender].totalDeposited -= amount_;
        users[msg.sender].lastUpdateTime = block.timestamp;

        if (users[msg.sender].totalDeposited == 0) {
            users[msg.sender].isActive = false;
        }

        markets[token_].totalSupply -= amount_;

        IERC20(token_).safeTransfer(msg.sender, amount_);

        emit Withdrawn(msg.sender, token_, amount_);
    }

    /**
     * @notice Borrow tokens from a market against your deposited collateral
     * @dev Reverts if there isn't enough market liquidity or if the resulting
     *      position would be undercollateralized (checked via canBorrow).
     * @param token_ The market token to borrow
     * @param amount_ Amount to borrow, in the token's own decimals
     */
    function borrow(
        address token_,
        uint256 amount_
    ) external nonReentrant whenNotPaused onlyActiveMarket(token_) {
        require(token_ != address(0), "LendingProtocol: token is zero");
        require(amount_ > 0, "LendingProtocol: amount must be greater than 0");
        require(
            markets[token_].totalSupply >= amount_,
            "LendingProtocol: insufficient supply"
        );
        require(
            canBorrow(msg.sender, token_, amount_),
            "LendingProtocol: cannot borrow"
        );

        borrows[msg.sender][token_] += amount_;
        markets[token_].totalBorrow += amount_;
        users[msg.sender].totalBorrowed += amount_;
        users[msg.sender].lastUpdateTime = block.timestamp;
        users[msg.sender].isActive = true;

        IERC20(token_).safeTransfer(msg.sender, amount_);

        emit Borrowed(msg.sender, token_, amount_);
    }

    /**
     * @notice Repay borrowed tokens, fully or partially
     * @dev Pulls the repaid amount via transferFrom, so the caller must approve first.
     * @param token_ The market token to repay
     * @param amount_ Amount to repay, in the token's own decimals
     */
    function repay(
        address token_,
        uint256 amount_
    ) external nonReentrant whenNotPaused onlyActiveMarket(token_) {
        require(token_ != address(0), "LendingProtocol: token is zero");
        require(amount_ > 0, "LendingProtocol: amount must be greater than 0");
        require(
            borrows[msg.sender][token_] >= amount_,
            "LendingProtocol: insufficient balance"
        );

        IERC20(token_).safeTransferFrom(msg.sender, address(this), amount_);

        borrows[msg.sender][token_] -= amount_;
        markets[token_].totalBorrow -= amount_;
        users[msg.sender].totalBorrowed -= amount_;
        users[msg.sender].lastUpdateTime = block.timestamp;

        if (users[msg.sender].totalBorrowed == 0) {
            users[msg.sender].isActive = false;
        }

        emit Repaid(msg.sender, token_, amount_);
    }

    /**
     * @notice Deposit tokens authorized by an off-chain signature, so a relayer
     *         can submit (and pay the gas for) the transaction on your behalf
     * @dev Rebuilds the EIP-191 signed message and recovers the signer with ECDSA,
     *      which reverts on a malformed signature (no zero-address check needed).
     *      The nonce/deadline are checked and the nonce consumed in onlyValidSignature.
     * @param token_ The token to deposit
     * @param amount_ The amount to deposit
     * @param sigData_ Nonce, deadline and signature authorizing this deposit
     */
    function depositWithSignature(
        address token_,
        uint256 amount_,
        SignatureData calldata sigData_
    )
        external
        nonReentrant
        whenNotPaused
        onlyActiveMarket(token_)
        onlyValidSignature(sigData_)
    {
        require(amount_ > 0, "LendingProtocol: amount must be greater than 0");

        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "deposit",
                token_,
                amount_,
                sigData_.nonce,
                sigData_.deadline
            )
        );
        address signer = messageHash.toEthSignedMessageHash().recover(
            sigData_.signature
        );
        require(signer == msg.sender, "LendingProtocol: invalid signature");

        IERC20(token_).safeTransferFrom(msg.sender, address(this), amount_);

        deposits[msg.sender][token_] += amount_;
        users[msg.sender].totalDeposited += amount_;
        users[msg.sender].lastUpdateTime = block.timestamp;
        users[msg.sender].isActive = true;

        markets[token_].totalSupply += amount_;

        emit Deposited(msg.sender, token_, amount_);
    }

    /**
     * @notice Liquidate an unhealthy position: repay part of its debt and seize collateral
     * @dev Only succeeds if the borrower is below the liquidation threshold. The seized
     *      collateral equals the repaid debt value plus the liquidation penalty,
     *      converted into units of the borrower's most valuable collateral at the
     *      current price. The repaid amount is pulled from the liquidator via transferFrom.
     * @param user_ The borrower being liquidated
     * @param token_ The debt token being repaid
     * @param amount_ Amount of debt to repay, in the token's own decimals
     */
    function liquidate(
        address user_,
        address token_,
        uint256 amount_
    ) external nonReentrant whenNotPaused onlyActiveMarket(token_) {
        require(token_ != address(0), "LendingProtocol: token is zero");
        require(amount_ > 0, "LendingProtocol: amount must be greater than 0");
        require(
            borrows[user_][token_] >= amount_,
            "LendingProtocol: insufficient balance"
        );
        require(isLiquidatable(user_), "LendingProtocol: cannot liquidate");

        // Find collateral token to seize
        address collateralToken = findBestCollateral(user_);
        require(
            collateralToken != address(0),
            "LendingProtocol: no collateral found"
        );

        // USD value of the repaid debt + liquidation penalty, converted into
        // units of the collateral token at its current price.
        uint256 seizeUsd = (_getUsdValue(token_, amount_) *
            (BASIS_POINT + LIQUIDATION_PENALTY)) / BASIS_POINT;
        uint256 collateralToSeize = _getTokenAmountFromUsd(
            collateralToken,
            seizeUsd
        );
        require(
            deposits[user_][collateralToken] >= collateralToSeize,
            "LendingProtocol: insufficient balance"
        );

        // Transfer borrowed tokens from liquidator
        IERC20(token_).safeTransferFrom(msg.sender, address(this), amount_);

        // Update user's borrow
        borrows[user_][token_] -= amount_;
        markets[token_].totalBorrow -= amount_;
        users[user_].totalBorrowed -= amount_;

        // Update Seized Collateral
        deposits[user_][collateralToken] -= collateralToSeize;
        users[user_].totalDeposited -= collateralToSeize;
        markets[collateralToken].totalSupply -= collateralToSeize;

        // Transfer seized collateral to liquidator
        IERC20(collateralToken).safeTransfer(msg.sender, collateralToSeize);

        emit Liquidated(msg.sender, user_, token_, amount_);
    }

    /**
     * @notice Pause deposits, withdrawals, borrows, repays and liquidations
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Resume operations after a pause
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Rescue tokens accidentally sent to the protocol
     * @dev Owner-only escape hatch; does not update protocol accounting, so use
     *      it only for tokens that are not part of an active market's balances.
     * @param token_ The token to recover
     * @param to_ Recipient of the recovered tokens
     * @param amount_ Amount to recover
     */
    function emergencyRecover(
        address token_,
        address to_,
        uint256 amount_
    ) external onlyOwner {
        require(to_ != address(0), "LendingProtocol: invalid recipient");
        IERC20(token_).safeTransfer(to_, amount_);
    }

    /**
     * @notice Current nonce of a user, needed to build the next signed message
     * @param user_ The user address
     */
    function getNonce(address user_) external view returns (uint256) {
        return nonces[user_];
    }

    /**
     * @notice Full configuration and state of a market
     * @param token_ The market token
     */
    function getMarket(address token_) external view returns (Market memory) {
        return markets[token_];
    }

    /**
     * @notice Aggregate position data for a user
     * @param user_ The user address
     */
    function getUser(address user_) external view returns (User memory) {
        return users[user_];
    }

    /**
     * @notice A user's deposited amount for a specific token
     * @param user_ The user address
     * @param token_ The market token
     */
    function getUserDeposit(
        address user_,
        address token_
    ) external view returns (uint256) {
        return deposits[user_][token_];
    }

    /**
     * @notice A user's borrowed amount for a specific token
     * @param user_ The user address
     * @param token_ The market token
     */
    function getUserBorrow(
        address user_,
        address token_
    ) external view returns (uint256) {
        return borrows[user_][token_];
    }

    /**
     * @notice All tokens that currently have a market
     */
    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens;
    }

    /**
     * @notice Whether `user_` could withdraw `amount_` of `token_` and stay healthy
     * @dev Simulates the withdrawal and compares the resulting ratio against the threshold.
     * @param user_ The user withdrawing
     * @param token_ The market token to withdraw
     * @param amount_ Amount to withdraw, in the token's own decimals
     * @return True if the position would remain at or above the liquidation threshold
     */
    function canWithdraw(
        address user_,
        address token_,
        uint256 amount_
    ) public view returns (bool) {
        uint256 currentRatio = getCollateralRatio(user_);
        if (currentRatio == type(uint256).max) return true;

        uint256 newCollateralValue = 0;
        uint256 totalBorrowValue = 0;

        for (uint256 i = 0; i < supportedTokens.length; i++) {
            address token = supportedTokens[i];
            if (markets[token].isActive) {
                uint256 depositAmount = deposits[user_][token];
                uint256 borrowAmount = borrows[user_][token];

                if (token == token_) {
                    depositAmount = depositAmount > amount_
                        ? depositAmount - amount_
                        : 0;
                }

                if (depositAmount > 0) {
                    uint256 depositValue = _getUsdValue(token, depositAmount);
                    newCollateralValue +=
                        (depositValue * markets[token].collateralFactor) /
                        BASIS_POINT;
                }

                if (borrowAmount > 0) {
                    totalBorrowValue += _getUsdValue(token, borrowAmount);
                }
            }
        }

        if (totalBorrowValue == 0) return true;
        uint256 newRatio = (newCollateralValue * BASIS_POINT) /
            totalBorrowValue;
        return newRatio >= LIQUIDATION_THRESHOLD;
    }

    /**
     * @notice Whether `user_` could borrow `amount_` of `token_` and stay healthy
     * @dev Simulates the new debt and compares the resulting ratio against the threshold.
     * @param user_ The user borrowing
     * @param token_ The market token to borrow
     * @param amount_ Amount to borrow, in the token's own decimals
     * @return True if the position would remain at or above the liquidation threshold
     */
    function canBorrow(
        address user_,
        address token_,
        uint256 amount_
    ) public view returns (bool) {
        uint256 totalCollateralValue = 0;
        uint256 totalBorrowValue = 0;

        for (uint256 i = 0; i < supportedTokens.length; i++) {
            address token = supportedTokens[i];
            if (markets[token].isActive) {
                uint256 depositAmount = deposits[user_][token];
                uint256 borrowAmount = borrows[user_][token];

                if (token == token_) {
                    borrowAmount += amount_;
                }

                if (depositAmount > 0) {
                    uint256 depositValue = _getUsdValue(token, depositAmount);
                    totalCollateralValue +=
                        (depositValue * markets[token].collateralFactor) /
                        BASIS_POINT;
                }

                if (borrowAmount > 0) {
                    totalBorrowValue += _getUsdValue(token, borrowAmount);
                }
            }
        }

        if (totalBorrowValue == 0) return true;
        uint256 newRatio = (totalCollateralValue * BASIS_POINT) /
            totalBorrowValue;
        return newRatio >= LIQUIDATION_THRESHOLD;
    }

    /**
     * @notice Current collateral ratio of a user, in basis points
     * @dev (collateral value × 10000) / debt value, both in USD. Returns
     *      type(uint256).max when the user has no debt.
     * @param user_ The user to check
     * @return The collateral ratio in basis points (or max if there is no debt)
     */
    function getCollateralRatio(address user_) public view returns (uint256) {
        uint256 totalCollateralValue = 0;
        uint256 totalBorrowValue = 0;

        for (uint256 i = 0; i < supportedTokens.length; i++) {
            address token = supportedTokens[i];
            if (markets[token].isActive) {
                uint256 depositAmount = deposits[user_][token];
                uint256 borrowAmount = borrows[user_][token];

                if (depositAmount > 0) {
                    uint256 depositValue = _getUsdValue(token, depositAmount);
                    totalCollateralValue +=
                        (depositValue * markets[token].collateralFactor) /
                        BASIS_POINT;
                }

                if (borrowAmount > 0) {
                    totalBorrowValue += _getUsdValue(token, borrowAmount);
                }
            }
        }

        if (totalBorrowValue == 0) return type(uint256).max;
        return (totalCollateralValue * BASIS_POINT) / totalBorrowValue;
    }

    /**
     * @notice Whether a user's position can be liquidated
     * @param user_ The user to check
     * @return True if the collateral ratio is below the liquidation threshold
     */
    function isLiquidatable(address user_) public view returns (bool) {
        uint256 collateralRatio = getCollateralRatio(user_);
        return collateralRatio < LIQUIDATION_THRESHOLD;
    }

    /**
     * @notice Latest USD price of a token from its Chainlink feed (8 decimals)
     * @dev Reverts if no feed is configured or the feed returns a non-positive price.
     * @param token_ The market token
     */
    function getPrice(address token_) public view returns (uint256) {
        IAggregator feed = priceFeeds[token_];
        require(address(feed) != address(0), "LendingProtocol: no price feed");
        (, int256 answer, , , ) = feed.latestRoundData();
        require(answer > 0, "LendingProtocol: invalid price");
        return uint256(answer);
    }

    /**
     * @dev Converts a token amount into its USD value normalized to 18 decimals.
     *      Combines the token's own decimals with the feed's 8 decimals so that
     *      values of tokens with different decimals can be summed and compared.
     */
    function _getUsdValue(
        address token_,
        uint256 amount_
    ) internal view returns (uint256) {
        uint256 price = getPrice(token_);
        uint8 tokenDecimals = IERC20Metadata(token_).decimals();
        return
            (amount_ * price * 1e18) /
            (10 ** tokenDecimals * 10 ** PRICE_FEED_DECIMALS);
    }

    /**
     * @dev Inverse of _getUsdValue: given a USD value (18 decimals), returns how
     *      many units of token_ it represents at the current price. Used in
     *      liquidations to convert the seized debt value into collateral units.
     */
    function _getTokenAmountFromUsd(
        address token_,
        uint256 usdValue_
    ) internal view returns (uint256) {
        uint256 price = getPrice(token_);
        uint8 tokenDecimals = IERC20Metadata(token_).decimals();
        return
            (usdValue_ * 10 ** tokenDecimals * 10 ** PRICE_FEED_DECIMALS) /
            (price * 1e18);
    }

    /**
     * @dev Returns the user's deposited token with the highest USD value — the
     *      most efficient collateral to seize in a liquidation. Zero address if none.
     */
    function findBestCollateral(address user_) internal view returns (address) {
        address bestToken = address(0);
        uint256 bestValue = 0;

        for (uint256 i = 0; i < supportedTokens.length; i++) {
            address token = supportedTokens[i];
            if (markets[token].isActive && deposits[user_][token] > 0) {
                uint256 depositValue = _getUsdValue(
                    token,
                    deposits[user_][token]
                );
                uint256 value = (depositValue *
                    markets[token].collateralFactor) / BASIS_POINT;
                if (value > bestValue) {
                    bestValue = value;
                    bestToken = token;
                }
            }
        }

        return bestToken;
    }
}
