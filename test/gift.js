const { ethers, upgrades } = require("hardhat");
const { expect } = require("chai");
const BigNumber = require("bignumber.js");

describe("GIFT token", function () {
  async function deploy() {
    signers = await ethers.getSigners();
    sellingWallet = signers[0];
    sender = signers[1];
    beneficiary = signers[2];

    const Access = await ethers.getContractFactory("Access");
    access = await upgrades.deployProxy(Access, []);
    await access.deployed();

    const ReserveConsumerV3 = await ethers.getContractFactory("ReserveConsumerV3");
    reserveConsumerV3 = await upgrades.deployProxy(ReserveConsumerV3, ['0x4e9fc7480c16F3FE5d956C0759eE6b4808d1F5D7']);
    await reserveConsumerV3.deployed();

    const GIFT = await ethers.getContractFactory("GIFT");
    gift = await upgrades.deployProxy(GIFT, [
      access.address,
      reserveConsumerV3.address,
    ]);
    await gift.deployed();

    // Set up access
    await access.updateSignValidationWhitelist(gift.address, true);
    await access.updateSenders(sender.address, true);
    await gift.setSupplyController(sellingWallet.address);
    await gift.setBeneficiary(beneficiary.address);

    console.log("Setup access DONE!");

    return { gift, access, reserveConsumerV3 };
  }

  let signers;
  let sender;
  let beneficiary;
  let sellingWallet;
  let gift;
  let access;
  let reserveConsumerV3;


  describe("Deployment", function () {

    before(async function () {
      // Get the Contract and Signers here.
      contracts = await deploy();
    });

    it("Should set the right owner", async function () {
      console.log("gift owner: ", await contracts.gift.owner());
      expect(await contracts.gift.owner()).to.equal(sellingWallet.address);
    });

    it("Should have correct name and symbol and decimal", async function () {
      expect(await contracts.gift.name()).to.equal("GIFT");
      expect(await contracts.gift.symbol()).to.equal("GIFT");
      expect(await contracts.gift.decimals()).to.equal(18);
    });

    it("Should have correct total supply", async function () {
      expect(await contracts.gift.totalSupply()).to.equal(ethers.utils.parseEther("0"));
    });

    it("Should have correct reserve address", async function () {
      expect(await contracts.gift.reserveConsumer()).to.equal(contracts.reserveConsumerV3.address);
    });

    it("Should have correct access address", async function () {
      expect(await contracts.gift.accessControl()).to.equal(contracts.access.address);
    });

    it("Should have correct selling wallet address", async function () {
      expect(await contracts.gift.supplyController()).to.equal(sellingWallet.address);
    });

    it("Reserve consumer should have correct functionality", async function () {
      expect(await contracts.reserveConsumerV3.getLatestReserve()).to.not.equal("0");
    });

  });

  describe("Minting", function () {

    before(async function () {
      // Get the Contract and Signers here.
      contracts = await deploy();
    });

    it("Should mint 1 GIFT with increase supply", async function () {
      await contracts.gift.increaseSupply(ethers.utils.parseEther("1"));
      expect(await contracts.gift.totalSupply()).to.equal(ethers.utils.parseEther("1"));
    });

    it("Only supply controller can mint", async function () {
      await expect(contracts.gift.connect(sender).increaseSupply(ethers.utils.parseEther("1")))
        .to.be.revertedWith("caller is not the supplyController");
    });

    it("Can mint up to reserveConsumer reserve", async function () {
      const reserve = await contracts.reserveConsumerV3.getLatestReserve();
      const reserveBN = (new BigNumber(reserve.toString())).multipliedBy(1e10);
      await contracts.gift.increaseSupply(reserveBN.minus(1e18).toString());
      expect(await contracts.gift.totalSupply()).to.equal(reserveBN.toString());
    })

    it("Shouldnt mint more than reserveConsumer reserve", async function () {
      const reserve = await contracts.reserveConsumerV3.getLatestReserve();
      const reserveBN = (new BigNumber(reserve.toString())).multipliedBy(1e10);
      await expect(contracts.gift.increaseSupply(ethers.utils.parseEther("1")))
        .to.be.revertedWith("GIFT reserve: underlying supply exceeds proof-of-reserves");
    })

  });

  describe("Transfer", function () {

    before(async function () {
      // Get the Contract and Signers here.
      contracts = await deploy();
      const reserve = await contracts.reserveConsumerV3.getLatestReserve();
      const reserveBN = (new BigNumber(reserve.toString())).multipliedBy(1e10);
      await contracts.gift.increaseSupply(reserveBN.minus(1e18).toString());

    });

    it("Should transfer 10 GIFT from selling wallet to sender", async function () {
      await contracts.gift.transfer(sender.address, ethers.utils.parseEther("10"));
      expect(await contracts.gift.balanceOf(sender.address)).to.equal(ethers.utils.parseEther("10"));
    });

    it("Should transfer 5 GIFT from sender to random wallet", async function () {
      await contracts.gift.connect(sender).transfer(signers[5].address, ethers.utils.parseEther("5"));
      expect(await contracts.gift.balanceOf(sender.address)).to.equal(ethers.utils.parseEther("5"));
    });

    it("Beneficiary should get his fee", async function () {
      const tax = await contracts.gift.computeTax(ethers.utils.parseEther("5"));
      expect(await contracts.gift.balanceOf(beneficiary.address)).to.equal(new BigNumber(tax.toString()).toString());
    })

    it("Should not transfer 10 GIFT from sender to selling because of low balance", async function () {
      await expect(contracts.gift.connect(sender).transfer(sellingWallet.address, ethers.utils.parseEther("10")))
        .to.be.revertedWith("ERC20: transfer amount exceeds balance");
    });

    it("Shloud transfer 1 gift with delegated Transfer", async function () {

      await contracts.gift.transfer(signers[5].address, ethers.utils.parseEther("1"));

      const bytes32hex = ethers.utils.randomBytes(32);

      let message = await contracts.gift.delegateTransferProof(
        bytes32hex,
        signers[5].address,
        signers[6].address,
        ethers.utils.parseEther("1"),
        0
      );
      let signature = await signers[5].signMessage(
        ethers.utils.arrayify(message)
      );
      const estimation = await contracts.gift.estimateGas.delegateTransfer(
        signature,
        bytes32hex,
        signers[5].address,
        signers[6].address,
        ethers.utils.parseEther("1"),
        0
      );

      message = await contracts.gift.delegateTransferProof(
        bytes32hex,
        signers[5].address,
        signers[6].address,
        ethers.utils.parseEther("1"),
        estimation.toString()
      );
      signature = await signers[5].signMessage(
        ethers.utils.arrayify(message)
      );
      await contracts.gift.delegateTransfer(
        signature,
        bytes32hex,
        signers[5].address,
        signers[6].address,
        ethers.utils.parseEther("1"),
        estimation.toString()
      );
      const tax = await contracts.gift.computeTax(ethers.utils.parseEther("1"));
      const expectedBalance = new BigNumber(ethers.utils.parseEther("1").toString()).minus(new BigNumber(tax.toString())).toString();
      const actualBalance = await contracts.gift.balanceOf(signers[6].address);

      await expect(actualBalance).to.equal(expectedBalance);

    });


  });

});
