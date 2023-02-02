// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ArrayUtils} from './utils/ArrayUtils.sol';
import {ISoonPair} from './interfaces/ISoonPair.sol';
import {IERC20} from  './interfaces/IERC20.sol';
import {IERC721} from  './interfaces/IERC721.sol';
import {IERC721Receiver} from  './interfaces/IERC721Receiver.sol';
import {Math} from './libraries/Math.sol';
import {TransferLib} from './libraries/TransferLib.sol';
import {ISoonswapFactory} from './interfaces/ISoonswapFactory.sol';
import {SoonswapOrderCenter} from  "./SoonswapOrderCenter.sol";

contract SoonPair is ISoonPair, IERC721Receiver {

    address public factory;
    address public orderCenter;
    address public token0;
    address public token1;
    address public nftContract;
    address public feeToken;
    uint8   public swapFee;
    bool public bilateral = false;

    uint256 public buyOrderId;
    uint256 public sellOrderId;

    address public feeTo;

    uint256 private reserve0;
    uint256 private reserve1;
    uint32  private blockTimestampLast;

    uint256[] public nfts;

    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'Soonswap: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    constructor(){
        factory = msg.sender;
    }


    function getReserves() public view returns (uint256 _reserve0, uint256 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function initialize(
        address _token0,
        address _token1,
        uint8 _swapFee,
        bool _bilateral,
        address _nftContract,
        address _orderCenter,
        address _feeToken,
        address _feeTo
    ) external {
        require(msg.sender == factory, 'Soonswap: FORBIDDEN');
        token0 = _token0;
        token1 = _token1;
        swapFee = _swapFee;
        nftContract = _nftContract;
        feeToken = _feeToken;
        feeTo = _feeTo;
        bilateral = _bilateral;
        orderCenter = _orderCenter;
    }

    function balanceETH() public view returns (uint256){
        return address(address(this)).balance;
    }

    function depositToToken(uint256[] calldata buyPrices) payable external lock returns (uint256){
        require(!bilateral && token0 == feeToken, 'Soonswap: TOKEN0_NOT_IS_FEETOKEN');
        uint256 buyPricesSum = ArrayUtils.arraySum(buyPrices);
        if (feeToken != address(0)) {
            IERC20(feeToken).transferFrom(msg.sender, address(this), buyPricesSum);
        } else {
            require(buyPricesSum == msg.value, 'Soonswap: buyPricesSum == msg.value');
        }
        (bool _state,uint256 _orderId) = _creatBuyOrder(buyPrices);
        require(_state, 'Soonswap: CREAT_BUY_ORDER_FAIL');
        // 更新储备量
        _update();
        emit depositToTokenEvent(msg.sender, _orderId, buyPricesSum, buyPrices);
        return _orderId;
    }

    function editToToken(
        uint256 _buyOrderId,
        uint256[] calldata buyPrices
    ) payable external lock returns (bool result){
        require(!bilateral && token0 == feeToken, 'Soonswap: TOKEN0_NOT_IS_FEETOKEN');
        SoonswapOrderCenter.BuyOrder memory _oldBuyOrder = SoonswapOrderCenter(orderCenter).getBuyOrders(nftContract, _buyOrderId);
        require(_oldBuyOrder.user == msg.sender, 'Soonswap: oldBuyOrder.user == msg.sender');
        uint256 _buyPricesSum = ArrayUtils.arraySum(_oldBuyOrder.prices);
        uint256 _newbuyPricesSum = ArrayUtils.arraySum(buyPrices);
        if (_buyPricesSum > _newbuyPricesSum) {
            uint256 money = _buyPricesSum - _newbuyPricesSum;
            if (feeToken != address(0)) {
                TransferLib.safeTransfer(feeToken, msg.sender, money);
            } else {
                payable(address(this)).transfer(money);
            }
        } else if (_buyPricesSum < _newbuyPricesSum) {
            uint256 money = _newbuyPricesSum - _buyPricesSum;
            if (feeToken != address(0)) {
                IERC20(feeToken).transferFrom(msg.sender, address(this), money);
            } else {
               // require(money == msg.value, 'Soonswap: money == msg.value');
            }
        }

        _oldBuyOrder.buyOrderTime = block.timestamp;
        _oldBuyOrder.prices = buyPrices;
        _oldBuyOrder.totalMoney = _newbuyPricesSum;

        SoonswapOrderCenter(orderCenter).updateBuyOrders(_buyOrderId, _oldBuyOrder);

        _update();
        emit editToTokenEvent(msg.sender, _buyOrderId, _buyPricesSum, buyPrices);
        return true;
    }


    function depositToNFT(
        uint256[] calldata sellNfts,
        uint256[] calldata sellPrices
    ) external lock returns (uint256){
        require(!bilateral && token0 == nftContract, 'Soonswap: TOKEN0_NOT_IS_NFTCONTRACT');
        bool isUpdateOrder = false;
        if (reserve1 > 0) {
            isUpdateOrder = true;
        }
        for (uint i = 0; i < sellNfts.length; i++) {
            IERC721(nftContract).safeTransferFrom(msg.sender, address(this), sellNfts[i]);
            ArrayUtils.addOnlyValue(nfts, sellNfts[i]);
        }
        (bool _state,uint256 _sellOrderId) = _creatSellOrder(sellPrices, sellNfts);
        require(_state, 'Soonswap: CREAT_SELL_ORDER_FAIL');
        _update();
        emit depositToNFTEvent(msg.sender, _sellOrderId, sellNfts, sellPrices);
        return _sellOrderId;
    }

    function editToNFT(
        uint256 _sellOrderId,
        uint256[] calldata sellNfts,
        uint256[] calldata sellPrices
    ) external lock returns (bool result){
        require(!bilateral && token0 == nftContract, 'Soonswap: TOKEN0_NOT_IS_NFTCONTRACT');
        SoonswapOrderCenter.SellOrder memory _oldSellOrder = SoonswapOrderCenter(orderCenter).getSellOrders(nftContract, _sellOrderId);
        require(_oldSellOrder.user == msg.sender, 'Soonswap: oldSellOrder.user == msg.sender');
        (bool refund,) = ArrayUtils.firstIndexOf(sellPrices, 0);
        if (refund) {
            for (uint i = 0; i < sellPrices.length; i++) {
                if (sellPrices[i] == 0) {
                    IERC721(nftContract).safeTransferFrom(address(this), msg.sender, sellNfts[i]);
                    ArrayUtils.removeByValue(nfts, sellNfts[i]);
                }
            }
        }
        _oldSellOrder.sellOrderTime = block.timestamp;
        _oldSellOrder.nfts = sellNfts;
        _oldSellOrder.prices = sellPrices;
        SoonswapOrderCenter(orderCenter).updateSellOrders(_sellOrderId, _oldSellOrder);
        _update();
        emit editToNFTEvent(msg.sender, _sellOrderId, sellNfts, sellPrices);
        return true;
    }

    function _update() private {
        if (feeToken != address(0)) {
            reserve0 = uint256(IERC20(feeToken).balanceOf(address(this)));
        } else {
            reserve0 = address(address(this)).balance;
        }
        reserve1 = uint256(IERC721(nftContract).balanceOf(address(this)));
        blockTimestampLast = uint32(block.timestamp % 2 ** 32);
        emit Sync(reserve0, reserve1);
    }


    function trading(Trading memory _trading) payable external returns (bool){
        require(orderCenter == msg.sender, 'Soonswap: Only orderCenter trading !');
        if (_trading.tradType == 1) {
            uint256 _price = _trading.txPrice * (1000 - swapFee) / 1000;
            require(_price > 0, 'Soonswap: _price > 0');
            uint256 _fee = 0;
            if (bilateral) {
                _fee = _trading.txPrice * swapFee * 20 / 100000;
            } else {
                _fee = _trading.txPrice * swapFee / 1000;
            }
            if (feeToken != address(0)) {
                TransferLib.approve(feeToken, feeTo, _fee);
                TransferLib.safeTransfer(feeToken, feeTo, _fee);
                TransferLib.approve(feeToken, _trading.to, _price);
                TransferLib.safeTransfer(feeToken, _trading.to, _price);
                if (_trading.txPrice < _trading.orderPrice) {
                    TransferLib.approve(feeToken, _trading.from, _trading.orderPrice - _trading.txPrice);
                    TransferLib.safeTransfer(feeToken, _trading.from, _trading.orderPrice - _trading.txPrice);
                }
            } else {
                payable(feeTo).transfer(_fee);
                payable(_trading.to).transfer(_price);
                if (_trading.txPrice < _trading.orderPrice) {
                    payable(_trading.from).transfer(_trading.orderPrice - _trading.txPrice);
                }
            }
        } else if (_trading.tradType == 2) {
            IERC721(nftContract).approve(_trading.to, _trading.nftId);
            IERC721(nftContract).safeTransferFrom(_trading.from, _trading.to, _trading.nftId);
            ArrayUtils.removeByValue(nfts, _trading.nftId);
        }
        _update();
        emit tradingEvent(_trading.orderId, address(this), _trading.from, _trading.to, _trading.orderPrice, _trading.txPrice, _trading.nftId, _trading.tradType);
        return true;
    }


    function exchange(uint256[] memory _tokenAmounts, uint256[] memory _tokenIds, uint256 _orderId, uint256 _txType)payable external lock {
        require(!bilateral, 'SoonswapPair: BILATERAL_IS_NOT_TRUE');
        uint256 buyPricesSum = ArrayUtils.arraySum(_tokenAmounts);

        if (_txType == 1) {
            SoonswapOrderCenter.SellOrder memory _sellOrder = SoonswapOrderCenter(orderCenter).getSellOrders(nftContract, _orderId);
            uint256 _amount = buyPricesSum * (1000 - swapFee) / 1000;
            uint256[] memory prices = _sellOrder.prices;
            for (uint i = 0; i < _tokenAmounts.length; i++) {
                for (uint j = 0; j < prices.length; j++) {
                    if(prices[j] == _tokenAmounts[i] && !_sellOrder.states[j]){
                        for (uint k = 0; k < _tokenIds.length; k++) {
                            uint256 _tokenId = _tokenIds[k];
                            (bool seek,uint256 index) = ArrayUtils.firstIndexOf(_sellOrder.nfts, _tokenId);
                            require(seek, 'SoonswapPair.exchange:seek');
                            require(_sellOrder.prices[index] <= _tokenAmounts[k], 'SoonswapPair.exchange:prices <= tokenAmount');
                            IERC721(nftContract).approve(msg.sender, _tokenId);
                            IERC721(nftContract).safeTransferFrom(address(this), msg.sender, _tokenId);
                            ArrayUtils.removeByValue(nfts, _tokenId);
                            _sellOrder.states[j] = true;
                            SoonswapOrderCenter(orderCenter).updateSellOrders(_orderId, _sellOrder);
                            emit tradingEvent(_orderId, address(this), _sellOrder.user, msg.sender, _sellOrder.prices[index], _sellOrder.prices[index], _tokenId, 2);
                        }
                    }
                }
            }
            IERC20(feeToken).transferFrom(msg.sender, address(this), buyPricesSum);
            TransferLib.approve(feeToken, feeTo, buyPricesSum - _amount);
            TransferLib.safeTransfer(feeToken, feeTo, buyPricesSum - _amount);
            TransferLib.approve(feeToken, _sellOrder.user, _amount);
            TransferLib.safeTransfer(feeToken, _sellOrder.user, _amount);

        } else if (_txType == 2) {
            require(_tokenIds.length > 0, 'SoonswapPair: _tokenIds.length > 0');
            SoonswapOrderCenter.BuyOrder memory _buyOrder = SoonswapOrderCenter(orderCenter).getBuyOrders(nftContract, _orderId);
            uint256[] memory prices = _buyOrder.prices;
            for (uint i = 0; i < _tokenIds.length; i++) {
                for (uint j = 0; j < prices.length; j++) {
                    if( !_buyOrder.states[j]){
                        IERC721(nftContract).transferFrom(msg.sender, _buyOrder.user, _tokenIds[i]);
                        uint256 _amount = prices[j] * (1000 - swapFee) / 1000;
                        if(feeToken != address(0)){
                            TransferLib.approve(feeToken, feeTo, prices[j] - _amount);
                            TransferLib.safeTransfer(feeToken, feeTo, prices[j] - _amount);
                            TransferLib.safeTransfer(feeToken, msg.sender, _amount);
                        }else{
                            (bool feeSuccess,) = payable(feeTo).call{ value : prices[j] - _amount, gas : 20000 }("");
                            require(feeSuccess , 'Soonswap: Fee failure to pay ETH');
                            (bool pay,) = payable(msg.sender).call{ value : _amount, gas : 20000 }("");
                            require(pay , 'Soonswap: Pay failure to pay ETH');
                        }
                        _buyOrder.states[j] = true;
                        SoonswapOrderCenter(orderCenter).updateBuyOrders(_orderId, _buyOrder);
                        emit tradingEvent(_orderId, address(this), msg.sender, _buyOrder.user, _buyOrder.prices[j], _buyOrder.prices[j], _tokenIds[i], 1);
                    }
                }
            }
        }
        _update();
    }

    function _creatBuyOrder(uint256[] memory buyPrices) private returns (bool _state, uint256){

        uint256 buyPricesSum = ArrayUtils.arraySum(buyPrices);
        uint256 _newOrderId = SoonswapOrderCenter(orderCenter).getBuyOrderId(nftContract);
        SoonswapOrderCenter.BuyOrder memory _buyOrder = SoonswapOrderCenter.BuyOrder({
                                                                                buyOrderId : _newOrderId,
                                                                                buyOrderTime : block.timestamp,
                                                                                nftContract : nftContract,
                                                                                feeToken : feeToken,
                                                                                swapFee : swapFee,
                                                                                pair : address(this),
                                                                                user : msg.sender,
                                                                                prices : buyPrices,
                                                                                states : new bool[](buyPrices.length),
                                                                                totalMoney : buyPricesSum,
                                                                                bilateral : bilateral
        });
        bool _result = SoonswapOrderCenter(orderCenter).addBuyOrders(_newOrderId, _buyOrder);
        return (_result, _newOrderId);
    }

    function _creatSellOrder(uint256[] memory sellPrices, uint256[] memory sellNfts) private returns (bool _state, uint256 _orderId){
        uint256 _sellOrderId = SoonswapOrderCenter(orderCenter).getSellOrderId(nftContract);
        SoonswapOrderCenter.SellOrder memory _sellOrder = SoonswapOrderCenter.SellOrder({
                                                                                sellOrderId : _sellOrderId,
                                                                                sellOrderTime : block.timestamp,
                                                                                nftContract : nftContract,
                                                                                feeToken : feeToken,
                                                                                swapFee : swapFee,
                                                                                pair : address(this),
                                                                                user : msg.sender,
                                                                                nfts : sellNfts,
                                                                                states : new bool[](sellNfts.length),
                                                                                prices : sellPrices,
                                                                                bilateral : bilateral
                                                            });
        bool _result = SoonswapOrderCenter(orderCenter).addSellOrders(_sellOrderId, _sellOrder);
        return (_result, _sellOrderId);
    }

    function rand(uint256 _length) private view returns (uint256) {
        uint256 random = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
        return (random % _length);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
