// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import {HashingProxy} from "./HashingProxy.sol";
import {ScoringProxy} from "./ScoringProxy.sol";
import {Staking} from "./Staking.sol";
import {IdentityStorage} from "./storage/IdentityStorage.sol";
import {ParametersStorage} from "./storage/ParametersStorage.sol";
import {ProfileStorage} from "./storage/ProfileStorage.sol";
import {ServiceAgreementStorageProxy} from "./storage/ServiceAgreementStorageProxy.sol";
import {ShardingTableStorageV2} from "../v2/storage/ShardingTableStorage.sol";
import {StakingStorage} from "./storage/StakingStorage.sol";
import {ContractStatus} from "./abstract/ContractStatus.sol";
import {Initializable} from "./interface/Initializable.sol";
import {Named} from "./interface/Named.sol";
import {Versioned} from "./interface/Versioned.sol";
import {ContentAssetErrors} from "./errors/assets/ContentAssetErrors.sol";
import {GeneralErrors} from "./errors/GeneralErrors.sol";
import {ServiceAgreementErrorsV1} from "./errors/ServiceAgreementErrorsV1.sol";
import {ServiceAgreementErrorsV1New} from "./errors/ServiceAgreementErrorsV1New.sol";
import {ServiceAgreementStructsV1} from "./structs/ServiceAgreementStructsV1.sol";
import {ShardingTableStructs} from "../v2/structs/ShardingTableStructs.sol";
import {CommitManagerErrorsV1} from "./errors/CommitManagerErrorsV1.sol";

contract CommitManagerV1New is Named, Versioned, ContractStatus, Initializable {
    event CommitSubmitted(
        address indexed assetContract,
        uint256 indexed tokenId,
        bytes keyword,
        uint8 hashFunctionId,
        uint16 epoch,
        uint72 indexed identityId,
        uint40 score
    );

    string private constant _NAME = "CommitManagerV1-new";
    string private constant _VERSION = "1.0.1";

    bool[4] public reqs = [false, false, false, false];

    HashingProxy public hashingProxy;
    ScoringProxy public scoringProxy;
    Staking public stakingContract;
    IdentityStorage public identityStorage;
    ParametersStorage public parametersStorage;
    ProfileStorage public profileStorage;
    ServiceAgreementStorageProxy public serviceAgreementStorageProxy;
    ShardingTableStorageV2 public shardingTableStorage;
    StakingStorage public stakingStorage;

    uint256 constant HASH_RING_SIZE = type(uint256).max;

    // solhint-disable-next-line no-empty-blocks
    constructor(address hubAddress) ContractStatus(hubAddress) {}

    function initialize() public onlyHubOwner {
        hashingProxy = HashingProxy(hub.getContractAddress("HashingProxy"));
        scoringProxy = ScoringProxy(hub.getContractAddress("ScoringProxy"));
        stakingContract = Staking(hub.getContractAddress("Staking"));
        identityStorage = IdentityStorage(hub.getContractAddress("IdentityStorage"));
        parametersStorage = ParametersStorage(hub.getContractAddress("ParametersStorage"));
        profileStorage = ProfileStorage(hub.getContractAddress("ProfileStorage"));
        serviceAgreementStorageProxy = ServiceAgreementStorageProxy(
            hub.getContractAddress("ServiceAgreementStorageProxy")
        );
        shardingTableStorage = ShardingTableStorageV2(hub.getContractAddress("ShardingTableStorage"));
        stakingStorage = StakingStorage(hub.getContractAddress("StakingStorage"));
    }

    function name() external pure virtual override returns (string memory) {
        return _NAME;
    }

    function version() external pure virtual override returns (string memory) {
        return _VERSION;
    }

    function isCommitWindowOpen(bytes32 agreementId, uint16 epoch) public view returns (bool) {
        ServiceAgreementStorageProxy sasProxy = serviceAgreementStorageProxy;

        if (!sasProxy.agreementV1Exists(agreementId))
            revert ServiceAgreementErrorsV1.ServiceAgreementDoesntExist(agreementId);

        uint256 startTime = sasProxy.getAgreementStartTime(agreementId);

        ParametersStorage params = parametersStorage;
        uint128 epochLength = sasProxy.getAgreementEpochLength(agreementId);

        if (epoch >= sasProxy.getAgreementEpochsNumber(agreementId))
            revert ServiceAgreementErrorsV1.ServiceAgreementHasBeenExpired(
                agreementId,
                startTime,
                sasProxy.getAgreementEpochsNumber(agreementId),
                epochLength
            );

        uint256 timeNow = block.timestamp;
        uint256 commitWindowDuration = (params.commitWindowDurationPerc() * epochLength) / 100;

        if (epoch == 0) {
            return timeNow < (startTime + commitWindowDuration);
        }

        return (timeNow >= (startTime + epochLength * epoch) &&
            timeNow < (startTime + epochLength * epoch + commitWindowDuration));
    }

    function getTopCommitSubmissions(
        bytes32 agreementId,
        uint16 epoch
    ) external view returns (ServiceAgreementStructsV1.CommitSubmission[] memory) {
        ServiceAgreementStorageProxy sasProxy = serviceAgreementStorageProxy;

        if (!sasProxy.agreementV1Exists(agreementId))
            revert ServiceAgreementErrorsV1.ServiceAgreementDoesntExist(agreementId);
        if (epoch >= sasProxy.getAgreementEpochsNumber(agreementId))
            revert ServiceAgreementErrorsV1.ServiceAgreementHasBeenExpired(
                agreementId,
                sasProxy.getAgreementStartTime(agreementId),
                sasProxy.getAgreementEpochsNumber(agreementId),
                sasProxy.getAgreementEpochLength(agreementId)
            );

        uint32 r0 = parametersStorage.r0();

        ServiceAgreementStructsV1.CommitSubmission[]
            memory epochCommits = new ServiceAgreementStructsV1.CommitSubmission[](r0);

        bytes32 epochSubmissionsHead = sasProxy.getV1AgreementEpochSubmissionHead(agreementId, epoch);

        epochCommits[0] = sasProxy.getCommitSubmission(epochSubmissionsHead);

        bytes32 commitId;
        uint72 nextIdentityId = epochCommits[0].nextIdentityId;
        uint8 submissionsIdx = 1;
        while ((submissionsIdx < r0) && (nextIdentityId != 0)) {
            commitId = keccak256(abi.encodePacked(agreementId, epoch, nextIdentityId));
            epochCommits[submissionsIdx] = sasProxy.getCommitSubmission(commitId);

            nextIdentityId = epochCommits[submissionsIdx].nextIdentityId;

            unchecked {
                submissionsIdx++;
            }
        }

        return epochCommits;
    }

    function submitCommit(ServiceAgreementStructsV1.CommitInputArgs calldata args) external {
        ServiceAgreementStorageProxy sasProxy = serviceAgreementStorageProxy;

        bytes32 agreementId = hashingProxy.callHashFunction(
            args.hashFunctionId,
            abi.encodePacked(args.assetContract, args.tokenId, args.keyword)
        );

        if (!sasProxy.agreementV1Exists(agreementId))
            revert ServiceAgreementErrorsV1.ServiceAgreementDoesntExist(agreementId);

        if (!reqs[0] && !isCommitWindowOpen(agreementId, args.epoch)) {
            uint128 epochLength = sasProxy.getAgreementEpochLength(agreementId);

            uint256 actualCommitWindowStart = (sasProxy.getAgreementStartTime(agreementId) + args.epoch * epochLength);

            revert ServiceAgreementErrorsV1.CommitWindowClosed(
                agreementId,
                args.epoch,
                actualCommitWindowStart,
                actualCommitWindowStart + (parametersStorage.commitWindowDurationPerc() * epochLength) / 100,
                block.timestamp
            );
        }

        uint72 identityId = identityStorage.getIdentityId(msg.sender);

        if (!reqs[1] && !shardingTableStorage.nodeExists(identityId)) {
            ProfileStorage ps = profileStorage;

            revert ServiceAgreementErrorsV1.NodeNotInShardingTable(
                identityId,
                ps.getNodeId(identityId),
                ps.getAsk(identityId),
                stakingStorage.totalStakes(identityId)
            );
        }

        uint8 agreementScoreFunctionId = sasProxy.getAgreementScoreFunctionId(agreementId);

        if (agreementScoreFunctionId != 2) {
            revert ServiceAgreementErrorsV1New.WrongScoreFunctionId(
                agreementId,
                args.epoch,
                agreementScoreFunctionId,
                2,
                block.timestamp
            );
        }

        if (!shardingTableStorage.nodeExists(args.closestNode)) {
            ProfileStorage ps = profileStorage;

            revert ServiceAgreementErrorsV1.NodeNotInShardingTable(
                args.closestNode,
                ps.getNodeId(args.closestNode),
                ps.getAsk(args.closestNode),
                stakingStorage.totalStakes(args.closestNode)
            );
        }

        if (!shardingTableStorage.nodeExists(args.leftNeighbourHoodEdge)) {
            ProfileStorage ps = profileStorage;

            revert ServiceAgreementErrorsV1.NodeNotInShardingTable(
                args.leftNeighbourHoodEdge,
                ps.getNodeId(args.leftNeighbourHoodEdge),
                ps.getAsk(args.leftNeighbourHoodEdge),
                stakingStorage.totalStakes(args.leftNeighbourHoodEdge)
            );
        }

        if (!shardingTableStorage.nodeExists(args.rightNeighbourHoodEdge)) {
            ProfileStorage ps = profileStorage;

            revert ServiceAgreementErrorsV1.NodeNotInShardingTable(
                args.rightNeighbourHoodEdge,
                ps.getNodeId(args.rightNeighbourHoodEdge),
                ps.getAsk(args.rightNeighbourHoodEdge),
                stakingStorage.totalStakes(args.rightNeighbourHoodEdge)
            );
        }

        ShardingTableStructs.Node memory closestNode = shardingTableStorage.getNode(args.closestNode);
        ShardingTableStructs.Node memory leftNeighbourhoodEdge = shardingTableStorage.getNode(
            args.leftNeighbourHoodEdge
        );
        ShardingTableStructs.Node memory rightNeighbourhoodEdge = shardingTableStorage.getNode(
            args.rightNeighbourHoodEdge
        );

        bool isBetween = (leftNeighbourhoodEdge.index > rightNeighbourhoodEdge.index)
            ? ((closestNode.index > leftNeighbourhoodEdge.index) || (closestNode.index < rightNeighbourhoodEdge.index))
            : ((closestNode.index > leftNeighbourhoodEdge.index) && (closestNode.index < rightNeighbourhoodEdge.index));

        if (!isBetween) {
            revert CommitManagerErrorsV1.closestNodeNotInNeighbourhood(
                agreementId,
                args.leftNeighbourHoodEdge,
                args.rightNeighbourHoodEdge,
                args.closestNode,
                args.epoch,
                block.timestamp
            );
        }

        uint256 numberOfNodes = shardingTableStorage.nodesCount();
        uint256 clockwiseDistance = (rightNeighbourhoodEdge.index + numberOfNodes - leftNeighbourhoodEdge.index) %
            numberOfNodes;
        uint256 counterclockwiseDistance = (leftNeighbourhoodEdge.index +
            numberOfNodes -
            rightNeighbourhoodEdge.index) % numberOfNodes;

        uint256 indexDistance = (clockwiseDistance < counterclockwiseDistance)
            ? clockwiseDistance
            : counterclockwiseDistance;

        //distance between 20 nodes is 19 (this shold be constant)
        if (!(indexDistance == 19)) {
            revert CommitManagerErrorsV1.negihbourhoodWrongSize(
                agreementId,
                args.leftNeighbourHoodEdge,
                args.rightNeighbourHoodEdge,
                numberOfNodes,
                20,
                indexDistance,
                args.epoch,
                block.timestamp
            );
        }

        uint256 hashRingNeighbourhoodDistance = calculateHashRingDistance(
            leftNeighbourhoodEdge.hashRingPosition,
            rightNeighbourhoodEdge.hashRingPosition
        );

        bytes32 keywordHash = hashingProxy.callHashFunction(args.hashFunctionId, args.keyword);
        bytes32 nodeIdHash = hashingProxy.callHashFunction(args.hashFunctionId, profileStorage.getNodeId(identityId));

        uint256 distance = calculateHashRingDistance(
            leftNeighbourhoodEdge.hashRingPosition,
            rightNeighbourhoodEdge.hashRingPosition
        );

        // uint40 score = scoringProxy.callScoreFunction(
        //     mappedDistance,
        //     mappedStake
        // );

        _insertCommit(agreementId, args.epoch, identityId, 0, 0, score);

        emit CommitSubmitted(
            args.assetContract,
            args.tokenId,
            args.keyword,
            args.hashFunctionId,
            args.epoch,
            identityId,
            score
        );
    }

    function setReq(uint256 index, bool req) external onlyHubOwner {
        reqs[index] = req;
    }

    function _insertCommit(
        bytes32 agreementId,
        uint16 epoch,
        uint72 identityId,
        uint72 prevIdentityId,
        uint72 nextIdentityId,
        uint40 score
    ) internal virtual {
        ServiceAgreementStorageProxy sasProxy = serviceAgreementStorageProxy;

        bytes32 commitId = keccak256(abi.encodePacked(agreementId, epoch, identityId));

        if (!reqs[2] && sasProxy.commitSubmissionExists(commitId))
            revert ServiceAgreementErrorsV1.NodeAlreadySubmittedCommit(
                agreementId,
                epoch,
                identityId,
                profileStorage.getNodeId(identityId)
            );

        bytes32 refCommitId = sasProxy.getV1AgreementEpochSubmissionHead(agreementId, epoch);

        ParametersStorage params = parametersStorage;

        uint72 refCommitNextIdentityId = sasProxy.getCommitSubmissionNextIdentityId(refCommitId);
        uint32 r0 = params.r0();
        uint8 i;
        while ((score < sasProxy.getCommitSubmissionScore(refCommitId)) && (refCommitNextIdentityId != 0) && (i < r0)) {
            refCommitId = keccak256(abi.encodePacked(agreementId, epoch, refCommitNextIdentityId));

            refCommitNextIdentityId = sasProxy.getCommitSubmissionNextIdentityId(refCommitId);
            unchecked {
                i++;
            }
        }

        if (!reqs[3] && (i >= r0))
            revert ServiceAgreementErrorsV1.NodeNotAwarded(
                agreementId,
                epoch,
                identityId,
                profileStorage.getNodeId(identityId),
                i
            );

        sasProxy.createV1CommitSubmissionObject(commitId, identityId, prevIdentityId, nextIdentityId, score);

        ServiceAgreementStructsV1.CommitSubmission memory refCommit = sasProxy.getCommitSubmission(refCommitId);

        if ((i == 0) && (refCommit.identityId == 0)) {
            //  No head -> Setting new head
            sasProxy.setV1AgreementEpochSubmissionHead(agreementId, epoch, commitId);
        } else if ((i == 0) && (score <= refCommit.score)) {
            // There is a head with higher or equal score, add new commit on the right
            _linkCommits(agreementId, epoch, refCommit.identityId, identityId);
        } else if ((i == 0) && (score > refCommit.score)) {
            // There is a head with lower score, replace the head
            sasProxy.setV1AgreementEpochSubmissionHead(agreementId, epoch, commitId);
            _linkCommits(agreementId, epoch, identityId, refCommit.identityId);
        } else if (score > refCommit.score) {
            // [H] - head
            // [RC] - reference commit
            // [RC-] - commit before reference commit
            // [RC+] - commit after reference commit
            // [NC] - new commit
            // [] <-> [H] <-> [X] ... [RC-] <-> [RC] <-> [RC+] ... [C] <-> []
            // [] <-> [H] <-> [X] ... [RC-] <-(NL)-> [NC] <-(NL)-> [RC] <-> [RC+] ... [C] <-> []
            _linkCommits(agreementId, epoch, refCommit.prevIdentityId, identityId);
            _linkCommits(agreementId, epoch, identityId, refCommit.identityId);
        } else {
            // [] <-> [H] <-> [RC] <-> []
            // [] <-> [H] <-> [RC] <-(NL)-> [NC] <-> []
            _linkCommits(agreementId, epoch, refCommit.identityId, identityId);
        }
    }

    function _linkCommits(
        bytes32 agreementId,
        uint16 epoch,
        uint72 leftIdentityId,
        uint72 rightIdentityId
    ) internal virtual {
        ServiceAgreementStorageProxy sasProxy = serviceAgreementStorageProxy;

        sasProxy.setCommitSubmissionNextIdentityId(
            keccak256(abi.encodePacked(agreementId, epoch, leftIdentityId)), // leftCommitId
            rightIdentityId
        );

        sasProxy.setCommitSubmissionPrevIdentityId(
            keccak256(abi.encodePacked(agreementId, epoch, rightIdentityId)), // rightCommitId
            leftIdentityId
        );
    }

    function calculateHashRingDistance(
        uint leftNodePositionOnHashRing,
        uint rightNodePositionOnHashRing
    ) private view returns (uint256) {
        uint256 directDistance = (leftNodePositionOnHashRing >= rightNodePositionOnHashRing)
            ? (leftNodePositionOnHashRing - rightNodePositionOnHashRing)
            : (rightNodePositionOnHashRing - leftNodePositionOnHashRing);

        uint256 reverseDistance = HASH_RING_SIZE - directDistance;

        return (directDistance < reverseDistance) ? directDistance : reverseDistance;
    }
}
