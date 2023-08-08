// deploys one GIFT token contract to be used for all tests
// set for local fork
// Load dependencies
const abiDecoder = require('abi-decoder');

const { expect } = require('chai');

const Web3 = require('web3');
const web3 = new Web3("https://speedy-nodes-nyc.moralis.io/3568f67f4eff90259f92f79f/eth/rinkeby"); // use for rinkeby testnet (moralis node)
// const web3 = new Web3("http://localhost:8545"); // use for local fork

// Import utilities from Test Helpers
const { BN, constants, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const {ZERO_ADDRESS} = require("@openzeppelin/test-helpers/src/constants");
// const {web3} = require("@openzeppelin/test-helpers/src/setup");

// create contract instances
const sushiRouterABI = require('./abis/SushiSwapRouter.json');
const sushiRouterContractAddress = '0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506';
const sushiRouterContract = new web3.eth.Contract(sushiRouterABI, sushiRouterContractAddress);

const sushiFactoryABI = require('./abis/SushiSwapFactory.json');
const sushiFactoryContractAddress = '0xc35DADB65012eC5796536bD9864eD8773aBc74C4';
const sushiFactoryContract = new web3.eth.Contract(sushiFactoryABI, sushiFactoryContractAddress);

const wethABI = require('./abis/Weth.json');
const wethContractAddress = '0xc778417E063141139Fce010982780140Aa0cD5Ab';
const wethContract = new web3.eth.Contract(wethABI, wethContractAddress);

const daiABI = require('./abis/Dai.json');
const daiContractAddress = '0xc7AD46e0b8a400Bb3C915120d284AafbA8fc4735';
const daiContract = new web3.eth.Contract(daiABI, daiContractAddress);

const sushiPairABI = require('./abis/SushiPair.json');


(async () => {

})();

// Load compiled artifacts
const SWIFT = artifacts.require('SWIFT'); // testing purposes
// const gift = await GIFT.deployed();

abiDecoder.addABI(SWIFT.abi);


// Start test block
contract('SWIFT', function (accounts) { // testing purposes
    // Use large integers ('big numbers')
    const totalSupply = new BN('500000000000000000000000000'); // 500 million tokens
    const increaseSupplyValue = new BN('500000000000000000000000') // 500,000 tokens
    const transferValue = new BN('500000000000000000000') // 500 tokens
    const largerTransferValue = new BN('600000000000000000000') // 600 tokens
    const smallValue = new BN('5000000000000000000') // 5 tokens
    const tierOne =  new BN('3000000000000000000000') // 3000
    const tierTwo =  new BN('9000000000000000000000') // 9000
    const tierThree =  new BN('30000000000000000000000') // 30000
    const tierFour =  new BN('300000000000000000000000') // 300000

    async function checkRevertReason(
        revertReason,
        to,
        from,
        gas,
        txData
    ) {
        const transactionObject = {
            data: txData,
            to: to,
            gas: gas,
            from: from
        }
        const message = await new Promise((resolve, reject) => {
            web3.eth.call(transactionObject, 'latest')
                .then((result) => {
                    resolve("");
                })
                .catch((error) => {
                    resolve(error.toString());
                });
        });

        if (message) {
            return message.toLowerCase().includes(revertReason.toLowerCase());
        }
        return false
    };

    async function checkEvents(
        receipt,
        eventName,
        params
    ) {
        const logs =  receipt.logs;
        console.log(logs[0].args);
        for (let i = 0; i < Object.keys(logs).length; i++) {
            if (logs[i].event === eventName) {
                const args = logs[i].args;
                const paramKeys = Object.keys(params);
                let valuesMatch = true;
                for (let x = 0; x < paramKeys.length; x++) {
                    const key = paramKeys[x];
                    if (key === 'value') {
                        if(params[key] !== args[key].toString()) {
                            valuesMatch = false;
                            break
                        }
                    }
                    else if (params[key] !== args[key]) {
                        valuesMatch = false;
                        break
                    }
                }
                if (valuesMatch) {
                    return true;
                }
            }
            // console.log(logs[i]);
            // console.log(logs[i].event);
        }
        return false;

    };

    before(async function () {

        this.gift = await SWIFT.at("0xFF1CF9d20816bc931151FeB939D7091cf4607AD8"); // testing purposes
        // this.gift = await SWIFT.new({'from': accounts[0]}); // testing purposes

    });

    it('checking if totalSupply returns total token supply', async function () {

        // Use large integer comparisons
        expect(await this.gift.totalSupply()).to.be.bignumber.equal('503500000000000000000000000');
    });

    // tests for updateTaxPercentages function
    it('updateTaxPercentages: checking that non owner cannot call onlyOwner modified function', async function () {
        // Test a transaction reverts
        const revertReason = "Ownable: caller is not the owner";
        const _contract = new web3.eth.Contract(this.gift.abi, this.gift.address);
        const txData = _contract.methods.updateTaxPercentages(4000, 3000, 2000, 1000, 500).encodeABI();
        const to = this.gift.address;
        const from = accounts[1];

        expect(await checkRevertReason(
            revertReason,
            to,
            from,
            '3000000',
            txData)).to.equal(true);
    });

    it('updateTaxPercentages: checking that tax percentages get updated', async function () {
        // Test a transaction reverts
        await this.gift.updateTaxPercentages(4000, 3000, 2000, 1000, 500, {from: accounts[0]});

        expect((await this.gift.tierOneTaxPercentage()).toString()).to.be.equal('4000');
    });

    // tests for updateTaxTiers function
    it('updateTaxTiers: checking that non owner cannot call onlyOwner modified function', async function () {
        // Test a transaction reverts
        const revertReason = "Ownable: caller is not the owner";
        const _contract = new web3.eth.Contract(this.gift.abi, this.gift.address);
        const txData = _contract.methods.updateTaxTiers(tierOne, tierTwo, tierThree, tierFour).encodeABI();
        const to = this.gift.address;
        const from = accounts[1];

        expect(await checkRevertReason(
            revertReason,
            to,
            from,
            '3000000',
            txData)).to.equal(true);
    });

    it('updateTaxTiers: checking that tax tiers get updated', async function () {
        // Test a transaction reverts
        await this.gift.updateTaxTiers(tierOne, tierTwo, tierThree, tierFour, {from: accounts[0]});

        expect((await this.gift.tierOneMax()).toString()).to.be.equal('3000000000000000000000');
    });

    //tests for setSupplyController function
    it('setSupplyController: checking that non owner cannot call onlyOwner modified function', async function () {
        // Test a transaction reverts
        const revertReason = "Ownable: caller is not the owner";
        const _contract = new web3.eth.Contract(this.gift.abi, this.gift.address);
        const txData = _contract.methods.setSupplyController(accounts[1]).encodeABI();
        const to = this.gift.address;
        const from = accounts[1];

        expect(await checkRevertReason(
            revertReason,
            to,
            from,
            '3000000',
            txData)).to.equal(true);
    });

    it('setSupplyController: checking that supplyController cannot be set to zero address', async function () {
        // Test a transaction reverts
        // Test a transaction reverts
        const revertReason = "cannot set supply controller to address zero";
        const _contract = new web3.eth.Contract(this.gift.abi, this.gift.address);
        const txData = _contract.methods.setSupplyController(ZERO_ADDRESS).encodeABI();
        const to = this.gift.address;
        const from = accounts[0];

        expect(await checkRevertReason(
            revertReason,
            to,
            from,
            '3000000',
            txData)).to.equal(true);
    });

    it('setSupplyController: checking that supplyController state variable gets set to expected address', async function () {
        // Test a transaction reverts
        await this.gift.setSupplyController(accounts[5], {from: accounts[0]});

        expect(await this.gift.supplyController()).to.be.equal(accounts[5]);
    });

    //tests for setBeneficiary function
    it('setBeneficiary: checking that non owner cannot call onlyOwner modified function', async function () {
        // Test a transaction reverts
        const revertReason = "Ownable: caller is not the owner";
        const _contract = new web3.eth.Contract(this.gift.abi, this.gift.address);
        const txData = _contract.methods.setBeneficiary(accounts[1]).encodeABI();
        const to = this.gift.address;
        const from = accounts[1];

        expect(await checkRevertReason(
            revertReason,
            to,
            from,
            '3000000',
            txData)).to.equal(true);
    });

    it('setBeneficiary: checking that beneficiary cannot be set to zero address', async function () {
        // Test a transaction reverts
        const revertReason = "cannot set beneficiary to address zero";
        const _contract = new web3.eth.Contract(this.gift.abi, this.gift.address);
        const txData = _contract.methods.setBeneficiary(ZERO_ADDRESS).encodeABI();
        const to = this.gift.address;
        const from = accounts[0];

        expect(await checkRevertReason(
            revertReason,
            to,
            from,
            '3000000',
            txData)).to.equal(true);
    });

    it('setBeneficiary: checking that beneficiary state variable gets set to expected address', async function () {
        // Test a transaction reverts
        await this.gift.setBeneficiary(accounts[5], {from: accounts[0]});

        expect(await this.gift.beneficiary()).to.be.equal(accounts[5]);
    });

    //tests for setFeeExclusion function
    it('setFeeExclusion: checking that non owner cannot call onlyOwner modified function', async function () {
        // Test a transaction reverts
        const revertReason = "Ownable: caller is not the owner";
        const _contract = new web3.eth.Contract(this.gift.abi, this.gift.address);
        const txData = _contract.methods.setFeeExclusion(accounts[1], true).encodeABI();
        const to = this.gift.address;
        const from = accounts[1];

        expect(await checkRevertReason(
            revertReason,
            to,
            from,
            '3000000',
            txData)).to.equal(true);
    });

    it('setFeeExclusion: checking if address gets set to be excluded from fee', async function () {
        // Test a transaction reverts
        await this.gift.setFeeExclusion(accounts[5], true, {from: accounts[0]});

        expect(
            await this.gift._isExcludedFromFees(accounts[5])).to.be.equal(true);
    });

    // tests for setLiquidityPools function
    it('setLiquidityPools: checking that non owner cannot call onlyOwner modified function', async function () {
        // Test a transaction reverts
        const revertReason = "Ownable: caller is not the owner";
        const _contract = new web3.eth.Contract(this.gift.abi, this.gift.address);
        const txData = _contract.methods.setLiquidityPools(accounts[1], true).encodeABI();
        const to = this.gift.address;
        const from = accounts[1];

        expect(await checkRevertReason(
            revertReason,
            to,
            from,
            '3000000',
            txData)).to.equal(true);
    });

    it('setLiquidityPools: checking if address gets set as a liquidity pool', async function () {
        // Test a transaction reverts
        await this.gift.setLiquidityPools(sushiRouterContractAddress, true, {from: accounts[0]});

        expect(
            await this.gift._isLiquidityPool(sushiRouterContractAddress)).to.be.equal(true);
    });

    //tests for increaseSupply function
    it('increaseSupply: checking that non supplyController cannot call onlySupplyController modified function', async function () {
        // Test a transaction reverts
        const revertReason = "caller is not the supplyController";
        const _contract = new web3.eth.Contract(this.gift.abi, this.gift.address);
        const txData = _contract.methods.increaseSupply(increaseSupplyValue).encodeABI();
        const to = this.gift.address;
        const from = accounts[2];

        expect(await checkRevertReason(
            revertReason,
            to,
            from,
            '3000000',
            txData)).to.equal(true);
    });

    it('increaseSupply: checking that it emits a Transfer event from zero address on successful call', async function () {
        // Test a transaction emits event with proper value
        const receipt = await this.gift.increaseSupply('500000000000000000000000', {from: accounts[5]});

        console.log(receipt);

        expect(await checkEvents(receipt, 'Transfer', {
            from: ZERO_ADDRESS,
            to: accounts[5],
            value: '500000000000000000000000'
        })).to.equal(true);
    });

    //tests for redeemGold function
    it('redeemGold: checking that non supplyController cannot call onlySupplyController modified function', async function () {
        // Test a transaction reverts
        await this.gift.transfer(accounts[4], '10000000000000000000', {from: accounts[0]});

        const revertReason = "caller is not the supplyController";
        const _contract = new web3.eth.Contract(this.gift.abi, this.gift.address);
        const txData = _contract.methods.redeemGold(accounts[4], '10000000000000000000').encodeABI();
        const to = this.gift.address;
        const from = accounts[0];

        expect(await checkRevertReason(
            revertReason,
            to,
            from,
            '3000000',
            txData)).to.equal(true);
    });

    it('redeemGold: checking that it emits a Transfer event to zero address on successful call', async function () {
        // Test a transaction emits event with proper value

        const receipt = await this.gift.redeemGold(accounts[4], '10000000000000000000', {from: accounts[5]});

        expect(await checkEvents(receipt, 'Transfer', {
            from: accounts[4],
            to: ZERO_ADDRESS,
            // value: '10000000000000000000'
        })).to.equal(true);
    });

    //tests for pause function
    it('pause: checking that non owner cannot call onlyOwner modified function', async function () {
        // Test a transaction reverts

        const revertReason = "Ownable: caller is not the owner";
        const _contract = new web3.eth.Contract(this.gift.abi, this.gift.address);
        const txData = _contract.methods.pause().encodeABI();
        const to = this.gift.address;
        const from = accounts[1];

        expect(await checkRevertReason(
            revertReason,
            to,
            from,
            '3000000',
            txData)).to.equal(true);
    });

    it('pause: checking that you cannot call pause function when contract is already paused', async function () {
        // Test a transaction reverts
        await this.gift.pause({from: accounts[0]});

        const revertReason = "Pausable: paused";
        const _contract = new web3.eth.Contract(this.gift.abi, this.gift.address);
        const txData = _contract.methods.pause().encodeABI();
        const to = this.gift.address;
        const from = accounts[0];

        expect(await checkRevertReason(
            revertReason,
            to,
            from,
            '3000000',
            txData)).to.equal(true);
    });

    it('pause: checking that it emits a Paused event on successful call', async function () {
        // Test a transaction emits event with proper value
        await this.gift.unpause({from: accounts[0]});

        const receipt = await this.gift.pause({from: accounts[0]});

        expect(await checkEvents(receipt, 'Paused', {
            account: accounts[0]
        })).to.equal(true);
    });

    //tests for unpause function
    it('unpause: checking that non owner cannot call onlyOwner modified function', async function () {
        // Test a transaction reverts

        const revertReason = "Ownable: caller is not the owner";
        const _contract = new web3.eth.Contract(this.gift.abi, this.gift.address);
        const txData = _contract.methods.unpause().encodeABI();
        const to = this.gift.address;
        const from = accounts[1];

        expect(await checkRevertReason(
            revertReason,
            to,
            from,
            '3000000',
            txData)).to.equal(true);
    });

    it('unpause: checking that you cannot call unpause function when contract is already unpaused', async function () {
        // Test a transaction reverts
        await this.gift.unpause({from: accounts[0]});

        const revertReason = "Pausable: not paused";
        const _contract = new web3.eth.Contract(this.gift.abi, this.gift.address);
        const txData = _contract.methods.unpause().encodeABI();
        const to = this.gift.address;
        const from = accounts[0];

        expect(await checkRevertReason(
            revertReason,
            to,
            from,
            '3000000',
            txData)).to.equal(true);
    });

    it('unpause: checking that it emits an Unpaused event on successful call', async function () {
        // Test a transaction emits event with proper value
        await this.gift.pause({from: accounts[0]});

        const receipt = await this.gift.unpause({from: accounts[0]});

        expect(await checkEvents(receipt, 'Unpaused', {
            account: accounts[0]
        })).to.equal(true);
    });

    //tests for snapshot functionality
    it('snapshot: checking that non owner cannot call onlyOwner modified function', async function () {
        // Test a transaction reverts

        const revertReason = "Ownable: caller is not the owner";
        const _contract = new web3.eth.Contract(this.gift.abi, this.gift.address);
        const txData = _contract.methods.snapshot().encodeABI();
        const to = this.gift.address;
        const from = accounts[1];

        expect(await checkRevertReason(
            revertReason,
            to,
            from,
            '3000000',
            txData)).to.equal(true);
    });

    it('snapshot: checking that values are recorded when snapshot function is called', async function () {

        await this.gift.snapshot({from: accounts[0]});
        await this.gift.transfer(accounts[1], '10000000000000000000', {from: accounts[0]});
        await this.gift.snapshot({from: accounts[0]});
        await this.gift.transfer(accounts[0], '5000000000000000000', {from: accounts[1]});

        const firstSnapshotBalance = BN(await this.gift.balanceOfAt(accounts[1], 1, {from: accounts[1]})).toString();
        const secondSnapshotBalance = BN(await this.gift.balanceOfAt(accounts[1], 2, {from: accounts[1]})).toString();
        const currentBalance = BN(await this.gift.balanceOf(accounts[1], {from: accounts[1]})).toString();


        console.log(firstSnapshotBalance);
        console.log(secondSnapshotBalance);
        console.log(currentBalance);
        expect(secondSnapshotBalance).to.not.equal(currentBalance);
    });

    //tests for transfer function
    it('transfer: checking that you cannot call transfer when contract is paused', async function () {
        // Test a transaction reverts
        await this.gift.pause({from: accounts[0]});

        const revertReason = "Pausable: paused";
        const _contract = new web3.eth.Contract(this.gift.abi, this.gift.address);
        const txData = _contract.methods.transfer(accounts[1], transferValue).encodeABI();
        const to = this.gift.address;
        const from = accounts[0];

        expect(await checkRevertReason(
            revertReason,
            to,
            from,
            '3000000',
            txData)).to.equal(true);
    });

    it('transfer: checking that you cannot call transfer to zero address', async function () {
        // Test a transaction reverts
        await this.gift.unpause({from: accounts[0]});

        const revertReason = "ERC20: transfer to the zero address";
        const _contract = new web3.eth.Contract(this.gift.abi, this.gift.address);
        const txData = _contract.methods.transfer(ZERO_ADDRESS, transferValue).encodeABI();
        const to = this.gift.address;
        const from = accounts[0];

        expect(await checkRevertReason(
            revertReason,
            to,
            from,
            '3000000',
            txData)).to.equal(true);
    });

    it('transfer: checking that you cannot transfer more than available balance', async function () {
        // Test a transaction reverts
        await this.gift.transfer(accounts[2], "1000000000000000000", {from: accounts[0]});

        const revertReason = "ERC20: transfer amount exceeds balance";
        const _contract = new web3.eth.Contract(this.gift.abi, this.gift.address);
        const txData = _contract.methods.transfer(accounts[3], "100000000000000000000").encodeABI();
        const to = this.gift.address;
        const from = accounts[2];

        expect(await checkRevertReason(
            revertReason,
            to,
            from,
            '3000000',
            txData)).to.equal(true);
    });

    it('transfer: checking that it emits Transfer event on successful call', async function () {
        // Test a transaction emits event with proper value
        const receipt = await this.gift.transfer(accounts[2], "1000000000000000000", {from: accounts[0]});

        expect(await checkEvents(receipt, 'Transfer', {
            from: accounts[0],
            to: accounts[2],
            // value: '1000000000000000000'
        })).to.equal(true);
    });

    it('transfer: checking that it emits additional Transfer event to beneficiary on successful call', async function () {
        // Test a transaction emits event with proper value
        await this.gift.transfer(accounts[1], "100000000000000000000", {from: accounts[0]});
        const tax = await this.gift.computeTax("100000000000000000000");

        const receipt = await this.gift.transfer(accounts[2], "100000000000000000000", {from: accounts[1]});

        expect(await checkEvents(receipt, 'Transfer', {
            from: accounts[1],
            to: accounts[5], // beneficiary address
            // value: tax
        })).to.equal(true);
    });

    //tests for adding liquidity and swapping
    it('adding liquidity and swapping ETH for exact GIFT (9)', async function () {
        //add liquidity GIFT/ETH to sushiswap
        giftTokenAddress = web3.utils.toChecksumAddress(this.gift.address);

        const prevBalance = BN(await this.gift.balanceOf(accounts[1], {from: accounts[1]})).toString();

        const allowance = await this.gift.allowance(accounts[0], sushiRouterContractAddress);

        if(allowance == 0) {
            await this.gift.approve(sushiRouterContractAddress, '9999999999999999999999999999999999', {from: accounts[0]});
        }

        await sushiRouterContract.methods.addLiquidityETH(
            giftTokenAddress,
            '100000000000000000000', // 100 GIFT tokens
            0,
            0,
            accounts[0],
            '99999999999999'
        ).send({gas: '5000000', value: '1000000000000000', from: accounts[0]}); // 0.001 ETH

        await sushiRouterContract.methods.swapETHForExactTokens(
            '100000000000000000', // 0.1 GIFT token
            [wethContractAddress, giftTokenAddress],
            accounts[1],
            '2644540023' // UNEX timestamp
        ).send({gas: '2000000', value: '10000000000000', from: accounts[1]}); // 0.00001 ETH

        const balance = BN(await this.gift.balanceOf(accounts[1], {from: accounts[1]})).toString();

        console.log(prevBalance);
        console.log(balance);
        expect(
            prevBalance).to.not.equal(balance);
    });

    it('swapping exact ETH for GIFT (10)', async function () {
        //add liquidity GIFT/ETH to sushiswap
        giftTokenAddress = web3.utils.toChecksumAddress(this.gift.address);

        const prevBalance = BN(await this.gift.balanceOf(accounts[1], {from: accounts[1]})).toString();

        await sushiRouterContract.methods.swapExactETHForTokens(
            0,
            [wethContractAddress, giftTokenAddress],
            accounts[1],
            '2644540023' // UNEX timestamp
        ).send({gas: '2000000', value: '10000000000000', from: accounts[1]}); // 0.00001 ETH

        const balance = BN(await this.gift.balanceOf(accounts[1], {from: accounts[1]})).toString();

        console.log(prevBalance);
        console.log(balance);
        expect(
            prevBalance).to.not.equal(balance);
    });

    it('swapping exact ETH for GIFT supporting fees (11)', async function () {
        //add liquidity GIFT/ETH to sushiswap
        giftTokenAddress = web3.utils.toChecksumAddress(this.gift.address);

        const prevBalance = BN(await this.gift.balanceOf(accounts[1], {from: accounts[1]})).toString();

        await sushiRouterContract.methods.swapExactETHForTokensSupportingFeeOnTransferTokens(
            0,
            [wethContractAddress, giftTokenAddress],
            accounts[1],
            '2644540023' // UNEX timestamp
        ).send({gas: '2000000', value: '10000000000000', from: accounts[1]}); // 0.00001 ETH

        const balance = BN(await this.gift.balanceOf(accounts[1], {from: accounts[1]})).toString();

        console.log(prevBalance);
        console.log(balance);
        expect(
            prevBalance).to.not.equal(balance);
    });

    it('swapping exact GIFT for ETH (12)', async function () {
        //add liquidity GIFT/ETH to sushiswap
        giftTokenAddress = web3.utils.toChecksumAddress(this.gift.address);

        const initialBalance = BN(await this.gift.balanceOf(accounts[0], {from: accounts[0]})).toString();

        await sushiRouterContract.methods.swapExactTokensForETH(
            '100000000000000000', // 0.1 tokens
            0,
            [giftTokenAddress, wethContractAddress],
            accounts[0],
            '2644540023' // UNEX timestamp
        ).send({gas: '3000000', from: accounts[0]});

        const balance = BN(await this.gift.balanceOf(accounts[0], {from: accounts[0]})).toString();

        console.log(initialBalance);
        console.log(balance);
        expect(
            initialBalance).to.not.equal(balance);
    });

    it('swapping exact GIFT for ETH supporting fees (13)', async function () {
        //add liquidity GIFT/ETH to sushiswap
        giftTokenAddress = web3.utils.toChecksumAddress(this.gift.address);

        const initialBalance = BN(await this.gift.balanceOf(accounts[1], {from: accounts[1]})).toString();

        const allowance = await this.gift.allowance(accounts[1], sushiRouterContractAddress);

        if(allowance == 0) {
            await this.gift.approve(sushiRouterContractAddress, '9999999999999999999999999999999999', {from: accounts[1]});
        }

        await sushiRouterContract.methods.swapExactTokensForETHSupportingFeeOnTransferTokens(
            '100000000000000000', // 0.1 tokens
            0,
            [giftTokenAddress, wethContractAddress],
            accounts[1],
            '2644540023' // UNEX timestamp
        ).send({gas: '3000000', from: accounts[1]});

        const balance = BN(await this.gift.balanceOf(accounts[1], {from: accounts[1]})).toString();

        console.log(initialBalance);
        console.log(balance);
        expect(
            initialBalance).to.not.equal(balance);
    });

    it('adding liquidity and swapping exact GIFT for DAI (14)', async function () {
        //add liquidity GIFT/ETH to sushiswap
        giftTokenAddress = web3.utils.toChecksumAddress(this.gift.address);

        const initialBalance = BN(await this.gift.balanceOf(accounts[0], {from: accounts[0]})).toString();

        const allowance = await daiContract.methods.allowance(accounts[0], sushiRouterContractAddress).call();

        if(allowance == 0) {
            await daiContract.methods.approve(sushiRouterContractAddress, '9999999999999999999999999999999999').send({from: accounts[0]});
        }

        await sushiRouterContract.methods.swapExactETHForTokens(
            0,
            [wethContractAddress, daiContractAddress],
            accounts[0],
            '2644540023' // UNEX timestamp
        ).send({gas: '4000000', value: '10000000000000000', from: accounts[0]}); // 0.01 ETH

        await sushiRouterContract.methods.addLiquidity(
            giftTokenAddress,
            daiContractAddress, // DAI address
            '100000000000000000000', // 100 GIFT tokens
            '100000', // 0.1 DAI tokens (decimal 6)
            0,
            0,
            accounts[0],
            '99999999999999'
        ).send({gas: '5000000', from: accounts[0]});

        const prevBalance = BN(await this.gift.balanceOf(accounts[0], {from: accounts[0]})).toString();

        await sushiRouterContract.methods.swapExactTokensForTokens(
            '1000000000000000000', // 1 token
            0,
            [giftTokenAddress, daiContractAddress],
            accounts[0],
            '2644540023' // UNEX timestamp
        ).send({gas: '3000000', from: accounts[0]});

        const balance = BN(await this.gift.balanceOf(accounts[0], {from: accounts[0]})).toString();

        console.log(initialBalance);
        console.log(prevBalance);
        console.log(balance);
        expect(
            prevBalance).to.not.equal(balance);
    });

    it('swapping exact GIFT for DAI supporting fees (15)', async function () {
        //add liquidity GIFT/ETH to sushiswap
        giftTokenAddress = web3.utils.toChecksumAddress(this.gift.address);

        const allowance = await daiContract.methods.allowance(accounts[1], sushiRouterContractAddress).call();

        if(allowance == 0) {
            await daiContract.methods.approve(sushiRouterContractAddress, '9999999999999999999999999999999999').send({from: accounts[1]});
        }

        const initialBalance = BN(await this.gift.balanceOf(accounts[1], {from: accounts[1]})).toString();

        await sushiRouterContract.methods.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            '1000000000000000000', // 1 token
            0,
            [giftTokenAddress, daiContractAddress],
            accounts[1],
            '2644540023' // UNEX timestamp
        ).send({gas: '3000000', from: accounts[1]});

        const balance = BN(await this.gift.balanceOf(accounts[1], {from: accounts[1]})).toString();

        console.log(initialBalance);
        console.log(balance);
        expect(
            initialBalance).to.not.equal(balance);
    });

    it('swapping GIFT for exact ETH (16)', async function () {
        //add liquidity GIFT/ETH to sushiswap
        giftTokenAddress = web3.utils.toChecksumAddress(this.gift.address);

        const initialBalance = BN(await this.gift.balanceOf(accounts[0], {from: accounts[0]})).toString();

        await sushiRouterContract.methods.swapTokensForExactETH(
            '10000000000000', // 0.00001 ETH
            '10000000000000000000', // 10 tokens
            [giftTokenAddress, wethContractAddress],
            accounts[0],
            '2644540023' // UNEX timestamp
        ).send({gas: '3000000', from: accounts[0]});

        const balance = BN(await this.gift.balanceOf(accounts[0], {from: accounts[0]})).toString();

        console.log(initialBalance);
        console.log(balance);
        expect(
            initialBalance).to.not.equal(balance);
    });

    it('swapping GIFT for exact DAI (17)', async function () {
        //add liquidity GIFT/ETH to sushiswap
        giftTokenAddress = web3.utils.toChecksumAddress(this.gift.address);

        const initialBalance = BN(await this.gift.balanceOf(accounts[0], {from: accounts[0]})).toString();

        await sushiRouterContract.methods.swapTokensForExactTokens(
            '1000', // 0.001 DAI token
            '10000000000000000000', // 10 GIFT tokens
            [giftTokenAddress, daiContractAddress],
            accounts[0],
            '2644540023' // UNEX timestamp
        ).send({gas: '3000000', from: accounts[0]});

        const balance = BN(await this.gift.balanceOf(accounts[0], {from: accounts[0]})).toString();

        console.log(initialBalance);
        console.log(balance);
        expect(
            initialBalance).to.not.equal(balance);
    });

    it('adding and removing liquidity GIFT/ETH', async function () {
        //add liquidity GIFT/ETH to sushiswap
        giftTokenAddress = web3.utils.toChecksumAddress(this.gift.address);

        const initialBalance = BN(await this.gift.balanceOf(accounts[0])).toString();

        const sushiPairAddress = await sushiFactoryContract.methods.getPair(giftTokenAddress, wethContractAddress).call();
        console.log(sushiPairAddress);
        const sushiPairContract = await new web3.eth.Contract(sushiPairABI, sushiPairAddress);

        const lpBalance = await sushiPairContract.methods.balanceOf(accounts[0]).call();
        console.log(lpBalance);

        const allowance = await this.gift.allowance(accounts[0], sushiRouterContractAddress);

        if(allowance == 0) {
            await this.gift.approve(sushiRouterContractAddress, '9999999999999999999999999999999999', {from: accounts[0]});
        }

        await sushiRouterContract.methods.removeLiquidityETHSupportingFeeOnTransferTokens(
            giftTokenAddress,
            lpBalance,
            0,
            0,
            accounts[0],
            '99999999999999'
        ).send({gas: '5000000', from: accounts[0]});

        const balance = BN(await this.gift.balanceOf(accounts[0])).toString();

        console.log(initialBalance);
        console.log(balance);
        expect(
            initialBalance).to.not.equal(balance);
    });

});