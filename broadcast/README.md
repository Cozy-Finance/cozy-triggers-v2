# Deploys

This file contains a list of live deployments.
These are also stored in this folder under e.g. `broadcast/DeployChainlinkPegTrigger.s.sol/10/run-latest.json`, but documenting them here as well is more user-friendly.
Deploys are sorted by timestamp, with the most recent one first.

## Optimism

### Trigger Factories

**Metadata:**

- Timestamp: 1660588222
- Parsed timestamp: 2022-08-15T18:30:22.000Z

**Configuration:**

- manager 0x1f513585D8bB1F994b37F2aaAB3F8499E52ca534
- umaOracleFinder 0x278d6b1aA37d09769E519f05FcC5923161A8536D

**Deployments:**

- ChainlinkTriggerFactory deployed 0x1eB3f4a379e7BfAf57331FC9BCb5b4763122E48B
- UMATriggerFactory deployed 0xa48666D91Ac494A3CCA96A3A4357d998d8619387

### Chainlink Triggers

#### Trigger 1

ChainlinkTrigger deployed 0xA067443b7f4A00e2c582f1e6aDf3F3a090C568AE

**Metadata:**

- Timestamp: 1660589980
- Parsed timestamp: 2022-08-15T18:59:40.000Z

**Configuration:**

- chainlinkTriggerFactory 0x1eB3f4a379e7BfAf57331FC9BCb5b4763122E48B
- truthOracle 0x13e3Ee699D1909E989722E753853AE30b17e08c5 (ETH / USD)
- trackingOracle 0x41878779a388585509657CE5Fb95a80050502186 (stETH / USD)
- priceTolerance 5000
- truthFrequencyTolerance 1201
- trackingFrequencyTolerance 86401

### Chainlink Peg Triggers

#### Trigger 1

ChainlinkTrigger deployed 0x5b0E6cD94854558aa2E0b0bc7aDD36b2147bFC13

**Metadata:**

- Timestamp: 1660588843
- Parsed timestamp: 2022-08-15T18:40:43.000Z

**Configuration:**

- chainlinkTriggerFactory 0x1eB3f4a379e7BfAf57331FC9BCb5b4763122E48B
- pegPrice 100000000
- decimals 8
- trackingOracle 0x82f6491eF3bb1467C1cb283cDC7Df18B2B9b968E (MockChainlinkOracle)
- priceTolerance 5000
- frequencyTolerance 43200

### UMA Triggers

#### Trigger 5

UMATrigger deployed 0xC6f31FFC09920121D818C9701f9EFBA573FC2ea0

**Metadata:**

- Timestamp: 1660591768
- Parsed timestamp: 2022-08-15T19:29:28.000Z

**Configuration:**

- umaTriggerFactory 0xa48666D91Ac494A3CCA96A3A4357d998d8619387
- query q: title: Hop Protocol, description: Was there a hack, bug, user error, or malfeasance resulting in a loss or lock-up of tokens in the Hop protocol on Ethereum Mainnet at any point after Ethereum Mainnet block number 114400? This will revert if a 'no' answer is proposed.
- rewardToken 0x7F5c764cBc14f9669B88837ca1490cCa17c31607
- rewardAmount 5000000
- bondAmount 5000000
- proposalDisputeWindow 3600

#### Trigger 4

UMATrigger deployed 0xe3a175D9B2D6A13CE8e5Ce1261C14Be3cAeC4a49

**Metadata:**

- Timestamp: 1660591704
- Parsed timestamp: 2022-08-15T19:28:24.000Z

**Configuration:**

- umaTriggerFactory 0xa48666D91Ac494A3CCA96A3A4357d998d8619387
- query q: title: Curve Finance 3pool, description: Was there a hack, bug, user error, or malfeasance resulting in a loss or lock-up of tokens in the Curve Finance 3pool on Ethereum Mainnet at any point after Ethereum Mainnet block number 114400? This will revert if a 'no' answer is proposed.
- rewardToken 0x7F5c764cBc14f9669B88837ca1490cCa17c31607
- rewardAmount 5000000
- bondAmount 5000000
- proposalDisputeWindow 3600

#### Trigger 3

UMATrigger deployed 0x90c73D486cd6Df7040Dc67C7f2EBae3DC85CD8ab

**Metadata:**

- Timestamp: 1660591658
- Parsed timestamp: 2022-08-15T19:27:38.000Z

**Configuration:**

- umaTriggerFactory 0xa48666D91Ac494A3CCA96A3A4357d998d8619387
- query q: title: Aave v3, description: Was there a hack, bug, user error, or malfeasance resulting in a loss or lock-up of tokens in Aave v3 on Ethereum Mainnet at any point after Ethereum Mainnet block number 114400? This will revert if a 'no' answer is proposed.
- rewardToken 0x7F5c764cBc14f9669B88837ca1490cCa17c31607
- rewardAmount 5000000
- bondAmount 5000000
- proposalDisputeWindow 3600

#### Trigger 2

UMATrigger deployed 0xfD64d826E52579C04Ee03a1c88f4888530D57aE4

**Metadata:**

- Timestamp: 1660591273
- Parsed timestamp: 2022-08-15T19:21:13.000Z

**Configuration:**

- umaTriggerFactory 0xa48666D91Ac494A3CCA96A3A4357d998d8619387
- query q: title: Uniswap v3, description: Was there a hack, bug, user error, or malfeasance resulting in a loss or lock-up of tokens in Uniswap v3 on Ethereum Mainnet at any point after Ethereum Mainnet block number 114400? This will revert if a 'no' answer is proposed.
- rewardToken 0x7F5c764cBc14f9669B88837ca1490cCa17c31607
- rewardAmount 5000000
- bondAmount 5000000
- proposalDisputeWindow 3600

#### Trigger 1

UMATrigger deployed 0x2925Da6bbD499D4882A8fD8d3990C753191CD583

**Metadata:**

- Timestamp: 1660590939
- Parsed timestamp: 2022-08-15T19:15:39.000Z

**Configuration:**

- umaTriggerFactory 0xa48666D91Ac494A3CCA96A3A4357d998d8619387
- query q: title: Mock UMA Trigger, description: Is the current date after August 17, 2022 in New York City, USA? 'No' answers are not accepted.
- rewardToken 0x7F5c764cBc14f9669B88837ca1490cCa17c31607
- rewardAmount 5000000
- bondAmount 5000000
- proposalDisputeWindow 3600