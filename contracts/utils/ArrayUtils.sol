// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Math} from  "@openzeppelin/contracts/utils/math/Math.sol";
import {SoonswapOrderCenter} from  "../SoonswapOrderCenter.sol";


library ArrayUtils {


    function firstIndexOf(uint256[] memory array, uint256 key) internal pure returns (bool, uint256) {
        if (array.length == 0) {
            return (false, 0);
        }
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == key) {
                return (true, i);
            }
        }
        return (false, 0);
    }


    // 数组求和;
    function arraySum(uint256[] memory arr) internal pure returns (uint256 sum){
        uint256 _sum = uint256(0);
        for (uint256 i = 0; i < arr.length; i++) {
            _sum += arr[i];
        }
        return _sum;
    }


    function removeByIndex(uint256[] storage array, uint index) internal {
        require(index < array.length, "ArrayUtils: index out of bounds");
        while (index < array.length - 1) {
            array[index] = array[index + 1];
            index++;
        }
        array.pop();
    }


    function removeByValue(uint256[] storage array, uint256 value) internal {
        uint index;
        bool isIn;
        (isIn, index) = firstIndexOf(array, value);
        if (isIn) {
            removeByIndex(array, index);
        }
    }

    function removeBuyItme(SoonswapOrderCenter.BuyOrderItem[] storage buyPriceItems) internal {
        uint index = 0;
        require(index < buyPriceItems.length, "ArrayUtils: index out of bounds");
        while (index < buyPriceItems.length - 1) {
            buyPriceItems[index] = buyPriceItems[index + 1];
            index++;
        }
        buyPriceItems.pop();
    }

    function removeSellItme(SoonswapOrderCenter.SellOrderItem[] storage sellPriceItems,uint256 _nftId) internal {
        uint index = 0;
        if(_nftId > 0){
            for (uint256 i = 0; i < sellPriceItems.length; i++) {
                if (sellPriceItems[i].nftId == _nftId ) {
                    index = i;
                    break;
                }
            }
        }
        sellPriceItems[index] = sellPriceItems[sellPriceItems.length - 1];
        sellPriceItems.pop();
    }


    function updateBuyItme(SoonswapOrderCenter.BuyOrderItem[] storage _items,uint256 _price,bool state) internal {
        for (uint256 i = 0; i < _items.length; i++) {
            if (_items[i].price == _price && _items[i].state !=  state) {
                _items[i].state = state;
                break;
            }
        }
    }

    function updateSellItme(SoonswapOrderCenter.SellOrderItem[] storage _items,uint256 _price,uint256 _nftId,bool state) internal {
        for (uint256 i = 0; i < _items.length; i++) {
            if(_nftId > 0){
                if (_items[i].nftId == _nftId && _items[i].state !=  state) {
                    _items[i].state = state;
                    break;
                }
            }else{
                if (_items[i].price == _price && _items[i].state !=  state) {
                    _items[i].state = state;
                    break;
                }
            }
        }
    }

    function addOnlyValue(uint256[] storage array, uint256 value) internal {
        uint index;
        bool isIn;
        (isIn, index) = firstIndexOf(array, value);
        if (!isIn) {
            array.push(value);
        }
    }

    function addValue(uint256[] storage array, uint256 value) internal {
        array.push(value);
    }

    function extend(uint256[] memory a, uint256[] memory b) pure internal {
        if (b.length != 0) {
            for (uint i = 0; i < b.length; i++) {
                a[a.length] = b[i];
            }
        }
    }

    function distinct(uint256[] storage array) internal returns (uint256 length) {
        bool contains;
        uint index;
        for (uint i = 0; i < array.length; i++) {
            contains = false;
            index = 0;
            uint j = i + 1;
            for (; j < array.length; j++) {
                if (array[j] == array[i]) {
                    contains = true;
                    index = i;
                    break;
                }
            }
            if (contains) {
                for (j = index; j < array.length - 1; j++) {
                    array[j] = array[j + 1];
                }
                array.pop();
                i--;
            }
        }
        length = array.length;
    }

    function sort(uint256[] memory _array) public  pure  returns(uint256[] memory) {
        for(uint i = 1; i < _array.length;i++){
            uint256 item = _array[i];
            uint256 j=i;
            while ((j >= 1) && (item < _array[j-1])){
                _array[j] = _array[j-1];
                j--;
            }
            _array[j] = item;
        }
        return _array;
    }

    function reverse(uint256[] memory _array) public  pure  returns(uint256[] memory) {
        for(uint i = 1; i < _array.length;i++){
            uint256 item = _array[i];
            uint256 j=i;
            while ((j >= 1) && (item < _array[j-1])){
                _array[j] = _array[j-1];
                j--;
            }
            _array[j] = item;
        }
        uint256 temp;
        for (uint i = 0; i < _array.length / 2; i++) {
            temp = _array[i];
            _array[i] = _array[_array.length - 1 - i];
            _array[_array.length - 1 - i] = temp;
        }
        return _array;
    }



    function max(uint256[] memory array) internal pure returns (uint256 maxValue, uint256 maxIndex) {
        maxValue = array[0];
        maxIndex = 0;
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] > maxValue) {
                maxValue = array[i];
                maxIndex = i;
            }
        }
    }

    function min(uint256[] memory array) internal pure returns (uint256 minValue, uint256 minIndex) {
        minValue = array[0];
        if(array.length > 1){
            minValue = array[1];
        }
        minIndex = 0;
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] < minValue && array[i] > 0) {
                minValue = array[i];
                minIndex = i;
            }
        }
    }

}
