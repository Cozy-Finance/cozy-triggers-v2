// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.15;

interface IChainlinkTriggerFactoryEvents {
  /// @dev Emitted when the factory deploys a trigger.
  /// @param trigger Address at which the trigger was deployed.
  /// @param triggerConfigId Unique identifier of the trigger based on its configuration.
  /// @param truthOracle The address of the desired truthOracle for the trigger.
  /// @param trackingOracle The address of the desired trackingOracle for the trigger.
  /// @param priceTolerance The priceTolerance that the deployed trigger will have. See
  /// `ChainlinkTrigger.priceTolerance()` for more information.
  /// @param frequencyTolerance The frequencyTolerance that the deployed trigger will have. See
  /// `ChainlinkTrigger.frequencyTolerance()` for more information.
  event TriggerDeployed(
    address trigger,
    bytes32 indexed triggerConfigId,
    address indexed truthOracle,
    address indexed trackingOracle,
    uint256 priceTolerance,
    uint256 frequencyTolerance
  );
}
