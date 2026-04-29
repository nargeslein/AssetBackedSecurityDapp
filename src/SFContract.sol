// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./AssetLedger.sol";
import "./BondA.sol";
import "./BondB.sol";
import "./Escrow.sol";
import "./TimeSim.sol";
import "./WaterFall.sol";

contract SFContract {
    /*
    Central scheduler/orchestrator for the securitization transaction.
    */

    struct State {
        bool LedgerAndEscrowCreated;
        bool EscrowSuccess;
        bool EscrowFail;
        bool BondsAndWaterFallCreated;
    }

    State public SecuritisationState;
    mapping(address => bool) public InvestorWithdrawn;

    bool[8] public EscrowState;

    uint256 public OriginalPoolBalance;
    uint256 public NumberOfLoans;
    uint256 public ClassAInitialBal;
    uint256 public ClassAInterestRateBPS;
    uint256 public ClassBInitialBal;
    uint256 public ClassBInterestRateBPS;
    uint256 public ReserveRequired;
    uint256 public InvestmentPeriodEnd;

    uint256[8] public ReadNumbersOutput;

    address[2] public AccountAddresses;
    address public TrustedParty;
    address public Owner;
    address public Originator;
    address public ExcessFundsReceiver;
    address public PoolAdd;

    address[13] public ReadAddressesOutput;

    address public EscrowAddress;
    address public AssetLedgerAddress;
    address public WaterFallAddress;
    address public ClassABondAddress;
    address public ClassBBondAddress;
    address public TimeAddress;

    Escrow public EscrowAccount;
    AssetLedger public AssetLedgerAccount;
    WaterFall public WaterFallAccount;
    BondA public ClassABond;
    BondB public ClassBBond;
    TimeSim public Time;

    modifier OnlyAfterEscrowLedgerCreated() {
        require(SecuritisationState.LedgerAndEscrowCreated, "SFContract: escrow/ledger not created");
        _;
    }

    modifier OnlyAfterEscrowSuccess() {
        require(SecuritisationState.EscrowSuccess, "SFContract: escrow not successful");
        _;
    }

    modifier NotAfterEscrowFail() {
        require(!SecuritisationState.EscrowFail, "SFContract: escrow failed");
        _;
    }

    modifier OnlyAfterBondsAndWaterFall() {
        require(SecuritisationState.BondsAndWaterFallCreated, "SFContract: bonds/waterfall not created");
        _;
    }

    constructor(
        address[2] memory accountAddresses,
        uint256 originalPoolBalance,
        uint256 numberOfLoans,
        uint256 classAInitialBal,
        uint256 classAInterestRateBPS,
        uint256 classBInitialBal,
        uint256 classBInterestRateBPS,
        uint256 reserveRequired,
        uint256 investmentPeriodEnd,
        address trustedParty,
        address originator,
        address excessFundsReceiver,
        address pool,
        address time
    ) {
        TimeAddress = time;
        Time = TimeSim(TimeAddress);
        AccountAddresses = accountAddresses;
        OriginalPoolBalance = originalPoolBalance;
        NumberOfLoans = numberOfLoans;
        ClassAInitialBal = classAInitialBal;
        ClassAInterestRateBPS = classAInterestRateBPS;
        ClassBInitialBal = classBInitialBal;
        ClassBInterestRateBPS = classBInterestRateBPS;
        ReserveRequired = reserveRequired;
        InvestmentPeriodEnd = investmentPeriodEnd;
        TrustedParty = trustedParty;
        Owner = address(this);
        PoolAdd = pool;
        ExcessFundsReceiver = excessFundsReceiver;
        Originator = originator;
    }

    function CreateEscrowAndLedger(address escrowAddress, address ledgerAddress) public {
        require(!SecuritisationState.LedgerAndEscrowCreated, "SFContract: escrow/ledger already created");

        EscrowAccount = Escrow(payable(escrowAddress));
        AssetLedgerAccount = AssetLedger(payable(ledgerAddress));
        EscrowAddress = escrowAddress;
        AssetLedgerAddress = ledgerAddress;
        SecuritisationState.LedgerAndEscrowCreated = true;
    }

    function CheckEscrow() public OnlyAfterEscrowLedgerCreated {
        EscrowState = EscrowAccount.CheckState();

        if (EscrowState[6]) {
            SecuritisationState.EscrowSuccess = true;
        }
        if (EscrowState[7]) {
            SecuritisationState.EscrowFail = true;
        }
    }

    function CreateBondsAndWaterFall(
        address AbondsAddress,
        address BbondsAddress,
        address waterFallAddress
    ) public OnlyAfterEscrowLedgerCreated NotAfterEscrowFail {
        require(!SecuritisationState.BondsAndWaterFallCreated, "SFContract: bonds/waterfall already created");

        ClassABond = BondA(payable(AbondsAddress));
        ClassABondAddress = AbondsAddress;

        ClassBBond = BondB(payable(BbondsAddress));
        ClassBBondAddress = BbondsAddress;

        WaterFallAccount = WaterFall(payable(waterFallAddress));
        WaterFallAddress = waterFallAddress;

        AssetLedgerAccount.WaterFallset(WaterFallAddress);
        ClassABond.SetWaterFall(WaterFallAddress);
        ClassBBond.SetWaterFall(WaterFallAddress);
        EscrowAccount.SendReserve(WaterFallAddress);
        SecuritisationState.BondsAndWaterFallCreated = true;
    }

    function SendMeMyBonds() public OnlyAfterBondsAndWaterFall OnlyAfterEscrowSuccess {
        require(!InvestorWithdrawn[msg.sender], "SFContract: already withdrawn");

        ClassABond.transfer(msg.sender, EscrowAccount.GetInvestorsBalanceA(msg.sender));
        ClassBBond.transfer(msg.sender, EscrowAccount.GetInvestorsBalanceB(msg.sender));

        InvestorWithdrawn[msg.sender] = true;
    }

    function MoveFundsFromLedgerToWaterfall() public OnlyAfterBondsAndWaterFall OnlyAfterEscrowSuccess {
        WaterFallAccount.CalcWaterFall();
    }

    function MoveFundsFromPoolIntoLedger() public OnlyAfterBondsAndWaterFall OnlyAfterEscrowSuccess returns (uint256[12] memory) {
        return AssetLedgerAccount.WithdrawDueLoans();
    }

    function MoveFundsIntoBonds() public OnlyAfterBondsAndWaterFall OnlyAfterEscrowSuccess {
        ClassABond.PayIn();
        ClassBBond.PayIn();
    }

    function ReadState() public view returns (bool[4] memory) {
        return [
            SecuritisationState.LedgerAndEscrowCreated,
            SecuritisationState.EscrowSuccess,
            SecuritisationState.EscrowFail,
            SecuritisationState.BondsAndWaterFallCreated
        ];
    }

    function ReadNumbers() public view returns (uint256[8] memory readNumbersOutput) {
        readNumbersOutput[0] = OriginalPoolBalance;
        readNumbersOutput[1] = NumberOfLoans;
        readNumbersOutput[2] = ClassAInitialBal;
        readNumbersOutput[3] = ClassAInterestRateBPS;
        readNumbersOutput[4] = ClassBInitialBal;
        readNumbersOutput[5] = ClassBInterestRateBPS;
        readNumbersOutput[6] = ReserveRequired;
        readNumbersOutput[7] = InvestmentPeriodEnd;
    }

    function ReadAddresses() public view returns (address[13] memory readAddressesOutput) {
        readAddressesOutput[0] = AccountAddresses[0];
        readAddressesOutput[1] = AccountAddresses[1];
        readAddressesOutput[2] = TrustedParty;
        readAddressesOutput[3] = Owner;
        readAddressesOutput[4] = Originator;
        readAddressesOutput[5] = ExcessFundsReceiver;
        readAddressesOutput[6] = PoolAdd;
        readAddressesOutput[7] = EscrowAddress;
        readAddressesOutput[8] = AssetLedgerAddress;
        readAddressesOutput[9] = WaterFallAddress;
        readAddressesOutput[10] = ClassABondAddress;
        readAddressesOutput[11] = ClassBBondAddress;
        readAddressesOutput[12] = TimeAddress;
    }
}
