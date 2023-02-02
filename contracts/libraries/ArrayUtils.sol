// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Math} from  "@openzeppelin/contracts/utils/math/Math.sol";

library ArrayUtils {

    function binarySearch(uint256[] storage array, uint256 key) internal view returns (bool, uint) {
        if (array.length == 0) {
            return (false, 0);
        }

        uint256 low = 0;
        uint256 high = array.length - 1;

        while (low <= high) {
            uint256 mid = Math.average(low, high);
            if (array[mid] == key) {
                return (true, mid);
            } else if (array[mid] > key) {
                high = mid - 1;
            } else {
                low = mid + 1;
            }
        }

        return (false, 0);
    }

    function firstIndexOf(uint256[] storage array, uint256 key) internal view returns (bool, uint256) {
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


    function equals(uint256[] storage a, uint256[] storage b) internal view returns (bool){
        if (a.length != b.length) {
            return false;
        }
        for (uint256 i = 0; i < a.length; i++) {
            if (a[i] != b[i]) {
                return false;
            }
        }
        return true;
    }

    function removeByIndex(uint256[] storage array, uint index) internal {
        require(index < array.length, "ArrayForUint256: index out of bounds");
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

    function addValue(uint256[] storage array, uint256 value) internal {
        uint index;
        bool isIn;
        (isIn, index) = firstIndexOf(array, value);
        if (!isIn) {
            array.push(value);
        }
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
        minIndex = 0;
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] < minValue) {
                minValue = array[i];
                minIndex = i;
            }
        }
    }

}
