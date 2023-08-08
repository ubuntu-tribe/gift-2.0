const { getImplementationAddress } = require("@openzeppelin/upgrades-core");
const { ethers, upgrades } = require("hardhat");
const { waitBlocks } = require("../utils/blockWaiter");

async function main() {
  const signers = await ethers.getSigners();

  const Access = await ethers.getContractFactory("Access");
  const access = await upgrades.upgradeProxy("0x2A51414644C14A42f83707E5D31101ce826C5A60", Access);
  await access.deployed();
  await waitBlocks(5);
  const accessImpl = await getImplementationAddress(
    ethers.provider,
    access.address
  );

  console.log(`Access deployed to: ${ access.address } => ${ accessImpl }`);
  await run("verify:verify", {
    address: accessImpl,
    contract: "contracts/Access.sol:Access",
  });

  const Reserve = await ethers.getContractFactory("ReserveConsumerV3");
  const reserve = await upgrades.upgradeProxy("0x2A51414644C14A42f83707E5D31101ce826C5A60", Reserve);
  await reserve.deployed();
  await waitBlocks(5);
  const reserveImpl = await getImplementationAddress(
    ethers.provider,
    reserve.address
  );

  console.log(`Access deployed to: ${ reserve.address } => ${ reserveImpl }`);
  await run("verify:verify", {
    address: reserveImpl,
    contract: "contracts/por/ReserveConsumerV3.sol:ReserveConsumerV3",
  });

  const Token = await ethers.getContractFactory("GIFT");
  const token = await upgrades.upgradeProxy("0x1994Fd475c4769138A6f834141DAEc362516497F", Token);
  await token.deployed();
  await waitBlocks(5);
  const tokenImpl = await getImplementationAddress(
    ethers.provider,
    token.address
  );
  console.log(`Token deployed to: ${ token.address } => ${ tokenImpl }`);
  await run("verify:verify", {
    address: tokenImpl,
    contract: "contracts/token/GIFT.sol:GIFT",
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
