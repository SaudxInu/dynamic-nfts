// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract BullBearToken is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    Ownable,
    AutomationCompatibleInterface,
    VRFConsumerBaseV2
{
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    AggregatorV3Interface private immutable i_pricefeed;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint256 private immutable i_interval;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    int256 private s_currentPrice;
    uint256 private s_lastTimeStamp;
    uint32 private s_callbackGasLimit;

    string[] private s_bullUrisIpfs = [
        "https://ipfs.io/ipfs/QmRXyfi3oNZCubDxiVFre3kLZ8XeGt6pQsnAQRZ7akhSNs?filename=gamer_bull.json",
        "https://ipfs.io/ipfs/QmRJVFeMrtYS2CUVUM2cHJpBV5aX2xurpnsfZxLTTQbiD3?filename=party_bull.json",
        "https://ipfs.io/ipfs/QmdcURmN1kEEtKgnbkVJJ8hrmsSWHpZvLkRgsKKoiWvW9g?filename=simple_bull.json"
    ];
    string[] private s_bearUrisIpfs = [
        "https://ipfs.io/ipfs/Qmdx9Hx7FCDZGExyjLR6vYcnutUR8KhBZBnZfAPHiUommN?filename=beanie_bear.json",
        "https://ipfs.io/ipfs/QmTVLyTSuiKGUEmb88BgXG3qNC8YgpHZiFbjHrXKH3QHEu?filename=coolio_bear.json",
        "https://ipfs.io/ipfs/QmbKhBXVWmwrYsTPFYfroR2N7NAekAMxHUVg2CWks7i9qj?filename=simple_bear.json"
    ];

    event RandomNumberRequested(uint256 _requestId);
    event TokensUpdated(string _marketTrend);

    constructor(
        uint256 _interval,
        address _priceFeedAddress,
        address _vrfCoordinatorAddress,
        uint64 _subscriptionId,
        bytes32 _gasLane, // aka key hash
        uint32 _callbackGasLimit
    ) ERC721("Bull & Bear Token", "BBTK") VRFConsumerBaseV2(_vrfCoordinatorAddress) {
        i_pricefeed = AggregatorV3Interface(_priceFeedAddress);
        i_vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinatorAddress);
        i_interval = _interval;
        i_subscriptionId = _subscriptionId;
        i_gasLane = _gasLane;

        s_currentPrice = getLatestPrice();
        s_lastTimeStamp = block.timestamp;
        s_callbackGasLimit = _callbackGasLimit;
    }

    function safeMint(address to) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();

        _tokenIdCounter.increment();

        _safeMint(to, tokenId);

        // Default to a bull NFT
        string memory defaultUri = s_bullUrisIpfs[0];

        _setTokenURI(tokenId, defaultUri);
    }

    function checkUpkeep(bytes calldata /* checkData */ )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /*performData */ )
    {
        upkeepNeeded = (block.timestamp - s_lastTimeStamp) > i_interval;

        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /* performData */ ) external override {
        if ((block.timestamp - s_lastTimeStamp) <= i_interval) return;

        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, i_subscriptionId, REQUEST_CONFIRMATIONS, s_callbackGasLimit, NUM_WORDS
        );

        emit RandomNumberRequested(requestId);
    }

    function fulfillRandomWords(uint256, /* requestId */ uint256[] memory randomWords) internal override {
        int256 latestPrice = getLatestPrice();

        string memory trend;
        uint256 idx;
        if (latestPrice == s_currentPrice) {
            return;
        } else if (latestPrice < s_currentPrice) {
            trend = "bear";
            idx = randomWords[0] % s_bearUrisIpfs.length;
        } else {
            trend = "bull";
            idx = randomWords[0] % s_bullUrisIpfs.length;
        }

        updateAllTokenUris(trend, idx);

        emit TokensUpdated(trend);

        s_currentPrice = latestPrice;
        s_lastTimeStamp = block.timestamp;
    }

    // Helpers

    function getLatestPrice() public view returns (int256) {
        (
            /*uint80 roundID*/
            ,
            int256 price,
            /*uint startedAt*/
            ,
            /*uint timeStamp*/
            ,
            /*uint80 answeredInRound*/
        ) = i_pricefeed.latestRoundData();

        return price;
    }

    function updateAllTokenUris(string memory trend, uint256 idx) internal {
        if (compareStrings("bear", trend)) {
            for (uint256 i = 0; i < _tokenIdCounter.current(); i++) {
                _setTokenURI(i, s_bearUrisIpfs[idx]);
            }
        } else {
            for (uint256 i = 0; i < _tokenIdCounter.current(); i++) {
                _setTokenURI(i, s_bullUrisIpfs[idx]);
            }
        }
    }

    function setCallbackGasLimit(uint32 _callbackGasLimit) public onlyOwner {
        s_callbackGasLimit = _callbackGasLimit;
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
