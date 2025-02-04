import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { deployments, ethers } from "hardhat";

const { deploy } = deployments;
let deployer: SignerWithAddress;

// mainnet
const timelockAddress = "0xca3171A5FCda4D840Aa375E907b7A1162aDA9379";
const proxyAdminAddress = "0xFC641CE792c242EACcD545B7bee2028f187f61EC";
const communityAdminProxyAddress = "0xd61c407c3A00dFD8C355973f7a14c55ebaFDf6F9";
const signerWalletAddress = "0x0000000000000000000000000000000000000000";

// // alfajores
// const timelockAddress = "0xcb0C15AdE117C812E4d96165472EbF83Bed231B0";
// const proxyAdminAddress = "0x79f9ca5f1A01e1768b9C24AD37FF63A0199E3Fe5";
// const communityAdminProxyAddress = "0x1c33D75bcE52132c7a0e220c1C338B9db7cf3f3A";
// const signerWalletAddress = "0x0000000000000000000000000000000000000000";


const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
	const accounts: SignerWithAddress[] = await ethers.getSigners();
	deployer = accounts[0];

	await deployLearnAndEarn();
};

async function deployLearnAndEarn() {
	console.log("Deploying LearnAndEarn contracts");

	const LearnAndEarnImplementationResult = await deploy("LearnAndEarnImplementation", {
		from: deployer.address,
		args: [],
		log: true,
		// gasLimit: 13000000,
	});

	await new Promise((resolve) => setTimeout(resolve, 6000));
	const LearnAndEarnProxyResult = await deploy("LearnAndEarnProxy", {
		from: deployer.address,
		args: [LearnAndEarnImplementationResult.address, proxyAdminAddress],
		log: true,
		// gasLimit: 13000000,
	});

	const LearnAndEarnContract = await ethers.getContractAt(
		"LearnAndEarnImplementation",
		LearnAndEarnProxyResult.address
	);

	await new Promise((resolve) => setTimeout(resolve, 6000));
	await LearnAndEarnContract.initialize(
		signerWalletAddress,
		communityAdminProxyAddress
	);

	await new Promise((resolve) => setTimeout(resolve, 6000));
	await LearnAndEarnContract.transferOwnership(timelockAddress);
}

export default func;
func.tags = ["LearnAndEarn"];
