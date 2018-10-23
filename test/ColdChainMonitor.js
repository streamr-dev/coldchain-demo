const assert = require("assert")
const BN = web3.utils.BN

const Monitor = artifacts.require("./ColdChainMonitor.sol");
const MintableToken = artifacts.require("./MintableToken.sol")

contract("ColdChainMonitor", accounts => {
    let token
    const customer = accounts[1]
    const serviceProvider = accounts[2]
    const canvas = accounts[3]
    const admin = accounts[4]
    const startCash = new BN(web3.utils.toWei("1", "ether"))
    const stake = new BN(web3.utils.toWei("0.1", "ether"))

    before(async () => {
        token = await MintableToken.new({from: admin})        
        await token.mint(customer, startCash, {from: admin})
        await token.mint(serviceProvider, startCash, {from: admin})
    })

    describe("Shipping process", () => {
        const temperatureLimit = "20"
        const deadlineTimestamp = "" + (Math.floor(Date.now() / 1000) + 100000)
        const paymentTokenWei = startCash
        const temperaturePenaltyTokenWei = new BN(web3.utils.toWei("0.001", "ether"))
        const overtimePenaltyTokenWeiPerSecond = new BN(web3.utils.toWei("0.0001", "ether"))
        it("works end to end as intended", async () => {
            // customer creates the monitor
            const monitor = await Monitor.new(
                token.address,
                canvas,
                temperatureLimit,
                deadlineTimestamp,
                paymentTokenWei,
                temperaturePenaltyTokenWei,
                overtimePenaltyTokenWeiPerSecond,
                {from: customer}
            )

            // all parties give necessary allowance to contract
            token.approve(monitor.address, startCash, {from: customer})
            token.approve(monitor.address, startCash, {from: serviceProvider})

            // shipping company accepts
            await monitor.acceptOrder({from: serviceProvider})

            // in transit...
            const overages = new BN(200)

            // customer receives
            await monitor.shipmentArrived({from: customer})

            // canvas reports the overages
            const deductions = overages.mul(temperaturePenaltyTokenWei)
            const payable = paymentTokenWei.sub(deductions)
            await monitor.payout(overages, {from: canvas})

            // shipping company withdraws its payment
            const beforeWithdraw = await token.balanceOf(serviceProvider)
            assert(startCash.sub(stake).eq(beforeWithdraw))
            await monitor.withdraw({from: serviceProvider})
            const afterWithdraw = await token.balanceOf(serviceProvider)
            assert(beforeWithdraw.add(payable).eq(afterWithdraw))

            // customer withdraws deductions
            const customerBalanceBefore = await token.balanceOf(customer)
            assert.strictEqual(0, +customerBalanceBefore)
            await monitor.withdraw({from: customer})
            const customerBalanceAfter = await token.balanceOf(customer)
            assert(deductions.eq(customerBalanceAfter))
        })
    })
})