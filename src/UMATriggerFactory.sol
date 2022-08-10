// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.15;

import "uma-protocol/packages/core/contracts/oracle/interfaces/FinderInterface.sol";
import "src/UMATrigger.sol";

/**
 * @notice This is a utility contract to make it easy to deploy UMATriggers for
 * the Cozy protocol.
 * @dev Be sure to computeTriggerAddress and approve the computed address to
 * spend the rewardAmount before calling deployTrigger, otherwise the latter will
 * revert. Funds need to be available to the created trigger within its
 * constructor so that it can submit its query to the UMA oracle.
 */
contract UMATriggerFactory {
  /// @notice The manager of the Cozy protocol.
  IManager public immutable manager;

  /// @notice The UMA contract used to lookup the UMA Optimistic Oracle.
  FinderInterface public immutable oracleFinder;

  /// @notice Maps the triggerConfigId to the number of triggers created with those configs.
  mapping(bytes32 => uint256) public triggerCount;

  /// @dev Emitted when the factory deploys a trigger.
  /// The `trigger` is the address at which the trigger was deployed.
  /// For `triggerConfigId`, see the function of the same name in this contract.
  /// For other attributes, see the docs for the params of `deployTrigger` in
  /// this contract.
  event TriggerDeployed(
    address trigger,
    bytes32 indexed triggerConfigId,
    address indexed umaOracleFinder,
    string query,
    address indexed rewardToken,
    uint256 rewardAmount,
    uint256 bondAmount,
    uint256 proposalDisputeWindow
  );

  constructor(IManager _manager, FinderInterface _oracleFinder) {
    manager = _manager;
    oracleFinder = _oracleFinder;
  }

  /// @notice Call this function to deploy a UMATrigger.
  /// @param _query The query that the trigger will send to the UMA Optimistic
  /// Oracle for evaluation.
  /// @param _rewardToken The token used to pay the reward to users that propose
  /// answers to the query.
  /// @param _rewardFunder The address that will be supplying funds for the reward.
  /// @param _rewardAmount The amount of rewardToken that will be paid to users
  /// who propose an answer to the query.
  /// @param _bondAmount The amount of `rewardToken` that must be staked by a
  /// user wanting to propose or dispute an answer to the query. See UMA's price
  /// dispute workflow for more information. It's recommended that the bond
  /// amount be a significant value to deter addresses from proposing malicious,
  /// false, or otherwise self-interested answers to the query.
  /// @param _proposalDisputeWindow The window of time in seconds within which a
  /// proposed answer may be disputed. See UMA's "customLiveness" setting for
  /// more information. It's recommended that the dispute window be fairly long
  /// (12-24 hours), given the difficulty of assessing expected queries (e.g.
  /// "Was protocol ABCD hacked") and the amount of funds potentially at stake.
  function deployTrigger(
    string memory _query,
    IERC20 _rewardToken,
    address _rewardFunder,
    uint256 _rewardAmount,
    uint256 _bondAmount,
    uint256 _proposalDisputeWindow
  ) external returns(UMATrigger _trigger) {
    bytes32 _configId = triggerConfigId(
      _query,
      _rewardToken,
      _rewardAmount,
      _bondAmount,
      _proposalDisputeWindow
    );

    uint256 _triggerCount = triggerCount[_configId]++;
    bytes32 _salt = keccak256(abi.encode(_triggerCount, block.chainid));

    _trigger = new UMATrigger{salt: _salt}(
      manager,
      oracleFinder,
      _query,
      _rewardToken,
      _rewardFunder,
      _rewardAmount,
      _bondAmount,
      _proposalDisputeWindow
    );

    emit TriggerDeployed(
      address(_trigger),
      _configId,
      address(oracleFinder),
      _query,
      address(_rewardToken),
      _rewardAmount,
      _bondAmount,
      _proposalDisputeWindow
    );
  }

  /// @notice Call this function to determine the address at which a trigger
  /// with the supplied configuration would be deployed. See `deployTrigger` for
  /// more information on parameters and their meaning.
  function computeTriggerAddress(
    string memory _query,
    IERC20 _rewardToken,
    address _rewardFunder,
    uint256 _rewardAmount,
    uint256 _bondAmount,
    uint256 _proposalDisputeWindow,
    uint256 _triggerCount
  ) public view returns(address _address) {
    bytes memory _triggerConstructorArgs = abi.encode(
      manager,
      oracleFinder,
      _query,
      _rewardToken,
      _rewardFunder,
      _rewardAmount,
      _bondAmount,
      _proposalDisputeWindow
    );

    // https://eips.ethereum.org/EIPS/eip-1014
    bytes32 _bytecodeHash = keccak256(
      bytes.concat(
        type(UMATrigger).creationCode,
        _triggerConstructorArgs
      )
    );
    bytes32 _salt = keccak256(abi.encode(_triggerCount, block.chainid));
    bytes32 _data = keccak256(bytes.concat(bytes1(0xff), bytes20(address(this)), _salt, _bytecodeHash));
    _address = address(uint160(uint256(_data)));
  }

  /// @notice Call this function to find triggers with the specified
  /// configurations that can be used for new markets in Sets. See
  /// `deployTrigger` for more information on parameters and their meaning.
  function findAvailableTrigger(
    string memory _query,
    IERC20 _rewardToken,
    address _rewardFunder,
    uint256 _rewardAmount,
    uint256 _bondAmount,
    uint256 _proposalDisputeWindow
  ) public view returns(address) {

    bytes32 _counterId = triggerConfigId(
      _query,
      _rewardToken,
      _rewardAmount,
      _bondAmount,
      _proposalDisputeWindow
    );
    uint256 _triggerCount = triggerCount[_counterId];

    for (uint i = 0; i < _triggerCount; i++) {
      address _computedAddr = computeTriggerAddress(
        _query,
        _rewardToken,
        _rewardFunder,
        _rewardAmount,
        _bondAmount,
        _proposalDisputeWindow,
        i
      );

      UMATrigger _trigger = UMATrigger(_computedAddr);
      if (_trigger.getSetsLength() < _trigger.MAX_SET_LENGTH()) {
        return _computedAddr;
      }
    }

    return address(0); // If none is found, return zero address.
  }

  /// @notice Call this function to determine the identifier of the supplied
  /// trigger configuration. This identifier is used both to track the number of
  /// triggers deployed with this configuration (see `triggerCount`) and is
  /// emitted at the time triggers with that configuration are deployed.
  function triggerConfigId(
    string memory _query,
    IERC20 _rewardToken,
    uint256 _rewardAmount,
    uint256 _bondAmount,
    uint256 _proposalDisputeWindow
  ) public view returns (bytes32) {
    bytes memory _triggerConstructorArgs = abi.encode(
      manager,
      oracleFinder,
      _query,
      _rewardToken,
      _rewardAmount,
      _bondAmount,
      _proposalDisputeWindow
    );
    return keccak256(_triggerConstructorArgs);
  }
}
