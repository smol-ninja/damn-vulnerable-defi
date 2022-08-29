// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "./FreeRiderNFTMarketplace.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IWETH9 {
    function deposit() external payable;
    function withdraw(uint wad) external;
    function transfer(address dst, uint wad) external returns (bool);
    function balanceOf(address) external returns (uint);
}


contract UniswapFlashLoanCallback is IERC721Receiver {

    using Address for address payable;
    using SafeMath for uint256;

    address private immutable owner;
    FreeRiderNFTMarketplace private immutable nftMarketplace;
    IWETH9 private immutable weth; 
    IUniswapV2Factory private immutable uniswapFactoryV2;
    address private immutable nftAddress;

    constructor(
        address _nftMarketplaceAddress, 
        address _wethAddress, 
        address uniswapFactoryAddress,
        address _nftAddress
    )
        payable
    {
        owner = msg.sender;
        nftMarketplace = FreeRiderNFTMarketplace(payable(_nftMarketplaceAddress));
        weth = IWETH9(_wethAddress);
        uniswapFactoryV2 = IUniswapV2Factory(uniswapFactoryAddress);
        nftAddress = _nftAddress;
    }

    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external {
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();
        assert(msg.sender == IUniswapV2Factory(uniswapFactoryV2).getPair(token0, token1));

        require(sender == owner, "non-owner called flashswap");
        require(data.length > 1, "invalid data");

        require(weth.balanceOf(address(this)) > 0, "zero weth balance");

        weth.withdraw(amount0);

        uint256[] memory tokenIds = new uint256[](6);
        for (uint8 i = 0; i < tokenIds.length; i++) {
            tokenIds[i] = i;
        }

        IERC721(nftAddress).setApprovalForAll(address(nftMarketplace), true);
        nftMarketplace.buyMany{value: amount0}(tokenIds);

        uint repayAmount = amount0.add((amount0.mul(3).div(997)).add(1));
        weth.deposit{value: repayAmount}();
        bool status = weth.transfer(msg.sender, repayAmount);
        require(status == true, "Flash repay failed");
    }


    function sendNftToBuyer(uint256[] calldata tokenIds, address partner) public {
        for (uint8 i = 0; i < tokenIds.length; i++) {
            IERC721(nftAddress).safeTransferFrom(address(this), partner, i);
        }
    }

    function destroy() public {
        selfdestruct(payable(owner));
    }

    receive() external payable {}

    function onERC721Received(
        address,
        address,
        uint256 _tokenId,
        bytes memory
    )
        external
        override
        pure
        returns (bytes4) 
    {
        return IERC721Receiver.onERC721Received.selector;
    }
}