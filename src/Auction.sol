// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Pool} from "./Pool.sol";
import {PoolFactory} from "./PoolFactory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract Auction is Initializable, UUPSUpgradeable, PausableUpgradeable {
  using SafeERC20 for IERC20;

  // Pool contract
  address public pool;

  // Auction beneficiary
  address public beneficiary;

  // Auction buy and sell tokens
  address public buyCouponToken;
  address public sellReserveToken;

  // Auction end time and total buy amount
  uint256 public endTime;
  uint256 public totalBuyCouponAmount;
  uint256 public poolSaleLimit;

  enum State {
    BIDDING,
    SUCCEEDED,
    FAILED_UNDERSOLD,
    FAILED_POOL_SALE_LIMIT
  }

  State public state;

  struct Bid {
    address bidder;
    uint256 buyReserveAmount;
    uint256 sellCouponAmount;
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
  uint256 public currentCouponAmount; // Aggregated buy amount (coupon) for the auction
  uint256 public totalSellReserveAmount; // Aggregated sell amount (reserve) for the auction

  event AuctionEnded(State state, uint256 totalSellReserveAmount, uint256 totalBuyCouponAmount);
  event BidRefundClaimed(uint256 bidIndex, address indexed bidder, uint256 sellCouponAmount);
  event BidClaimed(uint256 indexed bidIndex, address indexed bidder, uint256 sellCouponAmount);
  event BidPlaced(uint256 indexed bidIndex, address indexed bidder, uint256 buyReserveAmount, uint256 sellCouponAmount);
  event BidRemoved(uint256 indexed bidIndex, address indexed bidder, uint256 buyReserveAmount, uint256 sellCouponAmount);
  event BidReduced(uint256 indexed bidIndex, address indexed bidder, uint256 buyReserveAmount, uint256 sellCouponAmount);

  error AccessDenied();
  error AuctionFailed();
  error NothingToClaim();
  error AlreadyClaimed();
  error AuctionHasEnded();
  error AuctionNotEnded();
  error BidAmountTooLow();
  error BidAmountTooHigh();
  error InvalidSellAmount();
  error AuctionStillOngoing();
  error AuctionAlreadyEnded();

  uint256 public constant MAX_BID_AMOUNT = 1e50;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the Auction contract.
   * @param _buyCouponToken The address of the buy token (coupon).
   * @param _sellReserveToken The address of the sell token (reserve).
   * @param _totalBuyCouponAmount The total amount of buy tokens (coupon) for the auction.
   * @param _endTime The end time of the auction.
   * @param _maxBids The maximum number of bids allowed in the auction.
   * @param _beneficiary The address of the auction beneficiary.
   * @param _poolSaleLimit The percentage threshold auctions should respect when selling reserves (e.g. 95000 = 95%).
   */
  function initialize(
    address _buyCouponToken, 
    address _sellReserveToken, 
    uint256 _totalBuyCouponAmount, 
    uint256 _endTime, 
    uint256 _maxBids, 
    address _beneficiary, 
    uint256 _poolSaleLimit
  ) initializer public {
    __UUPSUpgradeable_init();

    buyCouponToken = _buyCouponToken; // coupon
    sellReserveToken = _sellReserveToken; // reserve
    totalBuyCouponAmount = _totalBuyCouponAmount; // coupon amount
    endTime = _endTime;
    maxBids = _maxBids;
    pool = msg.sender;
    poolSaleLimit = _poolSaleLimit;

    if (_beneficiary == address(0)) {
      beneficiary = msg.sender;
    } else {
      beneficiary = _beneficiary;
    }
  }

  /**
   * @dev Places a bid on a portion of the pool.
   * @param buyReserveAmount The amount of buy tokens (reserve) to bid.
   * @param sellCouponAmount The amount of sell tokens (coupon) to bid.
   * @return The index of the bid.
   */
  function bid(uint256 buyReserveAmount, uint256 sellCouponAmount) external auctionActive whenNotPaused returns(uint256) {
    if (sellCouponAmount == 0 || sellCouponAmount > totalBuyCouponAmount) revert InvalidSellAmount();
    if (sellCouponAmount % slotSize() != 0) revert InvalidSellAmount();
    if (buyReserveAmount == 0) revert BidAmountTooLow();
    if (buyReserveAmount > MAX_BID_AMOUNT) revert BidAmountTooHigh();

    // Transfer buy tokens to contract
    IERC20(buyCouponToken).safeTransferFrom(msg.sender, address(this), sellCouponAmount);

    Bid memory newBid = Bid({
      bidder: msg.sender,
      buyReserveAmount: buyReserveAmount,
      sellCouponAmount: sellCouponAmount,
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
    currentCouponAmount += sellCouponAmount;
    totalSellReserveAmount += buyReserveAmount;

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

    emit BidPlaced(newBidIndex,msg.sender, buyReserveAmount, sellCouponAmount);

    return newBidIndex;
  }

  /**
   * @dev Inserts the bid into the linked list based on the price (buyAmount/sellAmount) in descending order, then by sellAmount.
   * @param newBidIndex The index of the bid to insert.
   */
  function insertSortedBid(uint256 newBidIndex) internal {
    Bid storage newBid = bids[newBidIndex];
    uint256 newSellCouponAmount = newBid.sellCouponAmount;
    uint256 newBuyReserveAmount = newBid.buyReserveAmount;
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
        uint256 currentSellCouponAmount = currentBid.sellCouponAmount;
        uint256 currentBuyReserveAmount = currentBid.buyReserveAmount;
        uint256 currentNextBidIndex = currentBid.nextBidIndex;

        // Compare prices without division by cross-multiplying (it's more gas efficient)
        leftSide = newSellCouponAmount * currentBuyReserveAmount;
        rightSide = currentSellCouponAmount * newBuyReserveAmount;

        if (leftSide > rightSide || (leftSide == rightSide && newSellCouponAmount > currentSellCouponAmount)) {
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
    uint256 lowestSellCouponAmount = lowestBid.sellCouponAmount;
    uint256 lowestBuyReserveAmount = lowestBid.buyReserveAmount;

    // Compare prices without division by cross-multiplying (it's more gas efficient)
    leftSide = newSellCouponAmount * lowestBuyReserveAmount;
    rightSide = lowestSellCouponAmount * newBuyReserveAmount;

    if (leftSide < rightSide || (leftSide == rightSide && newSellCouponAmount < lowestSellCouponAmount)) {
      lowestBidIndex = newBidIndex;
    }
  }
  
  /**
   * @dev Removes excess bids from the auction.
   */
  function removeExcessBids() internal {
    if (currentCouponAmount <= totalBuyCouponAmount) {
      return;
    }

    uint256 amountToRemove = currentCouponAmount - totalBuyCouponAmount;
    uint256 currentIndex = lowestBidIndex;

    while (currentIndex != 0 && amountToRemove != 0) {
      // Cache the current bid's data into local variables
      Bid storage currentBid = bids[currentIndex];
      uint256 sellCouponAmount = currentBid.sellCouponAmount;
      uint256 prevIndex = currentBid.prevBidIndex;

      if (amountToRemove >= sellCouponAmount) {
        // Subtract the sellAmount from amountToRemove
        amountToRemove -= sellCouponAmount;

        // Remove the bid
        _removeBid(currentIndex);

        // Move to the previous bid (higher price)
        currentIndex = prevIndex;
      } else {
        // Calculate the proportion of sellAmount being removed
        uint256 proportion = (amountToRemove * 1e18) / sellCouponAmount;
        
        // Reduce the current bid's amounts
        currentBid.sellCouponAmount = sellCouponAmount - amountToRemove;
        currentCouponAmount -= amountToRemove;

        uint256 reserveReduction = ((currentBid.buyReserveAmount * proportion) / 1e18);
        currentBid.buyReserveAmount = currentBid.buyReserveAmount - reserveReduction;
        totalSellReserveAmount -= reserveReduction;
        
        // Refund the proportional sellAmount
        IERC20(buyCouponToken).safeTransfer(currentBid.bidder, amountToRemove);
        
        amountToRemove = 0;
        emit BidReduced(currentIndex, currentBid.bidder, currentBid.buyReserveAmount, currentBid.sellCouponAmount);
      }
    }
  }

  /**
   * @dev Removes a bid from the linked list.
   * @param bidIndex The index of the bid to remove.
   */
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
    uint256 buyReserveAmount = bidToRemove.buyReserveAmount;
    uint256 sellCouponAmount = bidToRemove.sellCouponAmount;
    currentCouponAmount -= sellCouponAmount;
    totalSellReserveAmount -= buyReserveAmount;

    // Refund the buy tokens for the removed bid
    IERC20(buyCouponToken).safeTransfer(bidder, sellCouponAmount);

    emit BidRemoved(bidIndex, bidder, buyReserveAmount, sellCouponAmount);

    delete bids[bidIndex];
    bidCount--;
  }

  /**
   * @dev Ends the auction and transfers the reserve to the auction.
   */
  function endAuction() external auctionExpired whenNotPaused {
    if (state != State.BIDDING) revert AuctionAlreadyEnded();

    if (currentCouponAmount < totalBuyCouponAmount) {
      state = State.FAILED_UNDERSOLD;
    } else if (totalSellReserveAmount >= (IERC20(sellReserveToken).balanceOf(pool) * poolSaleLimit) / 100) {
        state = State.FAILED_POOL_SALE_LIMIT;
    } else {
      state = State.SUCCEEDED;
      Pool(pool).transferReserveToAuction(totalSellReserveAmount);
      IERC20(buyCouponToken).safeTransfer(beneficiary, IERC20(buyCouponToken).balanceOf(address(this)));
    }

    emit AuctionEnded(state, totalSellReserveAmount, totalBuyCouponAmount);
  }

  /**
   * @dev Claims the tokens for a winning bid.
   * @param bidIndex The index of the bid to claim.
   */
  function claimBid(uint256 bidIndex) auctionExpired auctionSucceeded whenNotPaused external {
    Bid storage bidInfo = bids[bidIndex];
    if (bidInfo.bidder != msg.sender) revert NothingToClaim();
    if (bidInfo.claimed) revert AlreadyClaimed();

    bidInfo.claimed = true;
    IERC20(sellReserveToken).transfer(bidInfo.bidder, bidInfo.buyReserveAmount);

    emit BidClaimed(bidIndex, bidInfo.bidder, bidInfo.buyReserveAmount);
  }

  function claimRefund(uint256 bidIndex) auctionExpired auctionFailed whenNotPaused external {
    Bid storage bidInfo = bids[bidIndex];
    if (bidInfo.bidder != msg.sender) revert NothingToClaim();
    if (bidInfo.claimed) revert AlreadyClaimed();

    bidInfo.claimed = true;
    IERC20(buyCouponToken).safeTransfer(bidInfo.bidder, bidInfo.sellCouponAmount);

    emit BidRefundClaimed(bidIndex, bidInfo.bidder, bidInfo.sellCouponAmount);
  }

  /**
   * @dev Returns the size of a bid slot.
   * @return uint256 The size of a bid slot.
   */
  function slotSize() internal view returns (uint256) {
    return totalBuyCouponAmount / maxBids;
  }

  /**
   * @dev Modifier to check if the auction is still active.
   */
  modifier auctionActive() {
    if (block.timestamp >= endTime) revert AuctionHasEnded();
    _;
  }

  /**
   * @dev Modifier to check if the auction has expired.
   */
  modifier auctionExpired() {
    if (block.timestamp < endTime) revert AuctionStillOngoing();
    _;
  }

  /**
   * @dev Modifier to check if the auction succeeded.
   */
  modifier auctionSucceeded() {
    if (state != State.SUCCEEDED) revert AuctionFailed();
    _;
  }

  modifier auctionFailed() {
    if (state == State.SUCCEEDED || state == State.BIDDING) revert AuctionFailed();
    _;
  }

  /**
   * @dev Modifier to check if the caller has the specified role.
   * @param role The role to check for.
   */
  modifier onlyRole(bytes32 role) {
    if (!PoolFactory(Pool(pool).poolFactory()).hasRole(role, msg.sender)) {
      revert AccessDenied();
    }
    _;
  }

  function pause() external onlyRole(PoolFactory(Pool(pool).poolFactory()).SECURITY_COUNCIL_ROLE()) {
    _pause();
  }

  function unpause() external onlyRole(PoolFactory(Pool(pool).poolFactory()).SECURITY_COUNCIL_ROLE()) {
    _unpause();
  }

  /**
   * @dev Authorizes an upgrade to a new implementation.
   * Can only be called by the owner of the contract.
   * @param newImplementation Address of the new implementation
   */
  function _authorizeUpgrade(address newImplementation)
    internal
    onlyRole(PoolFactory(Pool(pool).poolFactory()).GOV_ROLE())
    override
  {}
}
