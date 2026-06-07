// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "./interfaces/IAggregator.sol";

contract Presale is Ownable {
    using SafeERC20 for IERC20;

    address public saleTokenAddress;
    address public daiAddress;
    address public usdcAddress;
    address public fundsWallet;
    address public dataFeedAddress;
    uint256 public totalSupply;
    uint256 public startingTime;
    uint256 public endingTime;
    uint256[][3] public phases;

    uint256 public totalSold;
    uint256 public currentPhase;
    mapping(address => bool) public isBlacklisted;
    mapping(address => uint256) public userBalance;

    event TokensSold(address indexed buyer, uint256 amount);

    constructor(
        address saleTokenAddress_,
        address daiAddress_,
        address usdcAddress_,
        address fundsWallet_,
        address dataFeedAddress_,
        uint256 totalSupply_,
        uint256 startingTime_,
        uint256 endingTime_,
        uint256[][3] memory phases_
    ) Ownable(msg.sender) {
        saleTokenAddress = saleTokenAddress_;
        daiAddress = daiAddress_;
        usdcAddress = usdcAddress_;
        fundsWallet = fundsWallet_;
        dataFeedAddress = dataFeedAddress_;
        totalSupply = totalSupply_;
        startingTime = startingTime_;
        endingTime = endingTime_;
        phases = phases_;

        require(
            endingTime > startingTime,
            "Ending time must be greater than starting time."
        );
        IERC20(saleTokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            totalSupply
        );
    }

    function blacklistAddress(address address_) external onlyOwner {
        isBlacklisted[address_] = true;
    }

    function removeAddressFromBlacklist(address address_) external onlyOwner {
        isBlacklisted[address_] = false;
    }

    function checkCurrentPhase(
        uint256 amount_
    ) private returns (uint256 currentPhase_) {
        if (
            (totalSold + amount_ >= phases[currentPhase][0] ||
                block.timestamp >= phases[currentPhase][2]) && currentPhase < 3
        ) {
            currentPhase++;
            currentPhase_ = currentPhase;
        } else {
            currentPhase_ = currentPhase;
        }
    }

    function buyWithStableCoin(
        address tokenAddress_,
        uint256 amount_
    ) external {
        require(!isBlacklisted[msg.sender], "You are blacklisted.");
        require(
            block.timestamp >= startingTime,
            "Presale has not started yet."
        );
        require(
            block.timestamp <= endingTime,
            "Presale has ended. No more tokens can be sold."
        );
        require(
            tokenAddress_ == daiAddress || tokenAddress_ == usdcAddress,
            "Invalid token address."
        );

        uint256 tokenAmountToReceive;
        if (ERC20(tokenAddress_).decimals() == 18)
            tokenAmountToReceive = (amount_ * 1e6) / phases[currentPhase][1];
        else
            tokenAmountToReceive =
                (amount_ * 10 ** (18 - ERC20(tokenAddress_).decimals()) * 1e6) /
                phases[currentPhase][1];

        checkCurrentPhase(tokenAmountToReceive);

        totalSold += tokenAmountToReceive;
        require(totalSold <= totalSupply, "Presale has sold all the tokens.");

        userBalance[msg.sender] += tokenAmountToReceive;

        IERC20(tokenAddress_).safeTransferFrom(
            msg.sender,
            fundsWallet,
            amount_
        );

        emit TokensSold(msg.sender, tokenAmountToReceive);
    }

    function buyWithEther() external payable {
        require(!isBlacklisted[msg.sender], "You are blacklisted.");
        require(
            block.timestamp >= startingTime,
            "Presale has not started yet."
        );
        require(
            block.timestamp <= endingTime,
            "Presale has ended. No more tokens can be sold."
        );

        uint256 usdValue = (msg.value * getEtherPrice()) / 1e18;
        uint256 tokenAmountToReceive = (usdValue * 1e6) /
            phases[currentPhase][1];

        checkCurrentPhase(tokenAmountToReceive);

        totalSold += tokenAmountToReceive;
        require(totalSold <= totalSupply, "Presale has sold all the tokens.");

        userBalance[msg.sender] += tokenAmountToReceive;

        (bool success, ) = fundsWallet.call{value: msg.value}("");
        require(success, "Transfer failed.");

        emit TokensSold(msg.sender, tokenAmountToReceive);
    }

    function claimTokens() external {
        require(block.timestamp >= endingTime, "Presale has not ended yet.");

        uint256 tokenAmountToReceive = userBalance[msg.sender];
        delete userBalance[msg.sender];

        IERC20(saleTokenAddress).safeTransfer(msg.sender, tokenAmountToReceive);
    }

    function getEtherPrice() public view returns (uint256) {
        (, int256 price, , , ) = IAggregator(dataFeedAddress).latestRoundData();
        return uint256(price * (10 ** 10));
    }

    function emergencyERC20Withdraw(
        address tokenAddress_,
        uint256 amount_
    ) external onlyOwner {
        IERC20(tokenAddress_).safeTransfer(msg.sender, amount_);
    }

    function emergencyETHWithdraw() external onlyOwner {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }
}
