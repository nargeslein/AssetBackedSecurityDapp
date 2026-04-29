// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Bond.sol";
import "./WaterFall.sol";

contract BondB is Bond {
    constructor(uint256 initialSupply, address owner) {
        _mintInitialSupply(initialSupply, owner);
    }

    function PayIn() public {
        require(msg.sender == Owner, "BondB: only owner");
        WaterFallIntPrin = WaterFall(payable(WaterfallAddress)).SendFundsB();
        UpdateBalances(WaterFallIntPrin[0], WaterFallIntPrin[1]);
    }
}
