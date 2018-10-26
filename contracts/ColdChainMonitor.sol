pragma solidity ^0.4.24;

contract ERC20 {
    // Basic token features: book of balances and transfer
    uint public totalSupply = 0;
    mapping (address => uint256) public balanceOf;
    function transfer(address to, uint tokens) public returns (bool success);

    // Advanced features: An account can approve another account to spend its funds
    mapping(address => mapping (address => uint256)) public allowance;
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

contract ColdChainMonitor {

    event OrderAccepted(int temperatureLimit);
    event ShipmentArrived();

    ERC20 public token;
    address public canvas;
    mapping (address => uint) credit;

    int tLimit;
    uint deadline;
    uint payment;
    uint tPenalty;
    uint timePenalty;

    address public customer;
    address public serviceProvider;

    constructor(
        ERC20 tokenAddress,
        address canvasAddress,
        int temperatureLimit,
        uint deadlineTimestamp,
        uint paymentTokenWei,
        uint temperaturePenaltyTokenWei,
        uint overtimePenaltyTokenWei
    ) public {
        customer = msg.sender;
        token = ERC20(tokenAddress);
        canvas = canvasAddress;
        tLimit = temperatureLimit;
        deadline = deadlineTimestamp;
        payment = paymentTokenWei;
        tPenalty = temperaturePenaltyTokenWei;
        timePenalty = overtimePenaltyTokenWei;
    }

    /** Check that customer has given the allowance to this contract to process the payment */
    function isReady() public view returns (bool) {
        return token.allowance(customer, this) >= payment;
    }

    /** Remember to give allowance for stake first! */
    function acceptOrder() public {
        serviceProvider = msg.sender;
        require(token.transferFrom(customer, this, payment), "Payment failed. Has customer given allowance?");
        emit OrderAccepted(tLimit);
    }

    function shipmentArrived() public {
        require(msg.sender == customer, "Only customer is allowed to call this!");
        emit ShipmentArrived();
    }

    function payout(uint overageSum) public {
        require(msg.sender == canvas, "Only Streamr canvas is allowed to call this!");
        uint deductions = overageSum * tPenalty;
        if (now > deadline) {
            deductions += (now - deadline) * timePenalty;
        }
        if (deductions > payment) {
            credit[customer] += payment;
        } else {
            credit[customer] += deductions;
            credit[serviceProvider] += payment - deductions;
        }
    }

    function withdraw() public {
        uint amount = credit[msg.sender];
        require(amount > 0, "Nothing to withdraw");
        credit[msg.sender] = 0;
        require(token.transfer(msg.sender, amount), "Withdraw failed");
    }
}
