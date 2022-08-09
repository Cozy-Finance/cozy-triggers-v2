// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "src/interfaces/ICostModel.sol";
import "src/interfaces/IDecayModel.sol";
import "src/interfaces/IDripModel.sol";
import "src/interfaces/IERC20.sol";

/**
 * @dev Structs used to define parameters in sets and markets.
 * @dev A "zoc" is a unit with 4 decimal places. All numbers in these config structs are in zocs, i.e. a
 * value of 900 translates to 900/10,000 = 0.09, or 9%.
 */
interface IConfig {
  // Set-level configuration.
  struct SetConfig {
    uint256 leverageFactor; // The set's leverage factor.
    uint256 depositFee; // Fee applied on each deposit and mint.
    IDecayModel decayModel; // Contract defining the decay rate for PTokens in this set.
    IDripModel dripModel; // Contract defining the rate at which funds are dripped to suppliers for their yield.
  }

  // Market-level configuration.
  struct MarketInfo {
    address trigger; // Address of the trigger contract for this market.
    address costModel; // Contract defining the cost model for this market.
    uint16 weight; // Weight of this market. Sum of weights across all markets must sum to 100% (1e4, 1 zoc).
    uint16 purchaseFee; // Fee applied on each purchase.
  }

  // PTokens and are not eligible to claim protection until maturity. It takes `purchaseDelay` seconds for a PToken
  // to mature, but time during an InactivePeriod is not counted towards maturity. Similarly, there is a delay
  // between requesting a withdrawal and completing that withdrawal, and inactive periods do not count towards that
  // withdrawal delay.
  struct InactivePeriod {
    uint64 startTime; // Timestamp that this inactive period began.
    uint64 cumulativeDuration; // Cumulative inactive duration of all prior inactive periods and this inactive period at the point when this inactive period ended.
  }
}
