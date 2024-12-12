import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  await hre.helpers.deploy({
    newContractName: 'KnowledgeCollectionStorage',
  });
};

export default func;
func.tags = ['KnowledgeCollectionStorage'];
func.dependencies = [];
