// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TimeSim.sol";

contract SmartLoan {
    /*
    The SmartLoan contract represents the loan which the originator grants to
    borrowers. It tracks a simple amortizing loan, accepts payments, and lets the
    current lender withdraw paid-in interest and principal.
    */

    struct LoanTerms {
        uint256 originalBalance;
        uint256 interestRateBasisPoints;
        uint256 originalTermMonths;
        uint256 monthlyInstallment;
    }

    struct LoanState {
        uint256 currentBalance;
        uint256 intPaidIn;
        uint256 prinPaidIn;
        uint256 remainingTermMonths;
        uint256 nextPaymentDate;
        uint256 paymentsMade;
        uint256 overdueDays;
        bool contractCurrent;
    }

    LoanTerms public terms;
    LoanState public loanState;

    uint256 public OriginalBalance;
    uint256 public CurrentBalance;
    uint256 public IntPaidIn;
    uint256 public PrinPaidIn;
    uint256 public MonthlyInstallment;
    uint256 public InterestRateBasisPoints;
    uint256 public OriginalTermMonths;
    uint256 public RemainingTermMonths;
    uint256 public NextPaymentDate;
    uint256 public PaymentsMade;
    uint256 public OverdueDays;

    uint256 public Now;
    uint256[120] public PaymentDates;

    bool public ContractCurrent = true;

    address public LenderAddress;
    address public TimeAddress;

    TimeSim public Time;

    modifier OnlyLender() {
        require(msg.sender == LenderAddress, "SmartLoan: only lender");
        _;
    }

    constructor(
        address lenderAddress,
        uint256 balance,
        uint256 interestRateBasisPoints,
        uint256 termMonths,
        address timeAddress
    ) {
        require(termMonths > 0 && termMonths <= PaymentDates.length, "SmartLoan: invalid term");

        LenderAddress = lenderAddress;
        TimeAddress = timeAddress;
        Time = TimeSim(timeAddress);

        OriginalBalance = balance;
        CurrentBalance = balance;
        InterestRateBasisPoints = interestRateBasisPoints;
        OriginalTermMonths = termMonths;
        RemainingTermMonths = termMonths;

        uint256 monthlyInstallment1 =
            (interestRateBasisPoints * (10000 * termMonths + interestRateBasisPoints) ** termMonths) / 1000000;
        uint256 monthlyInstallment2 = (
            (10000 * termMonths + interestRateBasisPoints) ** termMonths * 10000 * termMonths
                - 10000 ** (termMonths + 1) * termMonths ** (termMonths + 1)
        ) / 1000000;

        if (monthlyInstallment2 != 0) {
            MonthlyInstallment = balance * monthlyInstallment1 / (monthlyInstallment2 + 1);
        }

        for (uint256 k = 0; k < termMonths; k++) {
            PaymentDates[k] = block.timestamp + (k + 1) * 30 days;
        }

        NextPaymentDate = PaymentDates[0];
        _syncStructs();
    }

    function Read() public view returns (uint256[11] memory) {
        return [
            OverdueDays,
            OriginalBalance,
            CurrentBalance,
            NextPaymentDate,
            IntPaidIn,
            PrinPaidIn,
            MonthlyInstallment,
            InterestRateBasisPoints,
            OriginalTermMonths,
            RemainingTermMonths,
            address(this).balance
        ];
    }

    function ReadTime() public view returns (address) {
        return TimeAddress;
    }

    function ContractCurrentUpdate() private returns (uint256) {
        PaymentsMade = OriginalTermMonths - RemainingTermMonths;
        NextPaymentDate = PaymentDates[PaymentsMade];

        if (Time.Now() > NextPaymentDate && RemainingTermMonths != 0) {
            ContractCurrent = false;
            OverdueDays = (Time.Now() - NextPaymentDate) / 1 days;
            _syncStructs();
            return OverdueDays;
        }

        OverdueDays = 0;
        ContractCurrent = true;
        _syncStructs();
        return OverdueDays;
    }

    function Transfer(address NewLender) public OnlyLender {
        LenderAddress = NewLender;
    }

    function PayIn() public payable {
        require(msg.value == MonthlyInstallment, "SmartLoan: installment mismatch");
        require(RemainingTermMonths != 0, "SmartLoan: loan repaid");

        RemainingTermMonths--;
        uint256 principal = CalculatePVOfInstallment(OriginalTermMonths - RemainingTermMonths);
        uint256 interest = MonthlyInstallment - principal;
        CurrentBalance -= principal;
        IntPaidIn += interest;
        PrinPaidIn += principal;

        ContractCurrentUpdate();
    }

    function WithdrawIntPrin() public OnlyLender returns (uint256[10] memory) {
        uint256 intPaidIn = IntPaidIn;
        uint256 prinPaidIn = PrinPaidIn;

        OverdueDays = ContractCurrentUpdate();

        uint256 amount = IntPaidIn + PrinPaidIn;
        IntPaidIn = 0;
        PrinPaidIn = 0;
        _syncStructs();

        (bool success,) = payable(LenderAddress).call{value: amount}("");
        require(success, "SmartLoan: transfer failed");

        return [
            OverdueDays,
            OriginalBalance,
            CurrentBalance,
            NextPaymentDate,
            intPaidIn,
            prinPaidIn,
            MonthlyInstallment,
            InterestRateBasisPoints,
            OriginalTermMonths,
            RemainingTermMonths
        ];
    }

    function CalculatePVOfInstallment(uint256 periods) public view returns (uint256) {
        return MonthlyInstallment * (10000 * OriginalTermMonths) ** periods
            / (10000 * OriginalTermMonths + InterestRateBasisPoints) ** periods;
    }

    function _syncStructs() private {
        terms = LoanTerms({
            originalBalance: OriginalBalance,
            interestRateBasisPoints: InterestRateBasisPoints,
            originalTermMonths: OriginalTermMonths,
            monthlyInstallment: MonthlyInstallment
        });

        loanState = LoanState({
            currentBalance: CurrentBalance,
            intPaidIn: IntPaidIn,
            prinPaidIn: PrinPaidIn,
            remainingTermMonths: RemainingTermMonths,
            nextPaymentDate: NextPaymentDate,
            paymentsMade: PaymentsMade,
            overdueDays: OverdueDays,
            contractCurrent: ContractCurrent
        });
    }

    receive() external payable {}
}
