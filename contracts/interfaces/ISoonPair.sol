// SPDX-License-Identifier: MIT
pragma solidity = 0.8.17;


interface ISoonPair {

    event depositToTokenEvent(
        address indexed sender,
        uint256  indexed orderId,
        uint256 buyPricesSum,
        uint256[] buyPrices
    );

    event editToTokenEvent(
        address indexed sender,
        uint256  indexed orderId,
        uint256 buyPricesSum,
        uint256[] buyPrices
    );

    event depositToNFTEvent(
        address indexed sender,
        uint256  indexed orderId,
        uint256[] nfts,
        uint256[] sellPrices
    );

    event editToNFTEvent(
        address indexed sender,
        uint256  indexed orderId,
        uint256[] nfts,
        uint256[] sellPrices
    );

    event tradingEvent(
        uint256 orderId,
        address pair,
        address from,
        address to,
        uint256 orderPrice,
        uint256 txPrice,
        uint256 tokenId,
        uint txType
    );

    event Sync(uint256 reserve0, uint256 reserve1);

    struct Trading {
        uint256 orderId;
        address from;
        address to;
        uint256 orderPrice;
        uint256 txPrice;
        uint256 nftId;
        uint tradType;
    }

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function swapFee() external view returns (uint8);

    function bilateral() external view returns (bool);

    function getReserves() external view returns (uint256 reserve0, uint256 reserve1, uint32 blockTimestampLast);

    function initialize(
        address _token0,
        address _token1,
        uint8 _swapFee,
        bool _bilateral,
        address _nftContract,
        address _orderCenter,
        address _feeToken,
        address _feeTo
    ) external;

    function trading(Trading memory trading) payable external returns (bool);


    function depositToToken(
        uint256[] calldata buyPrices
    ) payable external returns (uint256 _orderId);

    function editToToken(
        uint256 buyOrderId,
        uint256[] calldata buyPrices
    ) payable external returns (bool result);

    function depositToNFT(
        uint256[] calldata sellNfts,
        uint256[] calldata sellPrices
    ) external returns (uint256 depositToNFTId);

    function editToNFT(
        uint256 sellOrderId,
        uint256[] calldata sellNfts,
        uint256[] calldata sellPrices
    ) external returns (bool result);

    function exchange(
        uint256[] memory _tokenAmounts,
        uint256[] memory _tokenIds,
        uint256 _orderId,
        uint256 _txType
    )payable external;

}
