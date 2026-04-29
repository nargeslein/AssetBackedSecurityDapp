// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
This is for simulation of passing time. Only necessary for testing
*/
contract TimeSim {
    uint256 public Now;

    constructor() {
        Now = block.timestamp;
    }

    function Step() public {
        Now += 30 days;
    }
}
