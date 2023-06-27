const hre = require("hardhat");

const main = async () => {
  try {
    const nftContractFactory = await hre.ethers.getContractFactory(
      "BullBearToken"
    );

    const interval = 900;
    const priceFeedAddress = "0x1b44f3514812d835eb1bdb0acb33d3fa3351ee43";
    const vrfCoordinatorAddress = "0x8103b0a8a00be2ddc778e6e7eaa21791cd364625";
    const subscriptionId = 2826;
    const gasLane =
      "0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c";
    const callbackGasLimit = 500000;

    const nftContract = await nftContractFactory.deploy(
      interval,
      priceFeedAddress,
      vrfCoordinatorAddress,
      subscriptionId,
      gasLane,
      callbackGasLimit
    );

    await nftContract.waitForDeployment();

    console.log("Contract deployed to:", await nftContract.getAddress());

    process.exit(0);
  } catch (error) {
    console.log(error);

    process.exit(1);
  }
};

main();
