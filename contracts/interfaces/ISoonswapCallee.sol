// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.17;

interface ISoonswapCallee {
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
}
