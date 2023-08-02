// deploys new GIFT token contract for each test

// Load dependencies
const { expect } = require('chai');

const Web3 = require('web3');
const web3 = new Web3("http://localhost:8545"); // use for local fork

// Import utilities from Test Helpers
const { BN, constants, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const {ZERO_ADDRESS} = require("@openzeppelin/test-helpers/src/constants");
// const {web3} = require("@openzeppelin/test-helpers/src/setup");

// create contract instances
const sushiRouterABI = require('./abis/SushiSwapRouter.json');
const sushiRouterContractAddress = '0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F'; //mainnet: 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F, rinkeby: 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506
const sushiRouterContract = new web3.eth.Contract(sushiRouterABI, sushiRouterContractAddress);

const sushiFactoryABI = require('./abis/SushiSwapFactory.json');
const sushiFactoryContractAddress = '0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac'; //mainnet: 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac, rinkeby: 0xc35DADB65012eC5796536bD9864eD8773aBc74C4
const sushiFactoryContract = new web3.eth.Contract(sushiFactoryABI, sushiFactoryContractAddress);

const wethABI = require('./abis/Weth.json');
const wethContractAddress = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'; //mainnet: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, rinkeby: 0xc778417E063141139Fce010982780140Aa0cD5Ab
const wethContract = new web3.eth.Contract(wethABI, wethContractAddress);

// for mainnet use USDT, for rinkeby replace USDT with DAI
const daiABI = require('./abis/Dai.json');
const daiContractAddress = '0xc7AD46e0b8a400Bb3C915120d284AafbA8fc4735'; //rinkeby: 0xc7AD46e0b8a400Bb3C915120d284AafbA8fc4735
const daiContract = new web3.eth.Contract(daiABI, daiContractAddress);

const usdtABI = require('./abis/Usdt.json');
const usdtContractAddress = '0xdAC17F958D2ee523a2206206994597C13D831ec7'; //mainnet: 0xdAC17F958D2ee523a2206206994597C13D831ec7
const usdtContract = new web3.eth.Contract(usdtABI, usdtContractAddress);

const sushiPairABI = require('./abis/SushiPair.json');

(async () => {

})();

// Load compiled artifacts
const GIFT = artifacts.require('GIFT');
// const gift = await GIFT.deployed();

// Start test block
contract('GIFT', function (accounts) {
    // Use large integers ('big numbers')
    const totalSupply = new BN('500000000000000000000000000'); // 500 million tokens
    const increaseSupplyValue = new BN('500000000000000000000000'); // 500,000 tokens
    const transferValue = new BN('500000000000000000000'); // 500 tokens
    const largerTransferValue = new BN('600000000000000000000'); // 600 tokens
    const smallValue = new BN('5000000000000000000'); // 5 tokens

    beforeEach(async function () {

        this.gift = await GIFT.new({'from': accounts[0]});

    });

    it('checking if totalSupply returns total token supply', async function () {

        // Use large integer comparisons
        expect(await this.gift.totalSupply()).to.be.bignumber.equal(totalSupply);
    });

    // tests for updateTaxPercentages function
    it('updateTaxPercentages: checking that non owner cannot call onlyOwner modified function', async function () {
        // Test a transaction reverts
        await expectRevert(
            this.gift.updateTaxPercentages(4000, 3000, 2000, 1000, 500, { from: accounts[1] }),
            'Ownable: caller is not the owner',
        );
    });

    it('updateTaxPercentages: checking that tax percentages get updated', async function () {
        // Test a transaction reverts
        await this.gift.updateTaxPercentages(4000, 3000, 2000, 1000, 500, {from: accounts[0]});

        expect((await this.gift.tierOneTaxPercentage()).toString()).to.be.equal('4000');
    });

    // tests for updateTaxTiers function
    it('updateTaxTiers: checking that non owner cannot call onlyOwner modified function', async function () {
        // Test a transaction reverts
        await expectRevert(
            this.gift.updateTaxTiers(40000, 50000, 60000, 70000, { from: accounts[1] }),
            'Ownable: caller is not the owner',
        );
    });

    it('updateTaxTiers: checking that tax tiers get updated', async function () {
        // Test a transaction reverts
        await this.gift.updateTaxTiers(40000, 50000, 60000, 70000, {from: accounts[0]});

        expect((await this.gift.tierOneMax()).toString()).to.be.equal('40000');
    });

    // //tests for setSupplyController function
    // it('setSupplyController: checking that non owner cannot call onlyOwner modified function', async function () {
    //     // Test a transaction reverts
    //     await expectRevert(
    //         this.gift.setSupplyController(accounts[1], { from: accounts[1] }),
    //         'Ownable: caller is not the owner',
    //     );
    // });
    //
    // it('setSupplyController: checking that supplyController cannot be set to zero address', async function () {
    //     // Test a transaction reverts
    //     await expectRevert(
    //         this.gift.setSupplyController(ZERO_ADDRESS, { from: accounts[0] }),
    //         'cannot set supply controller to address zero',
    //     );
    // });
    //
    // it('setSupplyController: checking that supplyController state variable gets set to expected address', async function () {
    //     await this.gift.setSupplyController(accounts[1], {from: accounts[0]});
    //
    //     expect(await this.gift.supplyController()).to.be.equal(accounts[1]);
    // });
    //
    // //tests for setBeneficiary function
    // it('setBeneficiary: checking that non owner cannot call onlyOwner modified function', async function () {
    //     // Test a transaction reverts
    //     await expectRevert(
    //         this.gift.setBeneficiary(accounts[1], { from: accounts[1] }),
    //         'Ownable: caller is not the owner',
    //     );
    // });
    //
    // it('setBeneficiary: checking that beneficiary cannot be set to zero address', async function () {
    //     // Test a transaction reverts
    //     await expectRevert(
    //         this.gift.setBeneficiary(ZERO_ADDRESS, { from: accounts[0] }),
    //         'cannot set beneficiary to address zero',
    //     );
    // });
    //
    // it('setBeneficiary: checking that beneficiary state variable gets set to expected address', async function () {
    //     // Test a transaction reverts
    //     await this.gift.setBeneficiary(accounts[1], {from: accounts[0]});
    //
    //     expect(await this.gift.beneficiary()).to.be.equal(accounts[1]);
    // });
    //
    // //tests for setFeeExclusion function
    // it('setFeeExclusion: checking that non owner cannot call onlyOwner modified function', async function () {
    //     // Test a transaction reverts
    //     await expectRevert(
    //         this.gift.setFeeExclusion(accounts[1], true, { from: accounts[1] }),
    //         'Ownable: caller is not the owner',
    //     );
    // });
    //
    // it('setFeeExclusion: checking if address gets set to be excluded from fee', async function () {
    //     // Test a transaction reverts
    //     await this.gift.setFeeExclusion(accounts[1], true, {from: accounts[0]});
    //
    //     expect(
    //         await this.gift.isExcludedFromFees({from: accounts[1]})).to.be.equal(true);
    // });
    //
    // //tests for setLiquidityPools function
    // it('setLiquidityPools: checking that non owner cannot call onlyOwner modified function', async function () {
    //     // Test a transaction reverts
    //     await expectRevert(
    //         this.gift.setLiquidityPools(accounts[1], true, { from: accounts[1] }),
    //         'Ownable: caller is not the owner',
    //     );
    // });
    //
    // it('setLiquidityPools: checking if address gets set as a liquidity pool', async function () {
    //     // Test a transaction reverts
    //     await this.gift.setLiquidityPools(accounts[1], true, {from: accounts[0]});
    //
    //     expect(
    //         await this.gift.isLiquidityPool({from: accounts[1]})).to.be.equal(true);
    // });
    //
    // //tests for increaseSupply function
    // it('increaseSupply: checking that non supplyController cannot call onlySupplyController modified function', async function () {
    //     // Test a transaction reverts
    //     await expectRevert(
    //         this.gift.increaseSupply(increaseSupplyValue, { from: accounts[2] }),
    //         'caller is not the supplyController',
    //     );
    // });
    //
    // it('increaseSupply: checking that it emits a Transfer event from zero address on successful call', async function () {
    //     // Test a transaction emits event with proper value
    //     await this.gift.setSupplyController(accounts[2],{from: accounts[0]});
    //
    //     const receipt = await this.gift.increaseSupply(increaseSupplyValue, {from: accounts[2]});
    //
    //     // Event assertions can verify that the arguments are the expected ones
    //     expectEvent(receipt, 'Transfer', {
    //         from: ZERO_ADDRESS,
    //         to: accounts[2],
    //         value: increaseSupplyValue
    //     });
    // });
    //
    // //tests for redeemGold function
    // it('redeemGold: checking that non supplyController cannot call onlySupplyController modified function', async function () {
    //     // Test a transaction reverts
    //     await this.gift.transfer(accounts[4], transferValue, {from: accounts[0]});
    //
    //     await expectRevert(
    //         this.gift.redeemGold(accounts[4], transferValue, { from: accounts[0] }),
    //         'caller is not the supplyController',
    //     );
    // });
    //
    // it('redeemGold: checking that it emits a Transfer event to zero address on successful call', async function () {
    //     // Test a transaction emits event with proper value
    //     await this.gift.transfer(accounts[4], transferValue, {from: accounts[0]});
    //
    //     await this.gift.setSupplyController(accounts[3],{from: accounts[0]});
    //
    //     const receipt = await this.gift.redeemGold(accounts[4], transferValue, {from: accounts[3]});
    //
    //     // Event assertions can verify that the arguments are the expected ones
    //     expectEvent(receipt, 'Transfer', {
    //         from: accounts[4],
    //         to: ZERO_ADDRESS,
    //         value: transferValue
    //     });
    // });
    //
    // //tests for pause function
    // it('pause: checking that non owner cannot call onlyOwner modified function', async function () {
    //     // Test a transaction reverts
    //     await expectRevert(
    //         this.gift.pause({ from: accounts[1]}),
    //         'Ownable: caller is not the owner',
    //     );
    // });
    //
    // it('pause: checking that you cannot call pause function when contract is already paused', async function () {
    //     // Test a transaction reverts
    //     await this.gift.pause({from: accounts[0]});
    //
    //     await expectRevert(
    //         this.gift.pause({ from: accounts[0]}),
    //         'Pausable: paused',
    //     );
    // });
    //
    // it('pause: checking that it emits a Paused event on successful call', async function () {
    //     // Test a transaction emits event with proper value
    //     const receipt = await this.gift.pause({from: accounts[0]});
    //
    //     // Event assertions can verify that the arguments are the expected ones
    //     expectEvent(receipt, 'Paused', {
    //         account: accounts[0]
    //     });
    // });
    //
    // //tests for unpause function
    // it('unpause: checking that non owner cannot call onlyOwner modified function', async function () {
    //     // Test a transaction reverts
    //     await this.gift.pause({from: accounts[0]});
    //
    //     await expectRevert(
    //         this.gift.unpause({ from: accounts[1]}),
    //         'Ownable: caller is not the owner',
    //     );
    // });
    //
    // it('pause: checking that you cannot call unpause function when contract is already unpaused', async function () {
    //     // Test a transaction reverts
    //
    //     await expectRevert(
    //         this.gift.unpause({ from: accounts[0]}),
    //         'Pausable: not paused',
    //     );
    // });
    //
    // it('unpause: checking that it emits a Unpaused event on successful call', async function () {
    //     // Test a transaction emits event with proper value
    //     await this.gift.pause({from: accounts[0]});
    //
    //     const receipt = await this.gift.unpause({from: accounts[0]});
    //
    //     // Event assertions can verify that the arguments are the expected ones
    //     expectEvent(receipt, 'Unpaused', {
    //         account: accounts[0]
    //     });
    // });
    //
    // //tests for snapshot functionality
    // it('snapshot: checking that non owner cannot call onlyOwner modified function', async function () {
    //     // Test a transaction reverts
    //
    //     await expectRevert(
    //         this.gift.snapshot({ from: accounts[1]}),
    //         'Ownable: caller is not the owner',
    //     );
    // });
    //
    // it('snapshot: checking that values are recorded when snapshot function is called', async function () {
    //
    //     await this.gift.setBeneficiary(accounts[5], {from: accounts[0]});
    //
    //     await this.gift.snapshot({from: accounts[0]});
    //     await this.gift.transfer(accounts[1], '100000000000000000000', {from: accounts[0]});
    //     await this.gift.snapshot({from: accounts[0]});
    //     await this.gift.transfer(accounts[0], '50000000000000000000', {from: accounts[1]});
    //
    //     const firstSnapshotBalance = BN(await this.gift.balanceOfAt(accounts[1], 1, {from: accounts[1]})).toString();
    //     const secondSnapshotBalance = BN(await this.gift.balanceOfAt(accounts[1], 2, {from: accounts[1]})).toString();
    //     const currentBalance = BN(await this.gift.balanceOf(accounts[1], {from: accounts[1]})).toString();
    //
    //
    //     console.log(firstSnapshotBalance);
    //     console.log(secondSnapshotBalance);
    //     console.log(currentBalance);
    //     expect(secondSnapshotBalance).to.not.equal(currentBalance);
    // });
    //
    // //tests for transfer function
    // it('transfer: checking that you cannot call transfer when contract is paused', async function () {
    //     // Test a transaction reverts
    //     await this.gift.pause({from: accounts[0]});
    //
    //     await expectRevert(
    //         this.gift.transfer(accounts[1], transferValue, { from: accounts[0]}),
    //         'Pausable: paused',
    //     );
    // });
    //
    // it('transfer: checking that you cannot call transfer to zero address', async function () {
    //     // Test a transaction reverts
    //
    //     await expectRevert(
    //         this.gift.transfer(ZERO_ADDRESS, transferValue, { from: accounts[0]}),
    //         'ERC20: transfer to the zero address',
    //     );
    // });
    //
    // it('transfer: checking that you cannot transfer more than available balance', async function () {
    //     // Test a transaction reverts
    //     await this.gift.setBeneficiary(accounts[4], {from: accounts[0]});
    //     await this.gift.transfer(accounts[2], transferValue, {from: accounts[0]});
    //
    //     await expectRevert(
    //         this.gift.transfer(accounts[3], largerTransferValue, { from: accounts[2]}),
    //         'ERC20: transfer amount exceeds balance',
    //     );
    // });
    //
    // it('transfer: checking that it emits Transfer event on successful call', async function () {
    //     // Test a transaction emits event with proper value
    //     const receipt = await this.gift.transfer(accounts[1], transferValue, {from: accounts[0]});
    //
    //     // Event assertions can verify that the arguments are the expected ones
    //     expectEvent(receipt, 'Transfer', {
    //         from: accounts[0],
    //         to: accounts[1],
    //         value: transferValue,
    //     });
    // });
    //
    // it('transfer: checking that it emits additional Transfer event to beneficiary on successful call', async function () {
    //     // Test a transaction emits event with proper value
    //     await this.gift.transfer(accounts[1], transferValue, {from: accounts[0]});
    //     await this.gift.setBeneficiary(accounts[4], {from: accounts[0]});
    //     const tax = await this.gift.computeTaxAmount(transferValue);
    //
    //     const receipt = await this.gift.transfer(accounts[2], transferValue, {from: accounts[1]});
    //
    //     // Event assertions can verify that the arguments are the expected ones
    //     expectEvent(receipt, 'Transfer', {
    //         from: accounts[1],
    //         to: accounts[4],
    //         value: tax,
    //     });
    // });
    //
    // //tests for adding liquidity and swapping
    // it('adding liquidity and swapping ETH for exact GIFT (9)', async function () {
    //     //add liquidity GIFT/ETH to sushiswap
    //     giftTokenAddress = web3.utils.toChecksumAddress(this.gift.address);
    //
    //     const prevBalance = BN(await this.gift.balanceOf(accounts[1], {from: accounts[1]})).toString();
    //     await this.gift.setBeneficiary(accounts[4], {from: accounts[0]});
    //     await this.gift.approve(sushiRouterContractAddress, totalSupply, {from: accounts[0]});
    //
    //     await sushiRouterContract.methods.addLiquidityETH(
    //         giftTokenAddress,
    //         transferValue,
    //         0,
    //         0,
    //         accounts[0],
    //         '99999999999999'
    //     ).send({gas: '5000000', value: '1000000000000000000', from: accounts[0]});
    //
    //     await sushiRouterContract.methods.swapETHForExactTokens(
    //         smallValue,
    //         [wethContractAddress, giftTokenAddress],
    //         accounts[1],
    //         '2644540023' // UNEX timestamp
    //     ).send({gas: '2000000', value: '100000000000000000', from: accounts[1]});
    //
    //     const balance = BN(await this.gift.balanceOf(accounts[1], {from: accounts[1]})).toString();
    //
    //     console.log(prevBalance);
    //     console.log(balance);
    //     expect(
    //         prevBalance).to.not.equal(balance);
    // });
    //
    // it('adding liquidity and swapping exact ETH for GIFT (10)', async function () {
    //     //add liquidity GIFT/ETH to sushiswap
    //     giftTokenAddress = web3.utils.toChecksumAddress(this.gift.address);
    //
    //     const prevBalance = BN(await this.gift.balanceOf(accounts[1], {from: accounts[1]})).toString();
    //     await this.gift.setBeneficiary(accounts[4], {from: accounts[0]});
    //     await this.gift.approve(sushiRouterContractAddress, totalSupply, {from: accounts[0]});
    //
    //     await sushiRouterContract.methods.addLiquidityETH(
    //         giftTokenAddress,
    //         transferValue,
    //         0,
    //         0,
    //         accounts[0],
    //         '99999999999999'
    //         ).send({gas: '5000000', value: '1000000000000000000', from: accounts[0]});
    //
    //     await sushiRouterContract.methods.swapExactETHForTokens(
    //         0,
    //         [wethContractAddress, giftTokenAddress],
    //         accounts[1],
    //         '2644540023' // UNEX timestamp
    //     ).send({gas: '2000000', value: '10000000000000000', from: accounts[1]});
    //
    //     const balance = BN(await this.gift.balanceOf(accounts[1], {from: accounts[1]})).toString();
    //
    //     console.log(prevBalance);
    //     console.log(balance);
    //     expect(
    //         prevBalance).to.not.equal(balance);
    // });
    //
    // it('adding liquidity and swapping exact ETH for GIFT supporting fees (11)', async function () {
    //     //add liquidity GIFT/ETH to sushiswap
    //     giftTokenAddress = web3.utils.toChecksumAddress(this.gift.address);
    //
    //     const prevBalance = BN(await this.gift.balanceOf(accounts[1], {from: accounts[1]})).toString();
    //     await this.gift.setBeneficiary(accounts[4], {from: accounts[0]});
    //     await this.gift.approve(sushiRouterContractAddress, totalSupply, {from: accounts[0]});
    //
    //     await sushiRouterContract.methods.addLiquidityETH(
    //         giftTokenAddress,
    //         transferValue,
    //         0,
    //         0,
    //         accounts[0],
    //         '99999999999999'
    //     ).send({gas: '5000000', value: '1000000000000000000', from: accounts[0]});
    //
    //     await sushiRouterContract.methods.swapExactETHForTokens(
    //         0,
    //         [wethContractAddress, giftTokenAddress],
    //         accounts[1],
    //         '2644540023' // UNEX timestamp
    //     ).send({gas: '2000000', value: '10000000000000000', from: accounts[1]});
    //
    //     const balance = BN(await this.gift.balanceOf(accounts[1], {from: accounts[1]})).toString();
    //
    //     console.log(prevBalance);
    //     console.log(balance);
    //     expect(
    //         prevBalance).to.not.equal(balance);
    // });
    //
    // it('adding liquidity and swapping exact GIFT for ETH (12)', async function () {
    //     //add liquidity GIFT/ETH to sushiswap
    //     giftTokenAddress = web3.utils.toChecksumAddress(this.gift.address);
    //
    //     const initialBalance = BN(await this.gift.balanceOf(accounts[0], {from: accounts[0]})).toString();
    //     await this.gift.setBeneficiary(accounts[4], {from: accounts[0]});
    //     await this.gift.approve(sushiRouterContractAddress, totalSupply, {from: accounts[0]});
    //
    //     await sushiRouterContract.methods.addLiquidityETH(
    //         giftTokenAddress,
    //         transferValue, // 500 tokens
    //         0,
    //         0,
    //         accounts[0],
    //         '99999999999999'
    //     ).send({gas: '5000000', value: '1000000000000000000', from: accounts[0]});
    //
    //     const prevBalance = BN(await this.gift.balanceOf(accounts[0], {from: accounts[0]})).toString();
    //
    //     await sushiRouterContract.methods.swapExactTokensForETH(
    //         '100000000000000000000', // 100 tokens
    //         0,
    //         [giftTokenAddress, wethContractAddress],
    //         accounts[1],
    //         '2644540023' // UNEX timestamp
    //     ).send({gas: '3000000', from: accounts[0]});
    //
    //     const balance = BN(await this.gift.balanceOf(accounts[0], {from: accounts[0]})).toString();
    //
    //     console.log(initialBalance);
    //     console.log(prevBalance);
    //     console.log(balance);
    //     expect(
    //         prevBalance).to.not.equal(balance);
    // });
    //
    // it('adding liquidity and swapping exact GIFT for ETH supporting fees (13)', async function () {
    //     //add liquidity GIFT/ETH to sushiswap
    //     giftTokenAddress = web3.utils.toChecksumAddress(this.gift.address);
    //
    //     const initialBalance = BN(await this.gift.balanceOf(accounts[1], {from: accounts[1]})).toString();
    //     await this.gift.setBeneficiary(accounts[4], {from: accounts[0]});
    //     await this.gift.approve(sushiRouterContractAddress, totalSupply, {from: accounts[0]});
    //     await this.gift.approve(sushiRouterContractAddress, totalSupply, {from: accounts[1]});
    //     await this.gift.transfer(accounts[1], transferValue, {from: accounts[0]}); // transfer 500 tokens
    //     const prevBalance = BN(await this.gift.balanceOf(accounts[1], {from: accounts[1]})).toString();
    //
    //     await sushiRouterContract.methods.addLiquidityETH(
    //         giftTokenAddress,
    //         transferValue, // 500 tokens
    //         0,
    //         0,
    //         accounts[0],
    //         '99999999999999'
    //     ).send({gas: '5000000', value: '1000000000000000000', from: accounts[0]});
    //
    //     await sushiRouterContract.methods.swapExactTokensForETHSupportingFeeOnTransferTokens(
    //         '100000000000000000000', // 100 tokens
    //         0,
    //         [giftTokenAddress, wethContractAddress],
    //         accounts[1],
    //         '2644540023' // UNEX timestamp
    //     ).send({gas: '3000000', from: accounts[1]});
    //
    //     const balance = BN(await this.gift.balanceOf(accounts[1], {from: accounts[1]})).toString();
    //
    //     console.log(initialBalance);
    //     console.log(prevBalance);
    //     console.log(balance);
    //     expect(
    //         prevBalance).to.not.equal(balance);
    // });
    //
    // it('adding liquidity and swapping exact GIFT for USDT (14)', async function () {
    //     //add liquidity GIFT/ETH to sushiswap
    //     giftTokenAddress = web3.utils.toChecksumAddress(this.gift.address);
    //
    //     const initialBalance = BN(await this.gift.balanceOf(accounts[0], {from: accounts[0]})).toString();
    //
    //     await this.gift.setBeneficiary(accounts[4], {from: accounts[0]});
    //     await this.gift.approve(sushiRouterContractAddress, totalSupply, {from: accounts[0]});
    //
    //     const allowance = await usdtContract.methods.allowance(accounts[1], sushiRouterContractAddress).call();
    //
    //     if(allowance == 0) {
    //         await usdtContract.methods.approve(sushiRouterContractAddress, '9999999999999999999999999999999999').send({from: accounts[0]});
    //     }
    //
    //     await sushiRouterContract.methods.swapExactETHForTokens(
    //         0,
    //         [wethContractAddress, usdtContractAddress],
    //         accounts[0],
    //         '2644540023' // UNEX timestamp
    //     ).send({gas: '2000000', value: '1000000000000000000', from: accounts[0]});
    //
    //     await sushiRouterContract.methods.addLiquidity(
    //         giftTokenAddress,
    //         usdtContractAddress, // USDT address
    //         transferValue, // 500 GIFT tokens
    //         '100000000', // 100 USDT tokens (decimal 6)
    //         0,
    //         0,
    //         accounts[0],
    //         '99999999999999'
    //     ).send({gas: '5000000', from: accounts[0]});
    //
    //     const prevBalance = BN(await this.gift.balanceOf(accounts[0], {from: accounts[0]})).toString();
    //
    //     await sushiRouterContract.methods.swapExactTokensForTokens(
    //         '100000000000000000000', // 100 tokens
    //         0,
    //         [giftTokenAddress, usdtContractAddress],
    //         accounts[1],
    //         '2644540023' // UNEX timestamp
    //     ).send({gas: '3000000', from: accounts[0]});
    //
    //     const balance = BN(await this.gift.balanceOf(accounts[0], {from: accounts[0]})).toString();
    //
    //     console.log(initialBalance);
    //     console.log(prevBalance);
    //     console.log(balance);
    //     expect(
    //         prevBalance).to.not.equal(balance);
    // });
    //
    // it('adding liquidity and swapping exact GIFT for USDT supporting fees (15)', async function () {
    //     //add liquidity GIFT/ETH to sushiswap
    //     giftTokenAddress = web3.utils.toChecksumAddress(this.gift.address);
    //
    //     await this.gift.setBeneficiary(accounts[4], {from: accounts[0]});
    //     await this.gift.approve(sushiRouterContractAddress, totalSupply, {from: accounts[1]});
    //
    //     const allowance = await usdtContract.methods.allowance(accounts[1], sushiRouterContractAddress).call();
    //
    //     if(allowance == 0) {
    //         await usdtContract.methods.approve(sushiRouterContractAddress, '9999999999999999999999999999999999').send({from: accounts[1]});
    //     }
    //
    //     await this.gift.transfer(accounts[1], '5000000000000000000000', {from: accounts[0]}); // transfer 5000 tokens
    //
    //     const initialBalance = BN(await this.gift.balanceOf(accounts[1], {from: accounts[1]})).toString();
    //
    //     await sushiRouterContract.methods.swapExactETHForTokens(
    //         0,
    //         [wethContractAddress, usdtContractAddress],
    //         accounts[1],
    //         '2644540023' // UNEX timestamp
    //     ).send({gas: '2000000', value: '1000000000000000000', from: accounts[1]});
    //
    //     await sushiRouterContract.methods.addLiquidity(
    //         giftTokenAddress,
    //         usdtContractAddress, // USDT address
    //         transferValue, // 500 GIFT tokens
    //         '100000000', // 100 USDT tokens (decimal 6)
    //         0,
    //         0,
    //         accounts[1],
    //         '99999999999999'
    //     ).send({gas: '5000000', from: accounts[1]});
    //
    //     const prevBalance = BN(await this.gift.balanceOf(accounts[1], {from: accounts[1]})).toString();
    //
    //     await sushiRouterContract.methods.swapExactTokensForTokensSupportingFeeOnTransferTokens(
    //         '1000000000000000000', // 1 token
    //         0,
    //         [giftTokenAddress, usdtContractAddress],
    //         accounts[1],
    //         '2644540023' // UNEX timestamp
    //     ).send({gas: '3000000', from: accounts[1]});
    //
    //     const balance = BN(await this.gift.balanceOf(accounts[1], {from: accounts[1]})).toString();
    //
    //     console.log(initialBalance);
    //     console.log(prevBalance);
    //     console.log(balance);
    //     expect(
    //         prevBalance).to.not.equal(balance);
    // });
    //
    // it('adding liquidity and swapping GIFT for exact ETH (16)', async function () {
    //     //add liquidity GIFT/ETH to sushiswap
    //     giftTokenAddress = web3.utils.toChecksumAddress(this.gift.address);
    //
    //     const initialBalance = BN(await this.gift.balanceOf(accounts[0], {from: accounts[0]})).toString();
    //     await this.gift.setBeneficiary(accounts[4], {from: accounts[0]});
    //     await this.gift.approve(sushiRouterContractAddress, totalSupply, {from: accounts[0]});
    //
    //     await sushiRouterContract.methods.addLiquidityETH(
    //         giftTokenAddress,
    //         transferValue, // 500 tokens
    //         0,
    //         0,
    //         accounts[0],
    //         '99999999999999'
    //     ).send({gas: '5000000', value: '1000000000000000000', from: accounts[0]});
    //
    //     const prevBalance = BN(await this.gift.balanceOf(accounts[0], {from: accounts[0]})).toString();
    //
    //     await sushiRouterContract.methods.swapTokensForExactETH(
    //         '10000000000000000', // 0.01 ETH
    //         '100000000000000000000', // 100 tokens
    //         [giftTokenAddress, wethContractAddress],
    //         accounts[0],
    //         '2644540023' // UNEX timestamp
    //     ).send({gas: '3000000', from: accounts[0]});
    //
    //     const balance = BN(await this.gift.balanceOf(accounts[0], {from: accounts[0]})).toString();
    //
    //     console.log(initialBalance);
    //     console.log(prevBalance);
    //     console.log(balance);
    //     expect(
    //         prevBalance).to.not.equal(balance);
    // });
    //
    // it('adding liquidity and swapping GIFT for exact USDT (17)', async function () {
    //     //add liquidity GIFT/ETH to sushiswap
    //     giftTokenAddress = web3.utils.toChecksumAddress(this.gift.address);
    //
    //     const initialBalance = BN(await this.gift.balanceOf(accounts[0], {from: accounts[0]})).toString();
    //
    //     await this.gift.setBeneficiary(accounts[4], {from: accounts[0]});
    //     await this.gift.approve(sushiRouterContractAddress, totalSupply, {from: accounts[0]});
    //
    //     await sushiRouterContract.methods.swapExactETHForTokens(
    //         0,
    //         [wethContractAddress, usdtContractAddress],
    //         accounts[0],
    //         '2644540023' // UNEX timestamp
    //     ).send({gas: '2000000', value: '1000000000000000000', from: accounts[0]});
    //
    //     await sushiRouterContract.methods.addLiquidity(
    //         giftTokenAddress,
    //         usdtContractAddress, // USDT address
    //         transferValue, // 500 GIFT tokens
    //         '100000000', // 100 USDT tokens (decimal 6)
    //         0,
    //         0,
    //         accounts[0],
    //         '99999999999999'
    //     ).send({gas: '5000000', from: accounts[0]});
    //
    //     const prevBalance = BN(await this.gift.balanceOf(accounts[0], {from: accounts[0]})).toString();
    //
    //     await sushiRouterContract.methods.swapTokensForExactTokens(
    //         '1000000', // 1 USDT token
    //         '100000000000000000000', // 100 GIFT tokens
    //         [giftTokenAddress, usdtContractAddress],
    //         accounts[0],
    //         '2644540023' // UNEX timestamp
    //     ).send({gas: '3000000', from: accounts[0]});
    //
    //     const balance = BN(await this.gift.balanceOf(accounts[0], {from: accounts[0]})).toString();
    //
    //     console.log(initialBalance);
    //     console.log(prevBalance);
    //     console.log(balance);
    //     expect(
    //         prevBalance).to.not.equal(balance);
    // });
    //
    // it('adding and removing liquidity GIFT/ETH', async function () {
    //     //add liquidity GIFT/ETH to sushiswap
    //     giftTokenAddress = web3.utils.toChecksumAddress(this.gift.address);
    //
    //     await this.gift.setBeneficiary(accounts[4], {from: accounts[0]});
    //     await this.gift.approve(sushiRouterContractAddress, totalSupply, {from: accounts[0]});
    //
    //     const initialBalance = BN(await this.gift.balanceOf(accounts[0])).toString();
    //
    //     await sushiRouterContract.methods.addLiquidityETH(
    //         giftTokenAddress,
    //         '10000000000000000000000000', // 1 million GIFT tokens
    //         0,
    //         0,
    //         accounts[0],
    //         '99999999999999'
    //     ).send({gas: '5000000', value: '1000000000000000000', from: accounts[0]});
    //
    //     const prevBalance = BN(await this.gift.balanceOf(accounts[0])).toString();
    //
    //     const sushiPairAddress = await sushiFactoryContract.methods.getPair(giftTokenAddress, wethContractAddress).call();
    //     console.log(sushiPairAddress);
    //     const sushiPairContract = await new web3.eth.Contract(sushiPairABI, sushiPairAddress);
    //
    //     const lpBalance = await sushiPairContract.methods.balanceOf(accounts[0]).call();
    //     console.log(lpBalance);
    //
    //     await sushiPairContract.methods.approve(sushiRouterContractAddress, '99999999999999999999999').send({gas: '5000000', from: accounts[0]});
    //
    //     await sushiRouterContract.methods.removeLiquidityETHSupportingFeeOnTransferTokens(
    //         giftTokenAddress,
    //         lpBalance,
    //         0,
    //         0,
    //         accounts[0],
    //         '99999999999999'
    //     ).send({gas: '5000000', from: accounts[0]});
    //
    //     const balance = BN(await this.gift.balanceOf(accounts[0])).toString();
    //
    //     console.log(initialBalance);
    //     console.log(prevBalance);
    //     console.log(balance);
    //     expect(
    //         prevBalance).to.not.equal(balance);
    // });
    //
    // it('swapping', async function () {
    //     //swapping ETH for USDT on sushiswap
    //
    //     await sushiRouterContract.methods.swapExactETHForTokens(
    //         0,
    //         [wethContractAddress, usdtContractAddress],
    //         accounts[1],
    //         '2644540023' // UNEX timestamp
    //     ).send({gas: '2000000', value: '10000000000000000', from: accounts[5]});
    //
    //     expect(
    //         1).to.be.greaterThan(0);
    // });

});