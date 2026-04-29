// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./AssetLedger.sol";

contract WaterFall {
    /*
    The WaterFall contract receives cashflow information from the AssetLedger and
    allocates available funds to Class A and Class B bonds.
    */

    struct Class {
        uint256 OrigBal;
        uint256 CurrentBal;
        uint256 InterestBPS;
        uint256 InterestDue;
        uint256 InterestAvailable;
        uint256 PrincipalAvailable;
    }

    Class public ClassA;
    Class public ClassB;

    struct Pool {
        uint256 IntFromPool;
        uint256 PrinFromPool;
        uint256 RecovFromPool;
        uint256 DefaultFromPool;
    }

    Pool public PoolA;

    uint256 public ReserveFundTarget;
    uint256 public ReserveFundAvailable;
    uint256 public AvailableFunds;
    uint256 public ExcessSpread;

    AssetLedger public AssetsLedgerA;

    address public AssetsAddress;
    address public LiabilitiesAddressA;
    address public LiabilitiesAddressB;
    address public ExcessFundsAddress;
    address public OwnerAddress;

    uint256[4] public SendFundsOutput;

    modifier OnlyOwner() {
        require(msg.sender == OwnerAddress, "WaterFall: only owner");
        _;
    }

    constructor(
        uint256 reserveAmount,
        uint256 classAInitialBal,
        uint256 classAInterestRateBPS,
        uint256 classBInitialBal,
        uint256 classBInterestRateBPS,
        address assetsAddress,
        address liabilitiesAddressA,
        address liabilitiesAddressB,
        address ownerAddress
    ) {
        AssetsAddress = assetsAddress;
        AssetsLedgerA = AssetLedger(payable(assetsAddress));
        LiabilitiesAddressA = liabilitiesAddressA;
        LiabilitiesAddressB = liabilitiesAddressB;
        OwnerAddress = ownerAddress;

        ClassA = Class({
            OrigBal: classAInitialBal,
            CurrentBal: classAInitialBal,
            InterestBPS: classAInterestRateBPS,
            InterestDue: classAInitialBal * classAInterestRateBPS / 120000,
            InterestAvailable: 0,
            PrincipalAvailable: 0
        });

        ClassB = Class({
            OrigBal: classBInitialBal,
            CurrentBal: classBInitialBal,
            InterestBPS: classBInterestRateBPS,
            InterestDue: classBInitialBal * classBInterestRateBPS / 120000,
            InterestAvailable: 0,
            PrincipalAvailable: 0
        });

        ReserveFundTarget = reserveAmount;
        ReserveFundAvailable = reserveAmount;
    }

    function SendFundsA() public returns (uint256[2] memory) {
        uint256 intavail = ClassA.InterestAvailable;
        uint256 prinavail = ClassA.PrincipalAvailable;

        require(msg.sender == LiabilitiesAddressA, "WaterFall: only class A");

        ClassA.InterestAvailable = 0;
        ClassA.PrincipalAvailable = 0;

        (bool success,) = payable(LiabilitiesAddressA).call{value: intavail + prinavail}("");
        require(success, "WaterFall: class A transfer failed");

        return [intavail, prinavail];
    }

    function SendFundsB() public returns (uint256[2] memory) {
        uint256 intavail = ClassB.InterestAvailable;
        uint256 prinavail = ClassB.PrincipalAvailable;

        require(msg.sender == LiabilitiesAddressB, "WaterFall: only class B");

        ClassB.InterestAvailable = 0;
        ClassB.PrincipalAvailable = 0;

        (bool success,) = payable(LiabilitiesAddressB).call{value: intavail + prinavail}("");
        require(success, "WaterFall: class B transfer failed");

        return [intavail, prinavail];
    }

    function SendFundsExcessSpread() public OnlyOwner returns (uint256) {
        uint256 xsavail = ExcessSpread;
        ExcessSpread = 0;

        (bool success,) = payable(LiabilitiesAddressB).call{value: xsavail}("");
        require(success, "WaterFall: excess transfer failed");

        return xsavail;
    }

    function Withdraw() public {
        SendFundsOutput = AssetsLedgerA.SendFunds();
        AvailableFunds = SendFundsOutput[0] + SendFundsOutput[1] + SendFundsOutput[2] + ReserveFundAvailable;
    }

    function CalcWaterFall() public OnlyOwner {
        Withdraw();

        if (AvailableFunds > ClassA.InterestDue) {
            AvailableFunds -= ClassA.InterestDue;
            ClassA.InterestAvailable = ClassA.InterestDue;
        } else {
            ClassA.InterestAvailable = AvailableFunds;
            AvailableFunds = 0;
        }

        if (AvailableFunds > ClassB.InterestDue) {
            AvailableFunds -= ClassB.InterestDue;
            ClassB.InterestAvailable = ClassB.InterestDue;
        } else {
            ClassB.InterestAvailable = AvailableFunds;
            AvailableFunds = 0;
        }

        if (AvailableFunds > ReserveFundTarget) {
            AvailableFunds -= ReserveFundTarget;
            ReserveFundAvailable = ReserveFundTarget;
        } else {
            ReserveFundAvailable = AvailableFunds;
            AvailableFunds = 0;
        }

        if (AvailableFunds > ClassA.CurrentBal) {
            AvailableFunds -= ClassA.CurrentBal;
            ClassA.PrincipalAvailable = ClassA.CurrentBal;
            ClassA.CurrentBal = 0;
        } else {
            ClassA.PrincipalAvailable = AvailableFunds;
            AvailableFunds = 0;
            ClassA.CurrentBal -= ClassA.PrincipalAvailable;
        }

        if (AvailableFunds > ClassB.CurrentBal) {
            AvailableFunds -= ClassB.CurrentBal;
            ClassB.PrincipalAvailable = ClassB.CurrentBal;
            ClassB.CurrentBal = 0;
        } else {
            ClassB.PrincipalAvailable = AvailableFunds;
            AvailableFunds = 0;
            ClassB.CurrentBal -= ClassB.PrincipalAvailable;
        }

        ExcessSpread = AvailableFunds;
        AvailableFunds = 0;

        CalculateInterestDue();
    }

    function CalculateInterestDue() private {
        ClassA.InterestDue = ClassA.CurrentBal * ClassA.InterestBPS / 120000;
        ClassB.InterestDue = ClassB.CurrentBal * ClassB.InterestBPS / 120000;
    }

    receive() external payable {}
}
