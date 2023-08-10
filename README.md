# Gift 2.0 Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a script that deploys that contract.

Try running some of the following tasks:

node version required: 18.17.0

```sh
nvm use 18.17.0
```

```sh
yarn install
npm install web3-utils
npx hardhat help
npx hardhat test
npx hardhat test test/gift_zero_consumer_init_supply.js
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.js --network polygon
npx hardhat run scripts/update.js
```shell

```


Backend transfers guide example:


```js
1. ethers install
2. npm install ethers
3. On the backend side estimate the gas for the transaction and generate bytes32hex
4. Send bytes32hex and extimation to the frontend
5. On the frontend side, sign the message with the bytes32hex and the estimation
6. Send the signed message to the backend
7. On the backend side, send the transaction with the signed message

      const bytes32hex = ethers.utils.randomBytes(32);
      
      let message = await contracts.gift.delegateTransferProof(
        bytes32hex,
        signers[5].address,
        signers[6].address,
        ethers.utils.parseEther("1"),
        0
      );
      
      // metamask sign message
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

      await expect(actualBalance).to.equal(expectedBalance);


