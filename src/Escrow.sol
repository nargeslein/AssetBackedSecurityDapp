// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./AssetLedger.sol";
import "./TimeSim.sol";

contract Escrow {
    /*
    The Escrow contract coordinates funding, reserve receipt, pool transfer, and
    third-party validation before the securitization can become active.
    */

    struct State {
        bool InvestorFundsReceivedA;
        bool InvestorFundsReceivedB;
        bool PoolReceived;
        bool ReserveReceived;
        bool ThirdPartyPoolValidation;
        bool FundingPeriodOver;
        bool Success;
        bool Fail;
    }

    State public CurrentState;
    bool[8] public currentState;

    mapping(address => uint256) public BalancesA;
    mapping(address => uint256) public BalancesB;

    uint256 public RequiredFundsA;
    uint256 public RequiredFundsB;
    uint256 public ReceivedFundsA;
    uint256 public ReceivedFundsB;
    uint256 public ReserveRequired;
    uint256 public ReserveReceived;
    uint256 public InvestmentPeriodEnd;

    address public TrustedParty;
    address public Owner;
    address public Originator;
    address public WaterFall;
    address public Ledger;

    address public TimeAddress;
    TimeSim public Time;

    bool public WaterFallSet = false;
    bool public LedgerSet = false;

    modifier OnlyFunding() {
        require(!CurrentState.FundingPeriodOver, "Escrow: funding over");
        _;
    }

    modifier OnlyFinalSuccess() {
        require(CurrentState.Success, "Escrow: not successful");
        _;
    }

    modifier OnlyFinalFail() {
        require(CurrentState.Fail, "Escrow: not failed");
        _;
    }

    modifier OnlyUntilAFull() {
        require(!CurrentState.InvestorFundsReceivedA, "Escrow: class A full");
        _;
    }

    modifier OnlyUntilBFull() {
        require(!CurrentState.InvestorFundsReceivedB, "Escrow: class B full");
        _;
    }

    modifier OnlyOwner() {
        require(msg.sender == Owner, "Escrow: only owner");
        _;
    }

    constructor(
        uint256 requiredFundsA,
        uint256 requiredFundsB,
        uint256 reserveRequired,
        uint256 investmentPeriodEnd,
        address trustedParty,
        address owner,
        address originator,
        address time
    ) {
        RequiredFundsA = requiredFundsA;
        RequiredFundsB = requiredFundsB;
        ReserveRequired = reserveRequired;
        InvestmentPeriodEnd = investmentPeriodEnd;
        TrustedParty = trustedParty;
        Owner = owner;
        TimeAddress = time;
        Time = TimeSim(TimeAddress);
        Originator = originator;
    }

    function PoolTransfer() public OnlyFunding returns (bool) {
        CurrentState.PoolReceived = AssetLedger(payable(Ledger)).PoolTransfer();
        return CurrentState.PoolReceived;
    }

    function SetWaterFallAddress(address waterFallAddress) public OnlyOwner {
        require(!WaterFallSet, "Escrow: waterfall already set");
        WaterFall = waterFallAddress;
        WaterFallSet = true;
    }

    function SetLedger(address ledger) public {
        require(!LedgerSet, "Escrow: ledger already set");
        Ledger = ledger;
        LedgerSet = true;
    }

    function InvestorPayInA() public payable OnlyFunding OnlyUntilAFull {
        require(msg.value <= RequiredFundsA - ReceivedFundsA, "Escrow: class A overfunded");

        BalancesA[msg.sender] += msg.value;
        ReceivedFundsA += msg.value;

        if (RequiredFundsA - ReceivedFundsA == 0) {
            CurrentState.InvestorFundsReceivedA = true;
        }
    }

    function InvestorPayInB() public payable OnlyFunding OnlyUntilBFull {
        require(msg.value <= RequiredFundsB - ReceivedFundsB, "Escrow: class B overfunded");

        BalancesB[msg.sender] += msg.value;
        ReceivedFundsB += msg.value;

        if (RequiredFundsB - ReceivedFundsB == 0) {
            CurrentState.InvestorFundsReceivedB = true;
        }
    }

    function GetInvestorsBalanceA(address investorAddress) public view OnlyFinalSuccess returns (uint256) {
        return BalancesA[investorAddress];
    }

    function GetInvestorsBalanceB(address investorAddress) public view OnlyFinalSuccess returns (uint256) {
        return BalancesB[investorAddress];
    }

    function RevertInvestmentInvestor() public OnlyFinalFail {
        uint256 amountA = BalancesA[msg.sender];
        uint256 amountB = BalancesB[msg.sender];

        BalancesA[msg.sender] = 0;
        BalancesB[msg.sender] = 0;

        if (amountA > 0) {
            (bool successA,) = payable(msg.sender).call{value: amountA}("");
            require(successA, "Escrow: class A refund failed");
        }

        if (amountB > 0) {
            (bool successB,) = payable(msg.sender).call{value: amountB}("");
            require(successB, "Escrow: class B refund failed");
        }
    }

    function RevertInvestmentORiginator() public OnlyFinalFail {
        AssetLedger(payable(Ledger)).SendbackPool(Originator);
        uint256 reserve = ReserveReceived;
        ReserveReceived = 0;

        (bool success,) = payable(Originator).call{value: reserve}("");
        require(success, "Escrow: reserve refund failed");
    }

    function ReturnReserve() public OnlyFinalFail {
        uint256 reserve = ReserveReceived;
        ReserveReceived = 0;

        (bool success,) = payable(Originator).call{value: reserve}("");
        require(success, "Escrow: reserve return failed");
    }

    function CheckTime() public {
        if (Time.Now() > InvestmentPeriodEnd) {
            CurrentState.FundingPeriodOver = true;
        }
    }

    function CheckState() public returns (bool[8] memory) {
        CheckTime();

        currentState[0] = CurrentState.InvestorFundsReceivedA;
        currentState[1] = CurrentState.InvestorFundsReceivedB;
        currentState[2] = CurrentState.PoolReceived;
        currentState[3] = CurrentState.ReserveReceived;
        currentState[4] = CurrentState.ThirdPartyPoolValidation;
        currentState[5] = CurrentState.FundingPeriodOver;

        if (currentState[0] && currentState[1] && currentState[2] && currentState[3] && currentState[4]) {
            CurrentState.Success = true;
        }

        if ((!currentState[0] || !currentState[1] || !currentState[2] || !currentState[3] || !currentState[4]) && currentState[5]) {
            CurrentState.Fail = true;
        }

        currentState[6] = CurrentState.Success;
        currentState[7] = CurrentState.Fail;

        return currentState;
    }

    function OriginatorWithdrawFunds() public OnlyFinalSuccess {
        uint256 amount = ReceivedFundsA + ReceivedFundsB;
        ReceivedFundsA = 0;
        ReceivedFundsB = 0;

        (bool success,) = payable(Originator).call{value: amount}("");
        require(success, "Escrow: originator transfer failed");
    }

    function PayReserve() public payable OnlyFunding {
        ReserveReceived += msg.value;
        if (ReserveReceived >= ReserveRequired) {
            CurrentState.ReserveReceived = true;
        }
    }

    function SendReserve(address waterFallAddress) public OnlyFinalSuccess OnlyOwner {
        uint256 reserve = ReserveReceived;
        ReserveReceived = 0;

        (bool success,) = payable(waterFallAddress).call{value: reserve}("");
        require(success, "Escrow: reserve transfer failed");
    }

    function PoolValid() public {
        if (msg.sender == TrustedParty) {
            CurrentState.ThirdPartyPoolValidation = true;
        }
    }

    receive() external payable {}
}
