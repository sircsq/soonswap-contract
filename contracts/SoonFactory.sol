// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import './interfaces/ISoonswapFactory.sol';
import './SoonPair.sol';

contract SoonFactory is ISoonswapFactory {
    address public feeTo;
    address public orderCenter;
    address public feeToSetter;

    mapping(address => mapping(address => address[])) public getPair;
    mapping(address => address[]) public getNftPair;
    address[] public allPairs;

    event PairCreated(
        address indexed token0,
        address indexed token1,
        uint8 swapFee,
        bool bilateral,
        address nftContract,
        address feeToken,
        address pair,
        uint allPairs);

    constructor(address _feeToSetter, address _orderCenter)  {
        feeToSetter = _feeToSetter;
        orderCenter = _orderCenter;
    }

    function createPair(
        address tokenA,
        address tokenB,
        uint8 swapFee,
        bool bilateral,
        address nftContract,
        address feeToken
    ) external returns (address pair) {
        require(tokenA != tokenB, 'Soonswap: IDENTICAL_ADDRESSES');

        pair =  address(new SoonPair{salt: bytes32(keccak256(abi.encodePacked(tokenA, tokenB,block.timestamp)))}());
        ISoonPair(pair).initialize(tokenA, tokenB, swapFee, false, nftContract,orderCenter,feeToken,feeTo);
        getPair[tokenA][tokenB].push(pair);
        getNftPair[nftContract].push(pair);
        allPairs.push(pair);
        emit PairCreated(tokenA, tokenB, swapFee, bilateral, nftContract,feeToken, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'Soonswap: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'Soonswap: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }

    function getFeeTo() external view returns (address ){
        return feeTo;
    }

     function getPairs(address tokenA, address tokenB) external view returns (address[] memory pair){
       return  getPair[tokenA][tokenB];
     }

}
