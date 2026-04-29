// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./AssetLedger.sol";
import "./Escrow.sol";
import "./SFContract.sol";
import "./SmartLoan.sol";
import "./TimeSim.sol";

contract Pool {
    /*
    This contract is a testing helper for deploying a small pool and exercising
    the securitization flow.
    */

    struct PoolInputs {
        uint256 reserve;
        uint256 classAInitialBal;
        uint256 classAIntBPS;
        uint256 classBInitialBal;
        uint256 classBIntBPS;
        uint256 numberOfLoans;
        uint256 originalBal1;
        uint256 int1;
        uint256 term1;
        uint256 originalBal2;
        uint256 int2;
        uint256 term2;
    }

    address public Owner;
    address public PoolAddress;
    address public Loan1Address;
    address public Loan2Address;
    address public TimeAddress;
    address public SFCAddress;
    address public EscrowAddress;
    address public LedgerAddress;

    uint256 public Reserve = 200000;
    uint256 public InvestmentPeriodEnds;

    uint256 public ClassAInitialBal = 10000000;
    uint256 public ClassAIntBPS = 1000;
    uint256 public ClassBInitialBal = 10000000;
    uint256 public ClassBIntBPS = 1000;

    uint256 public NumberOfLoans = 2;
    uint256 public OriginalBal1 = 10000000;
    uint256 public Int1 = 1000;
    uint256 public Term1 = 12;

    uint256 public OriginalBal2 = 10000000;
    uint256 public Int2 = 1000;
    uint256 public Term2 = 12;

    PoolInputs public inputs;

    SmartLoan public Loan1;
    SmartLoan public Loan2;
    TimeSim public Time;
    SFContract public SFC;

    constructor() {
        Owner = address(this);
        Time = new TimeSim();
        TimeAddress = address(Time);
        InvestmentPeriodEnds = Time.Now() + 10 days;
        PoolAddress = msg.sender;
        _syncInputs();
    }

    function DeployLoans() public {
        Loan1 = new SmartLoan(Owner, OriginalBal1, Int1, Term1, TimeAddress);
        Loan1Address = address(Loan1);

        Loan2 = new SmartLoan(Owner, OriginalBal2, Int2, Term2, TimeAddress);
        Loan2Address = address(Loan2);
    }

    function NewOwner() public returns (address[3] memory) {
        Loan1.Transfer(LedgerAddress);
        Loan2.Transfer(LedgerAddress);
        return [Loan1Address, Loan2Address, LedgerAddress];
    }

    function Pay() public payable {
        uint256 half = msg.value / 2;
        Loan1.PayIn{value: half}();
        Loan2.PayIn{value: msg.value - half}();
    }

    function DeploySFContract() public returns (address) {
        address[2] memory loanAddresses = [Loan1Address, Loan2Address];
        SFC = new SFContract(
            loanAddresses,
            OriginalBal1 + OriginalBal2,
            NumberOfLoans,
            ClassAInitialBal,
            ClassAIntBPS,
            ClassBInitialBal,
            ClassBIntBPS,
            Reserve,
            InvestmentPeriodEnds,
            Owner,
            Owner,
            Owner,
            PoolAddress,
            TimeAddress
        );
        SFCAddress = address(SFC);
        return SFCAddress;
    }

    function GetEscrowLedgerAddress() public {
        EscrowAddress = SFC.EscrowAddress();
        LedgerAddress = SFC.AssetLedgerAddress();
    }

    function EscrowGiveLedgerAddrestoEscrow() public {
        Escrow(payable(EscrowAddress)).SetLedger(LedgerAddress);
    }

    function LedgerCheckPool() public {
        AssetLedger(payable(LedgerAddress)).PooTransferred();
    }

    function EscrowInvestorPaySetValA() public payable {
        Escrow(payable(EscrowAddress)).InvestorPayInA{value: ClassAInitialBal}();
    }

    function EscrowInvestorPaySetValB() public payable {
        Escrow(payable(EscrowAddress)).InvestorPayInB{value: ClassAInitialBal}();
    }

    function EscrowPayereserve() public payable returns (uint256) {
        Escrow(payable(EscrowAddress)).PayReserve{value: ClassAInitialBal}();
        return Escrow(payable(EscrowAddress)).ReserveRequired();
    }

    function EscrowTrustedParty() public {
        Escrow(payable(EscrowAddress)).PoolValid();
    }

    function EscrowPoolTransferr() public {
        Escrow(payable(EscrowAddress)).PoolTransfer();
    }

    function EscrowCheckState() public {
        Escrow(payable(EscrowAddress)).CheckState();
    }

    function _syncInputs() private {
        inputs = PoolInputs({
            reserve: Reserve,
            classAInitialBal: ClassAInitialBal,
            classAIntBPS: ClassAIntBPS,
            classBInitialBal: ClassBInitialBal,
            classBIntBPS: ClassBIntBPS,
            numberOfLoans: NumberOfLoans,
            originalBal1: OriginalBal1,
            int1: Int1,
            term1: Term1,
            originalBal2: OriginalBal2,
            int2: Int2,
            term2: Term2
        });
    }

    receive() external payable {}
}
