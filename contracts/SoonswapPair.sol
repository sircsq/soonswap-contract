// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ArrayUtils} from './utils/ArrayUtils.sol';
import {ISoonswapPair} from './interfaces/ISoonswapPair.sol';
import {SoonswapERC20} from './SoonswapERC20.sol';
import {IERC20} from  './interfaces/IERC20.sol';
import {IERC721} from  './interfaces/IERC721.sol';
import {IERC721Receiver} from  './interfaces/IERC721Receiver.sol';
import {Math} from './libraries/Math.sol';
import {TransferLib} from './libraries/TransferLib.sol';
import {ISoonswapFactory} from './interfaces/ISoonswapFactory.sol';
import {SoonswapOrderCenter} from  "./SoonswapOrderCenter.sol";

contract SoonswapPair is ISoonswapPair,IERC721Receiver, SoonswapERC20 {

    address public factory;
    address public orderCenter;
    address public token0;
    address public token1;
    address public nftContract;
    address public feeToken;
    uint8   public swapFee;
    bool public bilateral = true;

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

    constructor() SoonswapERC20("LpToken", "LPTOKEN"){
        factory = msg.sender;
    }

    function getReserves() public view returns (uint256 _reserve0, uint256 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function getSellPrice() public view returns (uint256) {
        require(bilateral, 'Soonswap: BILATERAL_IS_FALSE');
        if(reserve1 < 1){
            return 0;
        }
        return ((1000-swapFee) * reserve0)/(reserve1*1000 + 1000);
    }

    function getBuyPrice() public view returns (uint256) {
        require(bilateral, 'Soonswap: BILATERAL_IS_FALSE');
        if(reserve1 < 2){
            return 0;
        }
        return ((1000+swapFee) * reserve0)/(reserve1*1000 - 1000);
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

    function addLiquidity(
        uint256[] calldata _tokenIds,
        uint256 _tokenAmount
    )payable public virtual lock returns (uint256 liquidity){
        require(bilateral, 'Soonswap: BILATERAL_IS_FALSE_DONT_ADDLIQUIDITY');
        bool isOrder = false;
        if(reserve1 == 0){
            isOrder = true;
        }
        // a/b = c/d    token >= reserve0 * nft/ reserve1
        uint _nftCount = _tokenIds.length;
        require((_nftCount * reserve0) <= (reserve1 * _tokenAmount), 'Soonswap: NFT<->TOKEN_RATIO_ERROR');

        for (uint i = 0; i < _tokenIds.length; i++) {
            IERC721(nftContract).safeTransferFrom(msg.sender, address(this), _tokenIds[i]);
            ArrayUtils.addOnlyValue(nfts,_tokenIds[i]);
        }
        if (feeToken != address(0)) {
            IERC20(feeToken).transferFrom(msg.sender, address(this), _tokenAmount);
        } else {
            require(_tokenAmount == msg.value, 'Soonswap: _tokenAmount == msg.value');
        }

        uint256 _totalSupply = totalSupply();
        uint256 _liquidity = 0;
        if(_totalSupply > 0 ){
            _liquidity = (_nftCount * _totalSupply) / reserve1 ;
        }else{
            _liquidity = Math.sqrt( _nftCount * _tokenAmount ) * (10**18);
        }
        require(_liquidity > 0, 'Soonswap: _liquidity > 0');
        _mint(msg.sender, _liquidity);
        _update();
        uint256[] memory _prices;
        _prices = new uint256[](1);
        _prices[0] = getBuyPrice();
         if(isOrder && getBuyPrice() > 0){
             (bool _state,uint256 _orderId) = _creatBuyOrder(_prices);
             require(_state, 'Soonswap: CREAT_BUY_ORDER_FAIL');
             buyOrderId = _orderId;
             uint256 nftIndex =  rand(nfts.length);
             uint256[]  memory _nfts;
             _nfts = new uint256[](1);
             _nfts[0] = nfts[nftIndex];
             _prices[0] = getSellPrice();
             if(_prices[0] > 0){
                 (bool _sellState,uint256 _sellOrderId) = _creatSellOrder(_prices,_nfts);
                 require(_sellState, 'Soonswap: CREAT_SELL_ORDER_FAIL');
                 sellOrderId = _sellOrderId;
             }
         }
        emit addLiquidityEvent(msg.sender, _tokenIds, _tokenAmount, _liquidity);
        return _liquidity;
    }

    function removeLiquidity(uint256 lpAmount)payable external virtual lock returns (uint256 _nftAmount,uint256 _tokenAmount){
        require(bilateral, 'Soonswap: BILATERAL_IS_FALSE_DONT_REMOVELIQUIDITY');
        uint256 _totalSupply = totalSupply();
         _tokenAmount = reserve0 * lpAmount / _totalSupply;
        _nftAmount = reserve1 * lpAmount / _totalSupply;
        require(_tokenAmount > 0, 'Soonswap: _tokenAmount > 0');
        if (feeToken != address(0)) {
            TransferLib.approve(feeToken, msg.sender, _tokenAmount);
            TransferLib.safeTransfer(feeToken, msg.sender, _tokenAmount);
        } else {
            (bool success,) = payable(msg.sender).call{ value : _tokenAmount, gas : 20000 }("");
            require(success , 'Soonswap: Failure to pay ETH');
        }
        uint256[] memory _tokenIds = new uint256[](_nftAmount);
        if(_nftAmount > 0){
            for (uint i = 0; i < _nftAmount; i++) {
                uint256  _tokenId =  IERC721(nftContract).tokenOfOwnerByIndex(address(this),0); //取第一个;
                IERC721(nftContract).safeTransferFrom(address(this), msg.sender, _tokenId);
                _tokenIds[i] = _tokenId;
                ArrayUtils.removeByValue(nfts,_tokenId);
            }
        }
        _burn(msg.sender,lpAmount);
        _update();
        if(reserve1 == 0){
            SoonswapOrderCenter.BuyOrder memory _oldBuyOrder = SoonswapOrderCenter(orderCenter).getBuyOrders(nftContract,buyOrderId);
            _oldBuyOrder.buyOrderTime = block.timestamp;
            _oldBuyOrder.prices = new uint256[](0);
            _oldBuyOrder.totalMoney = 0;
            SoonswapOrderCenter(orderCenter).updateBuyOrders(buyOrderId,_oldBuyOrder);

            SoonswapOrderCenter.SellOrder memory _oldSellOrder = SoonswapOrderCenter(orderCenter).getSellOrders(nftContract,sellOrderId);
            _oldSellOrder.sellOrderTime = block.timestamp;
            _oldSellOrder.nfts = new uint256[](0);
            _oldSellOrder.prices = new uint256[](0);
            SoonswapOrderCenter(orderCenter).updateSellOrders(sellOrderId,_oldSellOrder);
        }
        emit removeLiquidityEvent(msg.sender, _tokenIds, _tokenAmount, lpAmount);
    }

    function balanceETH()public view returns (uint256 ){
           return address(address(this)).balance;
    }

    function _update() private {
        if(feeToken != address(0)){
            reserve0 = uint256(IERC20(feeToken).balanceOf(address(this)));
        }else{
            reserve0 = address(address(this)).balance;
        }
        reserve1 = uint256(IERC721(nftContract).balanceOf(address(this)));
        blockTimestampLast = uint32(block.timestamp % 2 ** 32);
        emit Sync(reserve0, reserve1);
    }


    function trading(Trading memory _trading)external returns (bool){
        require(orderCenter == msg.sender, 'Soonswap: Only orderCenter trading !');
        if(_trading.tradType == 1){

            uint256 _price  = _trading.txPrice *  (1000 - swapFee) / 1000;
            require(_price > 0, 'Soonswap: _price > 0');
            uint256 _fee = 0 ;
            if(bilateral){
                _fee = _trading.txPrice *  swapFee * 20 / 100000;
            }else{
                _fee = _trading.txPrice *  swapFee  / 1000;
            }
            if(feeToken != address(0)){
                TransferLib.approve(feeToken, feeTo, _fee);
                TransferLib.safeTransfer(feeToken, feeTo, _fee);
                TransferLib.approve(feeToken, _trading.to,_price);
                TransferLib.safeTransfer(feeToken, _trading.to,_price);
                if(_trading.txPrice < _trading.orderPrice){
                    TransferLib.approve(feeToken, _trading.from,_trading.orderPrice - _trading.txPrice);
                    TransferLib.safeTransfer(feeToken, _trading.from,_trading.orderPrice - _trading.txPrice);
                }
            }else{
                (bool feeSuccess,) = payable(feeTo).call{ value : _fee, gas : 20000 }("");
                require(feeSuccess , 'Soonswap: Fee failure to pay ETH');

                (bool success,) = payable(_trading.to).call{ value : _trading.txPrice, gas : 20000 }("");
                require(success , 'Soonswap: Failure to pay ETH');
                if(_trading.txPrice < _trading.orderPrice){
                    (bool paySuccess,) = payable(_trading.from).call{ value : _trading.orderPrice - _trading.txPrice, gas : 20000 }("");
                    require(paySuccess , 'Soonswap: Refund payment ETH failed');
                }
            }
        }else if(_trading.tradType == 2){
            IERC721(nftContract).approve(_trading.to, _trading.nftId);
            IERC721(nftContract).safeTransferFrom(_trading.from, _trading.to, _trading.nftId);
            ArrayUtils.removeByValue(nfts,_trading.nftId);
        }
        _update();
        emit tradingEvent(_trading.orderId,address(this),_trading.from, _trading.to,_trading.orderPrice , _trading.txPrice, _trading.nftId, _trading.tradType);
        return true;
    }

    function swap(uint256[] memory _tokenAmounts, uint256[] memory _tokenIds)payable external lock {
        require(bilateral, 'SoonswapPair: BILATERAL_IS_NOT_TRUE');
        require(_tokenAmounts[0] > 0 || _tokenIds[0] > 0, 'SoonswapPair: INSUFFICIENT_OUTPUT_AMOUNT');
        uint256 _price  = 0;
        address  _feeTo = ISoonswapFactory(factory).getFeeTo();
        if(_tokenAmounts.length > 0 && _tokenAmounts[0] > 1){
            for (uint i = 0; i < _tokenAmounts.length; i++) {
                _price = getBuyPrice();
                require(_price > 0, 'SoonswapPair: _price > 0');
                require(_price <= _tokenAmounts[i], 'SoonswapPair.swap: _price <= _tokenAmount');
               // uint256 _allAmount =  _price * (1000 + swapFee ) /1000;
                uint256 _feeAmount = ( _price *  swapFee * 20 ) / 100000;

                if (feeToken != address(0)) {
                    IERC20(feeToken).transferFrom(msg.sender, address(this), _price - _feeAmount);
                    TransferLib.approve(feeToken, _feeTo, _feeAmount);
                    IERC20(feeToken).transferFrom(msg.sender, _feeTo, _feeAmount);
                } else {
                    (bool success,) = payable(_feeTo).call{ value : _feeAmount, gas : 20000 }("");
                    require(success , 'Soonswap: Failure to pay ETH');
                }

                uint256 nftIndex =  rand(nfts.length);
                uint256  _tokenIdOne = nfts[nftIndex];
                IERC721(nftContract).approve(msg.sender, _tokenIdOne);
                IERC721(nftContract).safeTransferFrom(address(this), msg.sender, _tokenIdOne);
                ArrayUtils.removeByValue(nfts,_tokenIdOne);
                emit Swap(msg.sender, _tokenAmounts[i], _tokenIdOne, _tokenAmounts[i], _tokenIdOne);
                _update();
            }
        }else if (_tokenIds.length > 0 && _tokenIds[0] > 0){
            for (uint i = 0; i < _tokenIds.length; i++) {
                _price = getSellPrice();
                require(_price > 0, 'SoonswapPair.swap: _price > 0');
                IERC721(nftContract).safeTransferFrom(msg.sender, address(this), _tokenIds[i]);
                ArrayUtils.addOnlyValue(nfts,_tokenIds[i]);
                uint256 _sellAmount =  _price * (1000 - swapFee ) /1000;
                uint256 _feeAmount = ( _price *  swapFee * 20 ) / 100000;
                if (feeToken != address(0)) {
                    TransferLib.approve(feeToken, _feeTo , _feeAmount);
                    TransferLib.approve(feeToken, msg.sender, _sellAmount);
                    TransferLib.safeTransfer(feeToken, msg.sender, _sellAmount);
                    TransferLib.safeTransfer(feeToken, _feeTo, _feeAmount);
                } else {
                    (bool success,) = payable(msg.sender).call{ value : _sellAmount, gas : 20000 }("");
                    require(success , 'Soonswap: Failure to pay ETH');
                    (bool feeSuccess,) = payable(_feeTo).call{ value : _feeAmount, gas : 20000 }("");
                    require(feeSuccess , 'Soonswap: Fee failure to pay ETH');
                }
                emit Swap(msg.sender, _price, _tokenIds[i], _sellAmount, _tokenIds[i]);
                _update();
            }
        }
       SoonswapOrderCenter.BuyOrder memory _oldBuyOrder = SoonswapOrderCenter(orderCenter).getBuyOrders(nftContract,buyOrderId);
       _oldBuyOrder.buyOrderTime = block.timestamp;
       _oldBuyOrder.prices[0] = getBuyPrice();
       _oldBuyOrder.totalMoney = _oldBuyOrder.prices[0];
       SoonswapOrderCenter(orderCenter).updateBuyOrders(buyOrderId,_oldBuyOrder);
        SoonswapOrderCenter.SellOrder memory _oldSellOrder = SoonswapOrderCenter(orderCenter).getSellOrders(nftContract,sellOrderId);
        _oldSellOrder.sellOrderTime = block.timestamp;
        uint256 _nftIndex =  rand(nfts.length);
        _oldSellOrder.nfts[0] = nfts[_nftIndex];
        _oldSellOrder.prices[0] = getSellPrice();
        SoonswapOrderCenter(orderCenter).updateSellOrders(sellOrderId,_oldSellOrder);
    }

    function _creatBuyOrder(uint256[] memory buyPrices) private  returns (bool _state,uint256 ){

        uint256 buyPricesSum  =  ArrayUtils.arraySum(buyPrices);
        uint256  _newOrderId = SoonswapOrderCenter(orderCenter).getBuyOrderId(nftContract);
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
                                                                bilateral : true
                                                        });
        bool  _result = SoonswapOrderCenter(orderCenter).addBuyOrders(_newOrderId,_buyOrder);
        return (_result,_newOrderId);
    }

    function _creatSellOrder(uint256[] memory sellPrices,uint256[] memory sellNfts) private  returns(bool _state,uint256 _orderId){
        uint256  _sellOrderId = SoonswapOrderCenter(orderCenter).getSellOrderId(nftContract);
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
                                                                    bilateral : true
                                                        });
        bool  _result =  SoonswapOrderCenter(orderCenter).addSellOrders(_sellOrderId,_sellOrder);
        return (_result,_sellOrderId);
    }

    function rand(uint256 _length) private view returns(uint256) {
        uint256 random = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
        return (random%_length);
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
