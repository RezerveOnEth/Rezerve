// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.4;

interface RezerveExchange {
    function exchangeReserve ( uint256 _amount ) external;
    function flush() external;
}