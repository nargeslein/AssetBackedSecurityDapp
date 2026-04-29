// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./SmartLoan.sol";
import "./TimeSim.sol";

/*
This contract should not be considered as a part of the Securitization contracts
Its merely a tool to facilitate creation and tracking of loans and therefore
only contains the most basic functionalites
*/
contract Bank {
    uint256 public LoansNumber;
    address public BankDirector;
    address public TmpLoanAddress;
    address public TimeAddress;
    address public Securitization;
    mapping(address => address) public AccountsToLoans;
    address[] public Loans;
    TimeSim public Time;
    SmartLoan public TmpLoan;

    modifier OnlyDirector() {
        require(msg.sender == BankDirector, "Bank: only director");
        _;
    }

    constructor() {
        Time = new TimeSim();
        TimeAddress = address(Time);
        BankDirector = msg.sender;
    }

    function SetSecuritization(address sfc) public {
        Securitization = sfc;
    }

    function GetLoanAddress() public view returns (address) {
        return AccountsToLoans[msg.sender];
    }

    function getLoans() public view returns (address[] memory) {
        return Loans;
    }

    function NewLoan(
        address _Borrower,
        uint256 _Balance,
        uint256 _InterestRateBPS,
        uint256 _TermMonths
    ) public OnlyDirector returns (address) {
        TmpLoan = new SmartLoan(address(this), _Balance, _InterestRateBPS, _TermMonths, TimeAddress);
        TmpLoanAddress = address(TmpLoan);
        AccountsToLoans[_Borrower] = TmpLoanAddress;
        Loans.push(TmpLoanAddress);
        LoansNumber++;
        return TmpLoanAddress;
    }
}
