// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8;

import "./NFTAuction.sol";

contract NFTAuctionV2 is NFTAuction {

    uint256 public testParam;

    function setTestParam(uint256 param) public {
        testParam = param;
    }

}