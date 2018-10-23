pragma solidity ^0.4.24;

import "../node_modules/openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

/**
 * More "real-world" type of a ColdChainMonitor contract that can handle many orders simultaneously
 */
contract ColdChainMonitorComplex {

    event OrderPlaced(
        uint orderId,
        uint temperatureLimit,
        uint deadlineTimestamp,
        uint paymentTokenWei,
        uint temperaturePenaltyTokenWei,
        uint overtimePenaltyTokenWeiPerSecond
    );
    event OrderAccepted(uint orderId, uint temperatureLimit);
    event ShipmentArrived(uint orderId);

    struct Order {
        address customer;
        address serviceProvider;
        uint temperatureLimit;
        uint deadlineTimestamp;
        uint paymentTokenWei;
        uint temperaturePenaltyTokenWei;
        uint overtimePenaltyTokenWeiPerSecond;
    }

    ERC20 public token;
    uint public stakeTokenWei = 0.1 ether;
    address public canvas;
    mapping (address => uint) credit;
    Order[] public orders;

    constructor(ERC20 tokenAddress, address canvasAddress) public {
        token = ERC20(tokenAddress);
        canvas = canvasAddress;
    }

    /** remember to give allowance for payment first! */
    function placeOrder(
        uint temperatureLimit,
        uint deadlineTimestamp,
        uint paymentTokenWei,
        uint temperaturePenaltyTokenWei,
        uint overtimePenaltyTokenWeiPerSecond
    ) public {
        emit OrderPlaced(orders.length, temperatureLimit, deadlineTimestamp, paymentTokenWei, temperaturePenaltyTokenWei, overtimePenaltyTokenWeiPerSecond);
        orders.push(Order(msg.sender, 0x0, temperatureLimit, deadlineTimestamp, paymentTokenWei, temperaturePenaltyTokenWei, overtimePenaltyTokenWeiPerSecond));
    }

    /** Check that customer has given the allowance to this contract to process the payment */
    function isReady(uint orderId) public view returns (bool) {
        Order storage o = orders[orderId];
        return token.allowance(o.customer, this) >= o.paymentTokenWei && token.allowance(msg.sender, this) >= stakeTokenWei;
    }

    /** Remember to give allowance for stake first! */
    function acceptOrder(uint orderId) public {
        Order storage o = orders[orderId];
        require(o.customer != 0x0, "Order not found");
        o.serviceProvider = msg.sender;
        require(token.transferFrom(o.customer, this, o.paymentTokenWei), "Payment failed. Has customer given allowance?");
        require(token.transferFrom(o.serviceProvider, this, stakeTokenWei), "Staking failed. Have you given allowance?");
        emit OrderAccepted(orderId, o.temperatureLimit);
    }

    function shipmentArrived(uint orderId) public {
        Order storage o = orders[orderId];
        require(o.customer != 0x0, "Order not found");
        require(msg.sender == o.customer, "Only customer is allowed to call this!");
        emit ShipmentArrived(orderId);
    }

    function payout(uint orderId, uint overageSum) public {
        require(msg.sender == canvas, "Only Streamr canvas is allowed to call this!");
        Order storage o = orders[orderId];
        require(o.customer != 0x0, "Order not found");
        uint deductions = overageSum * o.temperaturePenaltyTokenWei;
        if (now > o.deadlineTimestamp) {
            deductions += (now - o.deadlineTimestamp) * o.overtimePenaltyTokenWeiPerSecond;
        }
        if (deductions > o.paymentTokenWei) {
            credit[o.customer] += o.paymentTokenWei;
        } else {
            credit[o.customer] += deductions;
            credit[o.serviceProvider] += o.paymentTokenWei - deductions;
        }
    }

    function withdraw() public {
        uint amount = credit[msg.sender];
        require(amount > 0, "Nothing to withdraw");
        credit[msg.sender] = 0;
        require(token.transfer(msg.sender, amount), "Withdraw failed");
    }
}