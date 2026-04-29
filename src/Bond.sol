// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./WaterFall.sol";

contract Bond {
    /*
    The Bond contract mints a fixed supply of simple bond tokens. Token holders
    can withdraw their proportional share of interest and principal paid into
    the contract by the waterfall.
    */

    struct HolderAccounting {
        uint256 bondTokens;
        uint256 ethWithdrawnInt;
        uint256 ethWithdrawnPrin;
    }

    mapping(address => HolderAccounting) public holders;

    mapping(address => uint256) public balanceOfBondTokens;
    mapping(address => uint256) public ETHWithdrawnInt;
    mapping(address => uint256) public ETHWithdrawnPrin;

    uint256 public TotalETHPaidinInt;
    uint256 public TotalETHPaidinPrin;
    uint256 public InitialSupply;
    uint256[8] public StatusOutput;

    address public WaterfallAddress;
    address public Owner;

    uint256[2] public WaterFallIntPrin;

    bool public WaterFallSet = false;

    modifier OnlyOwner() {
        require(msg.sender == Owner, "Bond: only owner");
        _;
    }

    function SetWaterFall(address waterfallAddress) public {
        require(!WaterFallSet, "Bond: waterfall already set");
        WaterfallAddress = waterfallAddress;
        WaterFallSet = true;
    }

    function transfer(address _to, uint256 _value) public {
        require(balanceOfBondTokens[msg.sender] >= _value, "Bond: insufficient balance");

        uint256 senderBalance = balanceOfBondTokens[msg.sender];

        if (ETHWithdrawnInt[msg.sender] > 0) {
            uint256 transferredInt = ETHWithdrawnInt[msg.sender] * _value / senderBalance;
            ETHWithdrawnInt[_to] += transferredInt;
            ETHWithdrawnInt[msg.sender] -= transferredInt;
        }

        if (ETHWithdrawnPrin[msg.sender] > 0) {
            uint256 transferredPrin = ETHWithdrawnPrin[msg.sender] * _value / senderBalance;
            ETHWithdrawnPrin[_to] += transferredPrin;
            ETHWithdrawnPrin[msg.sender] -= transferredPrin;
        }

        balanceOfBondTokens[msg.sender] -= _value;
        balanceOfBondTokens[_to] += _value;
        _syncHolder(msg.sender);
        _syncHolder(_to);
    }

    function UpdateBalances(uint256 interest, uint256 principal) internal {
        TotalETHPaidinInt += interest;
        TotalETHPaidinPrin += principal;
    }

    function Withdraw() public {
        uint256 availableBalanceInt;
        uint256 availableBalancePrin;

        if (
            balanceOfBondTokens[msg.sender] * ((TotalETHPaidinInt + TotalETHPaidinPrin) / InitialSupply)
                > ETHWithdrawnInt[msg.sender] + ETHWithdrawnPrin[msg.sender]
        ) {
            availableBalanceInt =
                (balanceOfBondTokens[msg.sender] * TotalETHPaidinInt - ETHWithdrawnInt[msg.sender] * InitialSupply)
                    / InitialSupply;

            availableBalancePrin =
                (balanceOfBondTokens[msg.sender] * TotalETHPaidinPrin - ETHWithdrawnPrin[msg.sender] * InitialSupply)
                    / InitialSupply;
        }

        ETHWithdrawnInt[msg.sender] += availableBalanceInt;
        ETHWithdrawnPrin[msg.sender] += availableBalancePrin;
        _syncHolder(msg.sender);

        (bool success,) = payable(msg.sender).call{value: availableBalanceInt + availableBalancePrin}("");
        require(success, "Bond: transfer failed");
    }

    function CheckStatus(address BondAdress) public view returns (uint256[8] memory statusOutput) {
        statusOutput[0] = balanceOfBondTokens[BondAdress];
        statusOutput[1] = ETHWithdrawnInt[BondAdress];
        statusOutput[2] = ETHWithdrawnPrin[BondAdress];
        statusOutput[3] = TotalETHPaidinInt;
        statusOutput[4] = TotalETHPaidinPrin;
        statusOutput[7] = InitialSupply;
    }

    function _mintInitialSupply(uint256 initialSupply, address owner) internal {
        balanceOfBondTokens[msg.sender] = initialSupply;
        InitialSupply = initialSupply;
        Owner = owner;
        _syncHolder(msg.sender);
    }

    function _syncHolder(address holder) internal {
        holders[holder] = HolderAccounting({
            bondTokens: balanceOfBondTokens[holder],
            ethWithdrawnInt: ETHWithdrawnInt[holder],
            ethWithdrawnPrin: ETHWithdrawnPrin[holder]
        });
    }

    receive() external payable {}
}
