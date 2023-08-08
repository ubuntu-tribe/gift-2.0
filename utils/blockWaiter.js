const waitBlocks = async (num) => {
  const startBlock = await getBlock();
  const counter = new Array((num + 1) * 30).fill(0);
  for (const i in counter) {
    const currentBlock = await getBlock();
    if (currentBlock > startBlock + num) {
      return;
    } else {
      await sleep(1000);
    }
  }
};

const getBlock = async () => {
  const currentBlock = Number(
    (await ethers.provider.getBlock("latest")).number
  );
  return currentBlock;
};

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

module.exports = { waitBlocks };
