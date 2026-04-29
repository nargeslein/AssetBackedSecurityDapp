// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./SmartLoan.sol";
import "./TimeSim.sol";

contract AssetLedger {
    /*
    The asset ledger manages and keeps track of all SmartLoan contracts sold by
    the originator. The old implementation used many parallel fixed arrays; this
    version groups per-loan data in LoanInfo structs while preserving the legacy
    public arrays used by the old UI/tests.
    */

    struct LoanInfo {
        address accountAddress;
        uint256 originalBalance;
        uint256 currentBalance;
        uint256 lastPaymentDate;
        uint256 nextPaymentDate;
        uint256 intPaidIn;
        uint256 prinPaidIn;
        uint256 recoveriesPaidIn;
        uint256 overdueDays;
        bool defaulted;
    }

    LoanInfo[] public LoanLedger;

    address[2] public AccountAddress;
    uint256[2] public OBAL;
    uint256[2] public CBAL;
    uint256[2] public LastPaymentDate;
    uint256[2] public Nextpaymentdate;
    uint256[2] public IntpaidIn;
    uint256[2] public Prinpaidin;
    uint256[2] public RecoveriesPaidin;
    uint256[2] public OverdueDays;
    bool[2] public Default;
    uint256[10] public InitialLoaninfo;

    uint256 public PrincipalThisPeriod;
    uint256 public InterestThisPeriod;
    uint256 public RecoveriesThisPeriod;
    uint256 public DefaultThisPeriod;
    uint256[4] public PeriodicInfo;

    uint256 public PrincipalCum;
    uint256 public InterestCum;
    uint256 public RecoveriesCum;
    uint256 public DefaultCum;
    uint256 public LoansRepaid;
    uint256 public OriginalNumberOfLoans;
    uint256 public OriginalPoolBalance;
    uint256 public CurrentlPoolBalance;

    address public Controller;
    address public TimeAddress;
    address public WaterFall;
    address public ThisAddress;

    SmartLoan public Loan;
    TimeSim public Time;

    bool public PoolTransfer = false;
    bool public waterFallset = false;

    modifier OnlyController() {
        require(msg.sender == Controller, "AssetLedger: only controller");
        _;
    }

    modifier OnlyWaterFall() {
        require(msg.sender == WaterFall, "AssetLedger: only waterfall");
        _;
    }

    modifier IfPoolNotTransferred() {
        require(!PoolTransfer, "AssetLedger: pool already transferred");
        _;
    }

    constructor(
        address[2] memory accountAddresses,
        uint256 originalPoolBalance,
        uint256 numberOfLoans,
        address controller,
        address timeAddress
    ) {
        require(numberOfLoans <= accountAddresses.length, "AssetLedger: too many loans");

        TimeAddress = timeAddress;
        Time = TimeSim(timeAddress);
        Controller = controller;
        OriginalNumberOfLoans = numberOfLoans;
        AccountAddress = accountAddresses;
        OriginalPoolBalance = originalPoolBalance;
        CurrentlPoolBalance = originalPoolBalance;
        ThisAddress = address(this);

        for (uint256 i = 0; i < numberOfLoans; i++) {
            Nextpaymentdate[i] = block.timestamp - 1;
            LoanLedger.push(
                LoanInfo({
                    accountAddress: accountAddresses[i],
                    originalBalance: 0,
                    currentBalance: 0,
                    lastPaymentDate: 0,
                    nextPaymentDate: Nextpaymentdate[i],
                    intPaidIn: 0,
                    prinPaidIn: 0,
                    recoveriesPaidIn: 0,
                    overdueDays: 0,
                    defaulted: false
                })
            );
        }
    }

    function WaterFallset(address waterfallAddress) public OnlyController {
        require(!waterFallset, "AssetLedger: waterfall already set");
        WaterFall = waterfallAddress;
        waterFallset = true;
    }

    function PooTransferred() public returns (bool) {
        for (uint256 i = 0; i < OriginalNumberOfLoans; i++) {
            Loan = SmartLoan(payable(AccountAddress[i]));
            if (Loan.LenderAddress() != ThisAddress) {
                PoolTransfer = false;
                return PoolTransfer;
            }

            OBAL[i] = Loan.OriginalBalance();
            CBAL[i] = Loan.CurrentBalance();
            LoanLedger[i].originalBalance = OBAL[i];
            LoanLedger[i].currentBalance = CBAL[i];
        }

        PoolTransfer = true;
        return PoolTransfer;
    }

    function SendbackPool(address newLender) public OnlyController {
        for (uint256 i = 0; i < OriginalNumberOfLoans; i++) {
            Loan = SmartLoan(payable(AccountAddress[i]));
            Loan.Transfer(newLender);
        }
    }

    function GetLoans() public view returns (address[2] memory) {
        return AccountAddress;
    }

    function WithdrawDueLoans() public payable OnlyController returns (uint256[12] memory) {
        for (uint256 j = 0; j < OriginalNumberOfLoans; j++) {
            if (Time.Now() > Nextpaymentdate[j]) {
                Loan = SmartLoan(payable(AccountAddress[j]));
                InitialLoaninfo = Loan.WithdrawIntPrin();

                if (InitialLoaninfo[0] >= 180) {
                    RecoveriesPaidin[j] = InitialLoaninfo[4] + InitialLoaninfo[5];
                    RecoveriesThisPeriod += RecoveriesPaidin[j];
                    OverdueDays[j] = InitialLoaninfo[0];
                    if (InitialLoaninfo[0] == 180) {
                        DefaultThisPeriod += InitialLoaninfo[2];
                    }
                } else {
                    OverdueDays[j] = InitialLoaninfo[0];
                    CBAL[j] -= InitialLoaninfo[5];
                    LastPaymentDate[j] = Nextpaymentdate[j];
                    Nextpaymentdate[j] = block.timestamp + 30 days;
                    IntpaidIn[j] = InitialLoaninfo[4];
                    Prinpaidin[j] = InitialLoaninfo[5];

                    if (CBAL[j] == 0) {
                        LoansRepaid++;
                    }
                }

                PrincipalThisPeriod += Prinpaidin[j];
                InterestThisPeriod += IntpaidIn[j];
                PrincipalCum += Prinpaidin[j];
                InterestCum += IntpaidIn[j];
                RecoveriesCum += RecoveriesPaidin[j];
                CurrentlPoolBalance -= Prinpaidin[j];
                _syncLoanInfo(j);
            }
        }

        DefaultCum += DefaultThisPeriod;
        return [
            PrincipalThisPeriod,
            InterestThisPeriod,
            RecoveriesThisPeriod,
            DefaultThisPeriod,
            PrincipalCum,
            InterestCum,
            RecoveriesCum,
            DefaultCum,
            LoansRepaid,
            OriginalNumberOfLoans,
            OriginalPoolBalance,
            CurrentlPoolBalance
        ];
    }

    function SendFunds() public OnlyWaterFall returns (uint256[4] memory) {
        PeriodicInfo[0] = PrincipalThisPeriod;
        PeriodicInfo[1] = InterestThisPeriod;
        PeriodicInfo[2] = RecoveriesThisPeriod;
        PeriodicInfo[3] = DefaultThisPeriod;

        uint256 amount = PeriodicInfo[0] + PeriodicInfo[1] + PeriodicInfo[2];
        PrincipalThisPeriod = 0;
        InterestThisPeriod = 0;
        RecoveriesThisPeriod = 0;
        DefaultThisPeriod = 0;

        (bool success,) = payable(WaterFall).call{value: amount}("");
        require(success, "AssetLedger: transfer failed");

        return PeriodicInfo;
    }

    function _syncLoanInfo(uint256 index) private {
        LoanLedger[index] = LoanInfo({
            accountAddress: AccountAddress[index],
            originalBalance: OBAL[index],
            currentBalance: CBAL[index],
            lastPaymentDate: LastPaymentDate[index],
            nextPaymentDate: Nextpaymentdate[index],
            intPaidIn: IntpaidIn[index],
            prinPaidIn: Prinpaidin[index],
            recoveriesPaidIn: RecoveriesPaidin[index],
            overdueDays: OverdueDays[index],
            defaulted: Default[index]
        });
    }

    receive() external payable {}
}
