// migrations/gift-erc20-token/2_deploy.js
const GIFT = artifacts.require('GIFT');

module.exports = async function (deployer) {
    await deployer.deploy(GIFT);
};