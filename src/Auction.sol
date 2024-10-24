// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Pool} from "./Pool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Auction {
  using SafeERC20 for IERC20;

  // Pool contract
  address public pool;

  // Auction beneficiary
  address public beneficiary;

  // Auction buy and sell tokens
  address public buyToken;
  address public sellToken;

  // Auction end time and total buy amount
  uint256 public endTime;
  uint256 public totalBuyAmount;

  enum State {
    BIDDING,
    SUCCEEDED,
    FAILED
  }

  State public state;

  struct Bid {
    address bidder;
    uint256 buyAmount;
    uint256 sellAmount;
    uint256 nextBidIndex;
    uint256 prevBidIndex;
    bool claimed;
  }

  mapping(uint256 => Bid) public bids; // Mapping to store all bids by their index
  uint256 public bidCount;
  uint256 public lastBidIndex;
  uint256 public highestBidIndex; // The index of the highest bid in the sorted list
  uint256 public maxBids;
  uint256 public lowestBidIndex; // New variable to track the lowest bid
  uint256 public totalBidsAmount; // Aggregated buy amount (coupon) for the auction
  uint256 public totalSellAmount; // Aggregated sell amount (reserve) for the auction

  event AuctionEnded(State state, uint256 totalSellAmount, uint256 totalBuyAmount);
  event BidClaimed(address indexed bidder, uint256 sellAmount);
  event BidPlaced(address indexed bidder, uint256 buyAmount, uint256 sellAmount);
  event BidRemoved(address indexed bidder, uint256 buyAmount, uint256 sellAmount);

  error AuctionFailed();
  error NothingToClaim();
  error AlreadyClaimed();
  error AuctionHasEnded();
  error AuctionNotEnded();
  error BidAmountTooLow();
  error InvalidSellAmount();
  error AuctionStillOngoing();
  error AuctionAlreadyEnded();

  constructor(address _buyToken, address _sellToken, uint256 _totalBuyAmount, uint256 _endTime, uint256 _maxBids, address _beneficiary) {
    buyToken = _buyToken; // coupon
    sellToken = _sellToken; // reserve
    totalBuyAmount = _totalBuyAmount; // coupon amount
    endTime = _endTime;
    maxBids = _maxBids;
    pool = msg.sender;

    if (_beneficiary == address(0)) {
      beneficiary = msg.sender;
    } else {
      beneficiary = _beneficiary;
    }
  }

  // Function to place bids on a portion of the pool
  // buyAmount = reserve (bidder perspective)
  // sellAmount = coupon (bidder perspective)
  function bid(uint256 buyAmount, uint256 sellAmount) external auctionActive returns(uint256) {
    if (sellAmount == 0 || sellAmount > totalBuyAmount) revert InvalidSellAmount();
    if (sellAmount % slotSize() != 0) revert InvalidSellAmount();
    if (buyAmount == 0) revert BidAmountTooLow();

    // Transfer buy tokens to contract
    IERC20(buyToken).transferFrom(msg.sender, address(this), buyAmount);

    Bid memory newBid = Bid({
      bidder: msg.sender,
      buyAmount: buyAmount,
      sellAmount: sellAmount,
      nextBidIndex: 0, // Default to 0, which indicates the end of the list
      prevBidIndex: 0, // Default to 0, which indicates the start of the list
      claimed: false
    });

    lastBidIndex++; // Avoids 0 index
    uint256 newBidIndex = lastBidIndex;
    bids[newBidIndex] = newBid;
    bidCount++;

    // Insert the new bid into the sorted linked list
    insertSortedBid(newBidIndex);
    totalBidsAmount += sellAmount;
    totalSellAmount += buyAmount;

    if (bidCount > maxBids) {
      if (lowestBidIndex == newBidIndex) {
        revert BidAmountTooLow();
      }
      _removeBid(lowestBidIndex);
    }

    // Remove and refund out of range bids
    removeExcessBids();

    // Check if the new bid is still on the map after removeBids
    if (bids[newBidIndex].bidder == address(0)) {
      revert BidAmountTooLow();
    }

    emit BidPlaced(msg.sender, buyAmount, sellAmount);

    return newBidIndex;
  }

  // Inserts the bid into the linked list based on the price (buyAmount/sellAmount) in descending order, then by sellAmount
  function insertSortedBid(uint256 newBidIndex) internal {
    Bid storage newBid = bids[newBidIndex];
    uint256 newSellAmount = newBid.sellAmount;
    uint256 newBuyAmount = newBid.buyAmount;
    uint256 leftSide;
    uint256 rightSide;

    if (highestBidIndex == 0) {
      // First bid being inserted
      highestBidIndex = newBidIndex;
      lowestBidIndex = newBidIndex;
    } else {
      uint256 currentBidIndex = highestBidIndex;
      uint256 previousBidIndex = 0;

      // Traverse the linked list to find the correct spot for the new bid
      while (currentBidIndex != 0) {
        // Cache the current bid's data into local variables
        Bid storage currentBid = bids[currentBidIndex];
        uint256 currentSellAmount = currentBid.sellAmount;
        uint256 currentBuyAmount = currentBid.buyAmount;
        uint256 currentNextBidIndex = currentBid.nextBidIndex;

        // Compare without division by cross-multiplying (it's more gas efficient)
        leftSide = newSellAmount * currentBuyAmount;
        rightSide = currentSellAmount * newBuyAmount;

        if (leftSide > rightSide || (leftSide == rightSide && newSellAmount > currentSellAmount)) {
          break;
        }
        
        previousBidIndex = currentBidIndex;
        currentBidIndex = currentNextBidIndex;
      }

      if (previousBidIndex == 0) {
        // New bid is the highest bid
        newBid.nextBidIndex = highestBidIndex;
        bids[highestBidIndex].prevBidIndex = newBidIndex;
        highestBidIndex = newBidIndex;
      } else {
        // Insert bid in the middle or at the end
        newBid.nextBidIndex = currentBidIndex;
        newBid.prevBidIndex = previousBidIndex;
        bids[previousBidIndex].nextBidIndex = newBidIndex;
        if (currentBidIndex != 0) {
          bids[currentBidIndex].prevBidIndex = newBidIndex;
        }
      }

      // If the new bid is inserted at the end, update the lowest bid index
      if (currentBidIndex == 0) {
        lowestBidIndex = newBidIndex;
      }
    }

    // Cache the lowest bid's data into local variables
    Bid storage lowestBid = bids[lowestBidIndex];
    uint256 lowestSellAmount = lowestBid.sellAmount;
    uint256 lowestBuyAmount = lowestBid.buyAmount;

    // Compare without division by cross-multiplying (it's more gas efficient)
    leftSide = newSellAmount * lowestBuyAmount;
    rightSide = lowestSellAmount * newBuyAmount;

    if (leftSide < rightSide || (leftSide == rightSide && newSellAmount < lowestSellAmount)) {
      lowestBidIndex = newBidIndex;
    }
  }
  
  function removeExcessBids() internal {
    if (totalBidsAmount <= totalBuyAmount) {
      return;
    }

    uint256 amountToRemove = totalBidsAmount - totalBuyAmount;
    uint256 currentIndex = lowestBidIndex;

    while (currentIndex != 0 && amountToRemove != 0) {
      // Cache the current bid's data into local variables
      Bid storage currentBid = bids[currentIndex];
      uint256 sellAmount = currentBid.sellAmount;
      uint256 prevIndex = currentBid.prevBidIndex;

      if (amountToRemove >= sellAmount) {
        // Subtract the sellAmount from amountToRemove
        amountToRemove -= sellAmount;

        // Remove the bid
        _removeBid(currentIndex);

        // Move to the previous bid (higher price)
        currentIndex = prevIndex;
      } else {
        // Reduce the current bid's sellAmount
        currentBid.sellAmount = sellAmount - amountToRemove;
        amountToRemove = 0;
      }
    }
  }

  function _removeBid(uint256 bidIndex) internal {
    Bid storage bidToRemove = bids[bidIndex];
    uint256 nextIndex = bidToRemove.nextBidIndex;
    uint256 prevIndex = bidToRemove.prevBidIndex;

    // Update linked list pointers
    if (prevIndex == 0) {
      // Removing the highest bid
      highestBidIndex = nextIndex;
    } else {
      bids[prevIndex].nextBidIndex = nextIndex;
    }

    if (nextIndex == 0) {
      // Removing the lowest bid
      lowestBidIndex = prevIndex;
    } else {
      bids[nextIndex].prevBidIndex = prevIndex;
    }

    address bidder = bidToRemove.bidder;
    uint256 buyAmount = bidToRemove.buyAmount;
    uint256 sellAmount = bidToRemove.sellAmount;
    totalBidsAmount -= sellAmount;
    totalSellAmount -= buyAmount;

    // Refund the buy tokens for the removed bid
    IERC20(buyToken).transfer(bidder, buyAmount);

    emit BidRemoved(bidder, buyAmount, sellAmount);

    delete bids[bidIndex];
    bidCount--;
  }

  // End auction
  function endAuction() external auctionExpired {
    if (state != State.BIDDING) revert AuctionAlreadyEnded();
    
    if (totalBidsAmount < totalBuyAmount) {
      state = State.FAILED;
    } else {
      state = State.SUCCEEDED;
      Pool(pool).transferReserveToAuction(totalSellAmount);
      IERC20(buyToken).safeTransfer(beneficiary, IERC20(buyToken).balanceOf(address(this)));
    }

    emit AuctionEnded(state, totalSellAmount, totalBuyAmount);
  }

  // Claim tokens for a winning bid
  function claimBid(uint256 bidIndex) auctionExpired auctionSucceeded external {
    Bid storage bidInfo = bids[bidIndex];
    if (bidInfo.bidder != msg.sender) revert NothingToClaim();
    if (bidInfo.claimed) revert AlreadyClaimed();

    bidInfo.claimed = true;
    IERC20(sellToken).transfer(bidInfo.bidder, bidInfo.sellAmount);

    emit BidClaimed(bidInfo.bidder, bidInfo.sellAmount);
  }

  function slotSize() internal view returns (uint256) {
    return totalBuyAmount / maxBids;
  }

  modifier auctionActive() {
    if (block.timestamp >= endTime) revert AuctionHasEnded();
    _;
  }

  modifier auctionExpired() {
    if (block.timestamp < endTime) revert AuctionStillOngoing();
    _;
  }

  modifier auctionSucceeded() {
    if (state != State.SUCCEEDED) revert AuctionFailed();
    _;
  }
}
