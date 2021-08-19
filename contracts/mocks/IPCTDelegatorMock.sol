//SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.5;

import "../governor/IPCTDelegator.sol";

contract IPCTDelegatorMock is IPCTDelegator {
    constructor(
        address timelock_,
        address token_,
        address releaseToken_,
        address admin_,
        address implementation_,
        uint256 votingPeriod_,
        uint256 votingDelay_,
        uint256 proposalThreshold_,
        uint256 quorumVotes_
    )
        IPCTDelegator(
            timelock_,
            token_,
            releaseToken_,
            admin_,
            implementation_,
            votingPeriod_,
            votingDelay_,
            proposalThreshold_,
            quorumVotes_
        )
    {}
}
