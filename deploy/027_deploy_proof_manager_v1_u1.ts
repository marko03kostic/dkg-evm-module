import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  await hre.helpers.deploy({
    newContractName: 'ProofManagerV1U1',
    dependencies: func.dependencies,
  });
};

export default func;
func.tags = ['ProofManagerV1U1'];
func.dependencies = [
  'AssertionStorage',
  'Hub',
  'IdentityStorage',
  'ParametersStorage',
  'ProfileStorage',
  'ServiceAgreementStorageProxy',
  'HashingProxy',
  'SHA256',
  'Staking',
];
