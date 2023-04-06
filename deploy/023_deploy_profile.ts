import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  await hre.helpers.deploy({
    newContractName: 'Profile',
    dependencies: func.dependencies,
  });
};

export default func;
func.tags = ['Profile'];
func.dependencies = [
  'Hub',
  'Identity',
  'IdentityStorage',
  'ParametersStorage',
  'ProfileStorage',
  'HashingProxy',
  'SHA256',
  'Staking',
  'WhitelistStorage',
];
