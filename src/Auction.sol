// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Auction {

  // Auction beneficiary
  address public beneficiary;

  // Auction buy and sell tokens
  address public buyToken;
  address public sellToken;

  // Auction end time and total sell amount
  uint256 public endTime;
  uint256 public totalBuyAmount;
  bool public auctionEnded;

  struct Bid {
    address bidder;
    uint256 buyAmount;
    uint256 sellAmount;
    uint256 nextBidIndex;
    bool claimed;
  }

  mapping(uint256 => Bid) public bids; // Mapping to store all bids by their index
  uint256 public bidCount;
  uint256 public highestBidIndex; // The index of the highest bid in the sorted list
  uint256 private maxBids;
  uint256 private lowestBidIndex; // New variable to track the lowest bid
  uint256 private totalBidsAmount; // Aggregated buy amount (coupon) for the auction

  event AuctionEnded();
  event BidClaimed(address indexed bidder, uint256 sellAmount);
  event BidPlaced(address indexed bidder, uint256 buyAmount, uint256 sellAmount);
  event BidRemoved(address indexed bidder, uint256 buyAmount, uint256 sellAmount);

  error AuctionHasEnded();
  error AuctionStillOngoing();
  error InvalidSellAmount();
  error BidAmountTooLow();
  error AuctionAlreadyEnded();
  error AuctionNotEnded();
  error NothingToClaim();
  error AlreadyClaimed();

  constructor(address _buyToken, address _sellToken, uint256 _totalBuyAmount, uint256 _endTime, uint256 _maxBids, address _beneficiary) {
    buyToken = _buyToken; // coupon
    sellToken = _sellToken; // reserve
    totalBuyAmount = _totalBuyAmount; // coupon amount
    endTime = _endTime;
    maxBids = _maxBids;

    if (_beneficiary == address(0)) {
      beneficiary = msg.sender;
    } else {
      beneficiary = _beneficiary;
    }
  }

  modifier auctionActive() {
    if (block.timestamp >= endTime) revert AuctionHasEnded();
    _;
  }

  modifier auctionExpired() {
    if (block.timestamp < endTime) revert AuctionStillOngoing();
    _;
  }

  // Function to place bids on a portion of the pool
  // buyAmount = reserve (bidder perspective)
  // sellAmount = coupon (bidder perspective)
  function bid(uint256 buyAmount, uint256 sellAmount) external auctionActive {
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
      claimed: false
    });

    uint256 newBidIndex = bidCount;
    bids[newBidIndex] = newBid;
    bidCount++;

    // Insert the new bid into the sorted linked list
    insertSortedBid(newBidIndex);

    // Check if we've exceeded maxBids and remove the lowest bid if necessary
    if (bidCount > maxBids) {
      removeLowestBid();
    }

    // @todo: Was it actually placed? It could have been removed

    totalBidsAmount += sellAmount;
    
    emit BidPlaced(msg.sender, buyAmount, sellAmount);
  }

  // Inserts the bid into the linked list based on the price (buyAmount/sellAmount) in descending order, then by sellAmount
  function insertSortedBid(uint256 newBidIndex) internal {
    uint256 newPrice = bids[newBidIndex].buyAmount / bids[newBidIndex].sellAmount;

    if (highestBidIndex == 0) {
      // First bid being inserted
      highestBidIndex = newBidIndex;
      lowestBidIndex = newBidIndex;
    } else {
      uint256 currentBidIndex = highestBidIndex;
      uint256 previousBidIndex = 0;
      uint256 currentPrice = 0;

      // Traverse the linked list to find the correct spot for the new bid
      while (currentBidIndex != 0) {
        currentPrice = bids[currentBidIndex].buyAmount / bids[currentBidIndex].sellAmount;

        if (newPrice > currentPrice || (newPrice == currentPrice && bids[newBidIndex].sellAmount > bids[currentBidIndex].sellAmount)) {
          break;
        }
        
        previousBidIndex = currentBidIndex;
        currentBidIndex = bids[currentBidIndex].nextBidIndex;
      }

      if (previousBidIndex == 0) {
        // New bid is the highest bid
        bids[newBidIndex].nextBidIndex = highestBidIndex;
        highestBidIndex = newBidIndex;
      } else {
        // Insert bid in the middle or at the end
        bids[newBidIndex].nextBidIndex = currentBidIndex;
        bids[previousBidIndex].nextBidIndex = newBidIndex;
      }

      // If the new bid is inserted at the end, update the lowest bid index
      if (currentBidIndex == 0) {
        lowestBidIndex = newBidIndex;
      }
    }

    // Update the lowest bid index if the new bid has a lower price or equal price but lower sellAmount
    uint256 lowestPrice = bids[lowestBidIndex].buyAmount / bids[lowestBidIndex].sellAmount;
    if (newPrice < lowestPrice || (newPrice == lowestPrice && bids[newBidIndex].sellAmount < bids[lowestBidIndex].sellAmount)) {
      lowestBidIndex = newBidIndex;
    }
  }

  // Remove the lowest bid when maxBids is exceeded
  function removeLowestBid() internal {
    require(bidCount > 1, "Cannot remove the only bid");

    Bid storage lowestBid = bids[lowestBidIndex];
    uint256 previousBidIndex = highestBidIndex;

    // Find the bid that points to the lowest bid
    while (bids[previousBidIndex].nextBidIndex != lowestBidIndex) {
      previousBidIndex = bids[previousBidIndex].nextBidIndex;
    }

    // Update the next pointer of the previous bid
    bids[previousBidIndex].nextBidIndex = 0;
    
    // Refund the buy tokens to the bidder
    IERC20(buyToken).transfer(lowestBid.bidder, lowestBid.buyAmount);

    totalBidsAmount -= lowestBid.sellAmount;

    // Emit an event for the removed bid
    emit BidRemoved(lowestBid.bidder, lowestBid.buyAmount, lowestBid.sellAmount);

    // Update the lowest bid index
    lowestBidIndex = previousBidIndex;

    // Remove the bid from storage
    delete bids[lowestBidIndex];
    bidCount--;
  }

  // End auction
  function endAuction() external auctionExpired {
    if (auctionEnded) revert AuctionAlreadyEnded();
    auctionEnded = true;
    emit AuctionEnded();
  }

  // Claim tokens for a winning bid
  function claimBid(uint256 bidIndex) external {
    if (!auctionEnded) revert AuctionNotEnded();
    Bid storage bidInfo = bids[bidIndex];
    if (bidInfo.bidder != msg.sender) revert NothingToClaim();
    if (bidInfo.claimed) revert AlreadyClaimed();

    bidInfo.claimed = true;
    IERC20(sellToken).transfer(bidInfo.bidder, bidInfo.sellAmount);

    emit BidClaimed(bidInfo.bidder, bidInfo.sellAmount);
  }

  // Allow the beneficiary to withdraw buy token after auction ends
  function withdraw() external auctionExpired {
    uint256 balance = IERC20(buyToken).balanceOf(address(this));
    IERC20(buyToken).transfer(beneficiary, balance);
  }

  function slotSize() internal view returns (uint256) {
    return totalBuyAmount / maxBids;
  }
}
