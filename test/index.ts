import { deployments, ethers } from 'hardhat'
import { UniswapV3Connector__factory } from '../typechain-types'

export async function deployDefaultFixture() {
    const [deployer, user0, user1] = await ethers.getSigners()

    const uniswapConnectorFactory = await ethers.getContractFactory('UniswapV3Connector') as UniswapV3Connector__factory

    const connector = await uniswapConnectorFactory.connect(deployer).deploy()

    await connector.waitForDeployment()

    return {
        signers: [deployer, user0, user1],
        uniswapConnectorFactory, connector
    }
}