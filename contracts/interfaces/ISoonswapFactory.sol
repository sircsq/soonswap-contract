// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ISoonswapFactory {

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function createPair(
        address tokenA,
        address tokenB,
        uint8 swapFee,
        bool bilateral,
        address nftContract,
        address feeToken) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;

    function getFeeTo() external view returns (address feeTo);
}
