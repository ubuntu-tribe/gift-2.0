// scripts/index.js
module.exports = async function main (callback) {
    try {
        // Our code will go here

        // Retrieve accounts from the local node
        const accounts = await web3.eth.getAccounts();
        console.log(accounts)

        // Set up a Truffle contract, representing our deployed GIFT instance
        const GIFT = artifacts.require('GIFT');
        const gift = await GIFT.deployed();

        // // Call the totalSupply() function of the deployed GIFT contract
        // const totalSupply = await gift.totalSupply();
        // console.log('GIFT totalSupply is', totalSupply.toString());
        //
        // // return owner address
        // const owner = await gift.owner();
        // console.log('GIFT owner is', owner.toString());
        //
        // // Check balance of address before transfer
        // const prevBalance = await gift.balanceOf(accounts[1]);
        // console.log('address prevBalance is', prevBalance.toString());
        //
        // await gift.transfer(accounts[1], '500000000000000000000000');
        //
        // // Check balance of address after transfer
        // const newBalance = await gift.balanceOf(accounts[1]);
        // console.log('address newBalance is', newBalance.toString());

        // // test setSupplyController()
        // const supplyController = await gift.supplyController();
        // console.log('supplyController is', supplyController);
        //
        // await gift.setSupplyController(accounts[2]);
        //
        // const newSupplyController = await gift.supplyController();
        // console.log('newSupplyController is', newSupplyController);
        //
        // await gift.setSupplyController(accounts[1], {from: accounts[1]});

        // // test setBeneficiary()
        // const beneficiary = await gift.beneficiary();
        // console.log('beneficiary is', beneficiary);
        //
        // await gift.setBeneficiary(accounts[0]);
        //
        // const newBeneficiary = await gift.beneficiary();
        // console.log('newBeneficiary is', newBeneficiary);


        callback(0);
    } catch (error) {
        console.error(error);
        callback(1);
    }
};