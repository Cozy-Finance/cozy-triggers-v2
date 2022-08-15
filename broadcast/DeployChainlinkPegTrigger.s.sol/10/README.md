# Deploys

This file contains a list of live deployments.
These are also stored in this folder under e.g. `broadcast/DeployChainlinkPegTrigger.s.sol/10/run-latest.json`, but documenting them here as well is more user-friendly.
Deploys are sorted by timestamp, with the most recent one first.

## Optimism

### Triggers

- ChainlinkTrigger deployed 0x5b0E6cD94854558aa2E0b0bc7aDD36b2147bFC13
  - ChainlinkTriggerFactory 0x1eB3f4a379e7BfAf57331FC9BCb5b4763122E48B
  - pegPrice 100000000
  - decimals 8
  - trackingOracle 0x82f6491eF3bb1467C1cb283cDC7Df18B2B9b968E (MockChainlinkOracle)
  - priceTolerance 5000
  - frequencyTolerance 43200