// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;
pragma abicoder v2;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721Receiver.sol";
import "https://github.com/Uniswap/v3-periphery/blob/main/contracts/libraries/TransferHelper.sol";
import "https://github.com/Uniswap/v3-periphery/blob/main/contracts/interfaces/INonfungiblePositionManager.sol";

contract UniV3Exit is IERC721Receiver {

    struct Depositor {
        address payable owner;
        address token0;
        address token1;
        uint128 liquidity;
    }

    address public manager;
    mapping(uint256 => Depositor) vault;
    INonfungiblePositionManager public immutable uniswapPositionManager;
    TransferHelper public immutable transferHelper;

    event NFTDepositComplete(address owner, uint256 tokenId, uint128 liquidity);
    event NFTWithdrawalComplete(address owner, uint256 tokenId, uint128 liquidity);
    event PositionRemoved(address owner, uint256 tokenId, uint256 amount0, uint256 amount1);
    event FeesCollected(address recipient, uint256 tokenId, uint256 amount0, uint256 amount1);

    constructor(INonfungiblePositionManager _uniswapPositionManager, TransferHelper _transferHelper) {
        uniswapPositionManager = _uniswapPositionManager;
        transferHelper = _transferHelper;
        manager = msg.sender;
    }

    modifier isAuthorised {
        require(msg.sender == manager, "You are not allowed to call this function");
        _;
    }

    function depositNFT(uint256 tokenId, address owner) external {
        require(uniswapPositionManager.positions(tokenId), 'Not a valid Uniswap V3 Position');
        require(msg.sender == owner, "You are not the owner");
        (, , address token0, address token1, , , , uint128 liquidity, , , , ) = uniswapPositionManager.positions(tokenId);
        uniswapPositionManager.safeTransferFrom(owner, address(this), tokenId);
        vault[tokenId] = Depositor({owner: owner, token0: token0, token1: token1, liquidity: liquidity});

        emit NFTDepositComplete(owner, tokenId, vault[tokenId].liquidity);
    }

    function getDeposit(uint256 tokenId) external view returns (uint128 liquidity, address owner) {
        return (vault[tokenId].liquidity, vault[tokenId].owner);
    }

    function exitPosition(uint256 tokenId, address owner) external isAuthorised returns (uint256 amount0, uint256 amount0) {
        uint128 liquidity = deposits[tokenId].liquidity;
        INonfungiblePositionManager.DecreaseLiquidityParams memory params =
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            });

        (amount0, amount1) = uniswapPositionManager.decreaseLiquidity(params);
        transferHelper.safeTransfer(vault[tokenId].token0, owner, amount0);
        transferHelper.safeTransfer(vault[tokenId].token1, owner, amount1);
        collectAllFees(tokenId);
        uniswapPositionManager.burn(tokenId);

        emit PositionRemoved(owner, tokenId, amount0, amount1);
    }

    function collectAllFees(uint256 tokenId) external isAuthorised returns (uint256 amount0, uint256 amount1) {
        INonfungiblePositionManager.CollectParams memory params =
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: vault[tokenId].owner, 
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });
        (amount0, amount1) = uniswapPositionManager.collect(params);

        emit FeesCollected(recipient, tokenId, amount0, amount1);
    }

    function retrieveNFT(uint256 tokenId) external {
        require(msg.sender == vault[tokenId].owner, "You are not the owner");
        delete vault[tokenId];
        uniswapPositionManager.safeTransferFrom(address(this), vault[tokenId].owner, tokenId); 

        emit NFTWithdrawalComplete(owner, tokenId, vault[tokenId].liqiudity);
    }  

    function onERC721Received( 
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }  
}
