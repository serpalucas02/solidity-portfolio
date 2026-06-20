// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
    VRFConsumerBaseV2Plus
} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {
    VRFV2PlusClient
} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Multi-Round VRF Lottery
 * @author Lucas Serpa
 * @dev Multi-round lottery with provably-fair winner selection via Chainlink VRF 2.5:
 *      - Each round has a configurable time window, ticket price and max tickets per player
 *      - Up to 3 winners per round, split 50/30/20 (third gets the remainder)
 *      - Prizes are claimed with pull payments (claimPrize) so the VRF callback can never be
 *        bricked by a winner that rejects ETH
 *      - Inherits VRFConsumerBaseV2Plus (provides s_vrfCoordinator and onlyOwner via ConfirmedOwner)
 */
contract Lottery is VRFConsumerBaseV2Plus, ReentrancyGuard {
    /// @notice Lifecycle state of a lottery round
    enum RoundState {
        OPEN, // accepting ticket purchases
        CALCULATING, // VRF request sent, awaiting callback
        CLOSED // winners assigned (or round refunded)
    }

    /// @notice Owner-configurable parameters snapshotted into each new round
    struct LotteryConfig {
        uint256 ticketPrice;
        uint256 roundDuration;
        uint256 maxTicketsPerPlayer;
        uint256 minPlayers;
        uint16 protocolFeeBps;
    }

    /// @notice Full data for a single round
    struct Round {
        RoundState state;
        uint256 startTime;
        uint256 endTime;
        uint256 ticketPrice;
        uint256 maxTicketsPerPlayer;
        uint256 minPlayers;
        uint16 protocolFeeBps;
        uint256 prizePool;
        uint256 protocolFeeCollected;
        address[] players; // one entry per ticket (weighted odds)
        address[] uniquePlayers; // deduplicated player addresses
        address[3] winners; // 1st, 2nd, 3rd
        uint256[3] payouts; // prize amount per tier
        uint256 vrfRequestId;
        bool refunded;
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------
    error Lottery__RoundNotOpen(uint256 roundId);
    error Lottery__RoundNotCalculating(uint256 roundId);
    error Lottery__RoundStillOpen(uint256 roundId);
    error Lottery__InsufficientPayment(uint256 sent, uint256 required);
    error Lottery__MaxTicketsExceeded(uint256 requested, uint256 max);
    error Lottery__ZeroTickets();
    error Lottery__TransferFailed(address recipient, uint256 amount);
    error Lottery__NotEnoughPlayers(uint256 current, uint256 required);
    error Lottery__InvalidTicketPrice();
    error Lottery__InvalidRoundDuration();
    error Lottery__InvalidMaxTickets();
    error Lottery__InvalidProtocolFee();
    error Lottery__InvalidMinPlayers();
    error Lottery__NoRefundAvailable();
    error Lottery__NothingToWithdraw();
    error Lottery__PreviousRoundNotClosed();
    error Lottery__NoPrizeToClaim();

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------
    event RoundStarted(
        uint256 indexed roundId,
        uint256 startTime,
        uint256 endTime,
        uint256 ticketPrice
    );
    event TicketsPurchased(
        uint256 indexed roundId,
        address indexed player,
        uint256 quantity,
        uint256 totalPlayerTickets
    );
    event DrawRequested(uint256 indexed roundId, uint256 indexed vrfRequestId);
    event WinnersSelected(
        uint256 indexed roundId,
        address[3] winners,
        uint256[3] payouts
    );
    event RoundRefunded(uint256 indexed roundId, uint256 playerCount);
    event RefundClaimed(
        uint256 indexed roundId,
        address indexed player,
        uint256 amount
    );
    event PrizeClaimed(
        uint256 indexed roundId,
        address indexed winner,
        uint256 amount
    );
    event ProtocolFeeCollected(uint256 indexed roundId, uint256 amount);
    event FeesWithdrawn(address indexed to, uint256 amount);
    event ConfigUpdated(
        uint256 ticketPrice,
        uint256 roundDuration,
        uint256 maxTicketsPerPlayer,
        uint256 minPlayers,
        uint16 protocolFeeBps
    );

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------
    uint16 private constant MAX_PROTOCOL_FEE_BPS = 1000; // 10%
    uint16 private constant REQUEST_CONFIRMATIONS = 3; // chequear cuántas pide la red usada
    uint32 private constant NUM_WORDS = 3; // un random word por puesto
    uint16 private constant FIRST_PLACE_BPS = 5000; // 50%
    uint16 private constant SECOND_PLACE_BPS = 3000; // 30%
    // El tercer puesto recibe el remanente (~20%) para evitar dust por redondeo

    // -------------------------------------------------------------------------
    // Immutables (VRF config set at deploy)
    // -------------------------------------------------------------------------
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------
    LotteryConfig private s_config;
    uint256 private s_currentRoundId;
    uint256 private s_accumulatedFees;

    mapping(uint256 roundId => Round) private s_rounds;
    mapping(uint256 vrfRequestId => uint256 roundId)
        private s_vrfRequestIdToRoundId;
    mapping(uint256 roundId => mapping(address player => uint256 tickets))
        private s_playerTickets;
    // Pull-payment ledger: cuánto premio tiene reclamable cada ganador por ronda
    mapping(uint256 roundId => mapping(address winner => uint256 prize))
        private s_prizes;

    /**
     * @param vrfCoordinator Chainlink VRF V2.5 Coordinator address
     * @param keyHash Gas lane key hash
     * @param subscriptionId VRF subscription ID (uint256 in V2.5)
     * @param callbackGasLimit Max gas for the VRF callback
     * @param ticketPrice Initial ticket price in wei
     * @param roundDuration Duration of each round in seconds
     * @param maxTicketsPerPlayer Max tickets one address can buy per round
     * @param minPlayers Minimum unique players for a valid draw
     * @param protocolFeeBps Protocol fee in basis points (max 1000 = 10%)
     */
    constructor(
        address vrfCoordinator,
        bytes32 keyHash,
        uint256 subscriptionId,
        uint32 callbackGasLimit,
        uint256 ticketPrice,
        uint256 roundDuration,
        uint256 maxTicketsPerPlayer,
        uint256 minPlayers,
        uint16 protocolFeeBps
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        if (ticketPrice == 0) revert Lottery__InvalidTicketPrice();
        if (roundDuration == 0) revert Lottery__InvalidRoundDuration();
        if (maxTicketsPerPlayer == 0) revert Lottery__InvalidMaxTickets();
        if (minPlayers == 0) revert Lottery__InvalidMinPlayers();
        if (protocolFeeBps > MAX_PROTOCOL_FEE_BPS)
            revert Lottery__InvalidProtocolFee();

        i_keyHash = keyHash;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_config = LotteryConfig({
            ticketPrice: ticketPrice,
            roundDuration: roundDuration,
            maxTicketsPerPlayer: maxTicketsPerPlayer,
            minPlayers: minPlayers,
            protocolFeeBps: protocolFeeBps
        });
    }

    // -------------------------------------------------------------------------
    // External — Core
    // -------------------------------------------------------------------------

    /**
     * @notice Start a new lottery round, snapshotting the current config
     * @dev Reverts if the previous round is not CLOSED yet.
     */
    function startNewRound() external onlyOwner {
        if (s_currentRoundId > 0) {
            Round storage prev = s_rounds[s_currentRoundId];
            if (prev.state != RoundState.CLOSED) {
                revert Lottery__PreviousRoundNotClosed();
            }
        }

        s_currentRoundId++;
        uint256 roundId = s_currentRoundId;
        LotteryConfig memory cfg = s_config;

        Round storage r = s_rounds[roundId];
        r.state = RoundState.OPEN;
        r.startTime = block.timestamp;
        r.endTime = block.timestamp + cfg.roundDuration;
        r.ticketPrice = cfg.ticketPrice;
        r.maxTicketsPerPlayer = cfg.maxTicketsPerPlayer;
        r.minPlayers = cfg.minPlayers;
        r.protocolFeeBps = cfg.protocolFeeBps;

        emit RoundStarted(roundId, r.startTime, r.endTime, r.ticketPrice);
    }

    /**
     * @notice Buy tickets for the current open round
     * @dev Follows CEI: state is updated before the excess-ETH refund.
     * @param quantity Number of tickets to purchase
     */
    function buyTickets(uint256 quantity) external payable nonReentrant {
        if (quantity == 0) revert Lottery__ZeroTickets();

        uint256 roundId = s_currentRoundId;
        Round storage r = s_rounds[roundId];

        if (r.state != RoundState.OPEN) revert Lottery__RoundNotOpen(roundId);
        if (block.timestamp >= r.endTime) revert Lottery__RoundNotOpen(roundId);

        uint256 totalCost = r.ticketPrice * quantity;
        if (msg.value < totalCost) {
            revert Lottery__InsufficientPayment(msg.value, totalCost);
        }

        uint256 currentTickets = s_playerTickets[roundId][msg.sender];
        if (currentTickets + quantity > r.maxTicketsPerPlayer) {
            revert Lottery__MaxTicketsExceeded(
                currentTickets + quantity,
                r.maxTicketsPerPlayer
            );
        }

        // Effects
        if (currentTickets == 0) {
            r.uniquePlayers.push(msg.sender);
        }
        s_playerTickets[roundId][msg.sender] = currentTickets + quantity;

        for (uint256 i; i < quantity; ++i) {
            r.players.push(msg.sender);
        }
        r.prizePool += totalCost;

        emit TicketsPurchased(
            roundId,
            msg.sender,
            quantity,
            currentTickets + quantity
        );

        // Refund excess ETH (interaction last — CEI)
        uint256 excess = msg.value - totalCost;
        if (excess > 0) {
            (bool ok, ) = payable(msg.sender).call{value: excess}("");
            if (!ok) revert Lottery__TransferFailed(msg.sender, excess);
        }
    }

    /**
     * @notice Trigger the draw for a round whose time window has expired
     * @dev Permissionless. If the minimum unique players is not met, the round
     *      is marked refundable instead of requesting VRF. Transitions to
     *      CALCULATING before the external VRF call (CEI).
     * @param roundId The round to draw
     */
    function requestDraw(uint256 roundId) external {
        Round storage r = s_rounds[roundId];

        if (r.state != RoundState.OPEN) revert Lottery__RoundNotOpen(roundId);
        if (block.timestamp < r.endTime) revert Lottery__RoundStillOpen(roundId);

        // Not enough unique players → refund path
        if (r.uniquePlayers.length < r.minPlayers) {
            r.state = RoundState.CLOSED;
            r.refunded = true;
            emit RoundRefunded(roundId, r.uniquePlayers.length);
            return;
        }

        r.state = RoundState.CALCULATING;

        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );

        r.vrfRequestId = requestId;
        s_vrfRequestIdToRoundId[requestId] = roundId;

        emit DrawRequested(roundId, requestId);
    }

    /**
     * @notice Claim a refund for a cancelled round (not enough players)
     * @dev Pull payment with CEI: tickets are zeroed before the transfer.
     * @param roundId The refunded round
     */
    function claimRefund(uint256 roundId) external nonReentrant {
        Round storage r = s_rounds[roundId];

        if (!r.refunded) revert Lottery__NoRefundAvailable();

        uint256 tickets = s_playerTickets[roundId][msg.sender];
        if (tickets == 0) revert Lottery__NoRefundAvailable();

        uint256 refundAmount = tickets * r.ticketPrice;

        // Effects before interaction (CEI)
        s_playerTickets[roundId][msg.sender] = 0;

        (bool ok, ) = payable(msg.sender).call{value: refundAmount}("");
        if (!ok) revert Lottery__TransferFailed(msg.sender, refundAmount);

        emit RefundClaimed(roundId, msg.sender, refundAmount);
    }

    /**
     * @notice Claim your prize from a finished round (pull payment)
     * @dev Kept separate from fulfillRandomWords so the VRF callback can never
     *      be bricked by a winner that rejects ETH — each winner pulls their own
     *      prize. CEI: the balance is zeroed before the transfer.
     * @param roundId The round you won a prize in
     */
    function claimPrize(uint256 roundId) external nonReentrant {
        uint256 prize = s_prizes[roundId][msg.sender];
        if (prize == 0) revert Lottery__NoPrizeToClaim();

        // Effects before interaction (CEI)
        s_prizes[roundId][msg.sender] = 0;

        (bool ok, ) = payable(msg.sender).call{value: prize}("");
        if (!ok) revert Lottery__TransferFailed(msg.sender, prize);

        emit PrizeClaimed(roundId, msg.sender, prize);
    }

    // -------------------------------------------------------------------------
    // External — Owner Admin
    // -------------------------------------------------------------------------

    /**
     * @notice Update the ticket price for future rounds
     * @param newPrice New ticket price in wei
     */
    function setTicketPrice(uint256 newPrice) external onlyOwner {
        if (newPrice == 0) revert Lottery__InvalidTicketPrice();
        s_config.ticketPrice = newPrice;
        _emitConfigUpdated();
    }

    /**
     * @notice Update the round duration for future rounds
     * @param newDuration New duration in seconds
     */
    function setRoundDuration(uint256 newDuration) external onlyOwner {
        if (newDuration == 0) revert Lottery__InvalidRoundDuration();
        s_config.roundDuration = newDuration;
        _emitConfigUpdated();
    }

    /**
     * @notice Update the max tickets per player for future rounds
     * @param newMax New per-player ticket cap
     */
    function setMaxTicketsPerPlayer(uint256 newMax) external onlyOwner {
        if (newMax == 0) revert Lottery__InvalidMaxTickets();
        s_config.maxTicketsPerPlayer = newMax;
        _emitConfigUpdated();
    }

    /**
     * @notice Update the minimum unique players for future rounds
     * @param newMin New minimum players for a valid draw
     */
    function setMinPlayers(uint256 newMin) external onlyOwner {
        if (newMin == 0) revert Lottery__InvalidMinPlayers();
        s_config.minPlayers = newMin;
        _emitConfigUpdated();
    }

    /**
     * @notice Update the protocol fee for future rounds
     * @param newFeeBps New fee in basis points (max 1000 = 10%)
     */
    function setProtocolFee(uint16 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_PROTOCOL_FEE_BPS) {
            revert Lottery__InvalidProtocolFee();
        }
        s_config.protocolFeeBps = newFeeBps;
        _emitConfigUpdated();
    }

    /**
     * @notice Withdraw the accumulated protocol fees
     * @param to Recipient of the fees
     */
    function withdrawFees(address to) external onlyOwner nonReentrant {
        uint256 amount = s_accumulatedFees;
        if (amount == 0) revert Lottery__NothingToWithdraw();

        s_accumulatedFees = 0;

        (bool ok, ) = payable(to).call{value: amount}("");
        if (!ok) revert Lottery__TransferFailed(to, amount);

        emit FeesWithdrawn(to, amount);
    }

    // -------------------------------------------------------------------------
    // External — View
    // -------------------------------------------------------------------------

    /// @notice Full data of a round
    function getRound(uint256 roundId) external view returns (Round memory) {
        return s_rounds[roundId];
    }

    /// @notice Id of the current (latest) round
    function getCurrentRoundId() external view returns (uint256) {
        return s_currentRoundId;
    }

    /// @notice Owner config applied to future rounds
    function getConfig() external view returns (LotteryConfig memory) {
        return s_config;
    }

    /// @notice Tickets `player` holds in `roundId`
    function getPlayerTickets(
        uint256 roundId,
        address player
    ) external view returns (uint256) {
        return s_playerTickets[roundId][player];
    }

    /// @notice Prize still claimable by `winner` in `roundId`
    function getPrize(
        uint256 roundId,
        address winner
    ) external view returns (uint256) {
        return s_prizes[roundId][winner];
    }

    /// @notice Protocol fees pending withdrawal
    function getAccumulatedFees() external view returns (uint256) {
        return s_accumulatedFees;
    }

    /// @notice All ticket entries of a round (one per ticket, weighted)
    function getRoundPlayers(
        uint256 roundId
    ) external view returns (address[] memory) {
        return s_rounds[roundId].players;
    }

    /// @notice Deduplicated players of a round
    function getRoundUniquePlayers(
        uint256 roundId
    ) external view returns (address[] memory) {
        return s_rounds[roundId].uniquePlayers;
    }

    /// @notice The (up to) 3 winners of a round
    function getRoundWinners(
        uint256 roundId
    ) external view returns (address[3] memory) {
        return s_rounds[roundId].winners;
    }

    /// @notice The payouts per tier of a round
    function getRoundPayouts(
        uint256 roundId
    ) external view returns (uint256[3] memory) {
        return s_rounds[roundId].payouts;
    }

    // -------------------------------------------------------------------------
    // Internal — VRF Callback
    // -------------------------------------------------------------------------

    /**
     * @dev Called by the VRF Coordinator via rawFulfillRandomWords. Selects up to
     *      3 unique winners, computes prizes, and ASSIGNS them to the pull-payment
     *      ledger (no ETH is sent here, see claimPrize).
     */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        uint256 roundId = s_vrfRequestIdToRoundId[requestId];
        Round storage r = s_rounds[roundId];

        // Protocol fee from the snapshot bps
        uint256 totalPool = r.prizePool;
        uint256 protocolFee = (totalPool * r.protocolFeeBps) / 10_000;
        uint256 distributablePool = totalPool - protocolFee;

        s_accumulatedFees += protocolFee;
        r.protocolFeeCollected = protocolFee;

        // Number of winners (capped at unique player count)
        uint256 numUniquePlayers = r.uniquePlayers.length;
        uint256 numWinners = numUniquePlayers < 3 ? numUniquePlayers : 3;

        address[] memory selected = _selectUniqueWinners(
            r.players,
            randomWords,
            numWinners
        );

        // Payouts based on the number of winners
        uint256[3] memory payouts;
        if (numWinners == 1) {
            payouts[0] = distributablePool;
        } else if (numWinners == 2) {
            payouts[0] = (distributablePool * 6000) / 10_000; // 60%
            payouts[1] = distributablePool - payouts[0]; // 40% (remainder)
        } else {
            payouts[0] = (distributablePool * FIRST_PLACE_BPS) / 10_000; // 50%
            payouts[1] = (distributablePool * SECOND_PLACE_BPS) / 10_000; // 30%
            payouts[2] = distributablePool - payouts[0] - payouts[1]; // 20%
        }

        // Store winners and ASSIGN prizes to the pull-payment ledger.
        // No ETH is sent here on purpose: this callback must never revert because
        // of a winner that rejects ETH, or the round (and its funds) would be
        // stuck in CALCULATING forever. Winners pull their prize via claimPrize().
        for (uint256 i; i < numWinners; ++i) {
            r.winners[i] = selected[i];
            s_prizes[roundId][selected[i]] += payouts[i];
        }
        r.payouts = payouts;
        r.state = RoundState.CLOSED;

        emit ProtocolFeeCollected(roundId, protocolFee);
        emit WinnersSelected(roundId, r.winners, r.payouts);
    }

    // -------------------------------------------------------------------------
    // Internal — Helpers
    // -------------------------------------------------------------------------

    /**
     * @dev Select `numWinners` unique winners from the ticket pool. Each random
     *      word seeds a pick; on collision, re-hash with an incrementing nonce
     *      until a unique player is found. More tickets = more entries = higher odds.
     */
    function _selectUniqueWinners(
        address[] storage tickets,
        uint256[] calldata randomWords,
        uint256 numWinners
    ) internal view returns (address[] memory winners) {
        winners = new address[](numWinners);
        uint256 totalTickets = tickets.length;

        for (uint256 i; i < numWinners; ++i) {
            uint256 seed = randomWords[i];
            address selected;
            uint256 attempts;

            uint256 maxAttempts = totalTickets * 10;
            do {
                uint256 index = uint256(
                    keccak256(abi.encode(seed, attempts))
                ) % totalTickets;
                selected = tickets[index];
                ++attempts;
            } while (
                _isDuplicate(winners, selected, i) && attempts < maxAttempts
            );

            winners[i] = selected;
        }
    }

    /// @dev True if `candidate` already appears in `winners` at [0, currentIdx).
    function _isDuplicate(
        address[] memory winners,
        address candidate,
        uint256 currentIdx
    ) internal pure returns (bool) {
        for (uint256 j; j < currentIdx; ++j) {
            if (winners[j] == candidate) return true;
        }
        return false;
    }

    /// @dev Emit the full config-updated event from the current config.
    function _emitConfigUpdated() private {
        LotteryConfig memory cfg = s_config;
        emit ConfigUpdated(
            cfg.ticketPrice,
            cfg.roundDuration,
            cfg.maxTicketsPerPlayer,
            cfg.minPlayers,
            cfg.protocolFeeBps
        );
    }
}
