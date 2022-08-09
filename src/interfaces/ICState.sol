// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

/**
 * @dev Contains the enum used to define valid Cozy states.
 * @dev All states except TRIGGERED are valid for sets, and all states except PAUSED are valid for markets/triggers.
 */
interface ICState {
  // The set of all Cozy states.
  enum CState {
    ACTIVE,
    FROZEN,
    PAUSED,
    TRIGGERED
  }
}
