const { getImplementationAddress } = require("@openzeppelin/upgrades-core");
const { ethers, upgrades } = require("hardhat");
const { waitBlocks } = require("../utils/blockWaiter");

async function main() {
  const signers = await ethers.getSigners();

  const ACCESS = await ethers.getContractFactory("Access");
  const access = await upgrades.deployProxy(ACCESS, []);
  await access.deployed();
  await waitBlocks(5);
  const accessImpl = await getImplementationAddress(
    ethers.provider,
    access.address
  );
  console.log(`access deployed to: ${ access.address } => ${ accessImpl }`);
  await run("verify:verify", {
    address: accessImpl,
    contract: "contracts/Access.sol:Access",
  });

  // Cand be commented and deployed separately after the PoR is created
  const porAddress = '0x0000000000000000000000000000000000000000'
  const ReserveConsumerV3 = await ethers.getContractFactory("ReserveConsumerV3");
  const reserveConsumerV3 = await upgrades.deployProxy(ReserveConsumerV3, [porAddress]);
  await reserveConsumerV3.deployed();
  await waitBlocks(5);
  const reserveConsumerV3Impl = await getImplementationAddress(
    ethers.provider,
    reserveConsumerV3.address
  );
  
  console.log(`reserveConsumerV3 deployed to: ${ reserveConsumerV3.address } => ${ reserveConsumerV3Impl }`);
  
  await run("verify:verify", {
    address: reserveConsumerV3Impl,
    contract: "contracts/por/ReserveConsumerV3.sol:ReserveConsumerV3",
  });

  const GIFT = await ethers.getContractFactory("GIFT");
  const gift = await upgrades.deployProxy(GIFT,
    [
      access.address,
      porAddress == '0x0000000000000000000000000000000000000000' ? '0x0000000000000000000000000000000000000000' :reserveConsumerV3.address,
    ]
  );
  await gift.deployed();
  await waitBlocks(5);
  const giftImpl = await getImplementationAddress(
    ethers.provider,
    gift.address
  );
  console.log(`GIFT deployed to: ${ gift.address } => ${ giftImpl }`);
  await run("verify:verify", {
    address: giftImpl,
    contract: "contracts/token/GIFT.sol:GIFT",
  });

  await access.updateSignValidationWhitelist(gift.address, true);
  await access.updateSenders(signers[0].address, true);

  console.log("DONE!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

