// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./StoryRegistry.sol";
import "./ChapterNFT.sol";
import "./VotingManager.sol";
import "./RevenueDistributor.sol";
import "../governance/ProposalManager.sol";
import "../governance/StoryGovernance.sol";
import "../tokens/StoryToken.sol";
import "../tokens/ReaderRewards.sol";
import "../utils/AccessManager.sol";
import "../utils/EmergencyPause.sol";
import "../integration/StoryPlatformRouter.sol";

/**
 * @title Story Platform Factory
 * @dev Factory for atomic deployment of entire story platform
 * @notice Benefits:
 * - Atomic deployment ensures system integrity
 * - All contracts guaranteed compatible (same codebase)
 * - Automatic role setup in same transaction
 * - CREATE2 support for deterministic addresses
 * - Perfect for L2s with higher gas limits
 * - Cross-chain deployment consistency
 * - Immutable deployment record
 */
contract StoryPlatformFactory {
    struct PlatformContracts {
        address storyRegistry;
        address chapterNFT;
        address votingManager;
        address revenueDistributor;
        address proposalManager;
        address storyGovernance;
        address storyToken;
        address readerRewards;
        address accessManager;
        address emergencyPause;
        address platformRouter;
    }

    struct DeploymentConfig {
        string tokenName;
        string tokenSymbol;
        string nftName;
        string nftSymbol;
        uint256 votingDuration;
        uint256 proposalFee;
        bool useCreate2;
        bytes32 salt;
    }

    // Track all deployments across chains
    mapping(uint256 => PlatformContracts) public deployments;
    mapping(bytes32 => bool) public usedSalts;
    
    uint256 public deploymentCount;
    
    event PlatformDeployed(
        address indexed deployer,
        uint256 indexed chainId,
        uint256 indexed deploymentId,
        PlatformContracts contracts,
        bytes32 salt
    );

    /**
     * @dev Deploy complete platform with default config
     */
    function deployPlatform() external returns (PlatformContracts memory) {
        return deployPlatformWithConfig(DeploymentConfig({
            tokenName: "Story Token",
            tokenSymbol: "STORY",
            nftName: "Story Chapter",
            nftSymbol: "SCHP",
            votingDuration: 3 days,
            proposalFee: 0.01 ether,
            useCreate2: false,
            salt: bytes32(0)
        }));
    }

    /**
     * @dev Deploy platform with custom configuration
     * @param config Deployment configuration parameters
     */
    function deployPlatformWithConfig(DeploymentConfig memory config) 
        public 
        returns (PlatformContracts memory) 
    {
        if (config.useCreate2) {
            require(!usedSalts[config.salt], "Salt already used");
            usedSalts[config.salt] = true;
        }

        PlatformContracts memory contracts;
        
        // Deploy governance layer first
        contracts.storyGovernance = _deployGovernance(config);
        contracts.accessManager = _deployAccessManager(config);
        contracts.emergencyPause = _deployEmergencyPause(config);

        // Deploy token layer
        contracts.storyToken = _deployStoryToken(config);
        contracts.readerRewards = _deployReaderRewards(config);

        // Deploy core contracts with dependencies
        contracts.storyRegistry = _deployStoryRegistry(config);
        contracts.chapterNFT = _deployChapterNFT(config);
        contracts.votingManager = _deployVotingManager(contracts.storyToken, config);
        contracts.revenueDistributor = _deployRevenueDistributor(config);
        contracts.proposalManager = _deployProposalManager(config);

        // Deploy integration layer
        contracts.platformRouter = _deployPlatformRouter(contracts, config);

        // Critical: Setup all roles and permissions atomically
        _setupSystemRoles(contracts);
        
        // Configure initial parameters
        _configureSystem(contracts, config);

        // Record deployment
        uint256 deploymentId = ++deploymentCount;
        deployments[block.chainid] = contracts;

        emit PlatformDeployed(
            msg.sender, 
            block.chainid, 
            deploymentId, 
            contracts, 
            config.salt
        );

        return contracts;
    }

    /**
     * @dev Deploy platform with CREATE2 for deterministic addresses
     * @param salt Unique salt for CREATE2 deployment
     */
    function deployPlatformDeterministic(bytes32 salt) 
        external 
        returns (PlatformContracts memory) 
    {
        return deployPlatformWithConfig(DeploymentConfig({
            tokenName: "Story Token",
            tokenSymbol: "STORY",
            nftName: "Story Chapter", 
            nftSymbol: "SCHP",
            votingDuration: 3 days,
            proposalFee: 0.01 ether,
            useCreate2: true,
            salt: salt
        }));
    }

    // =============================================================================
    // INTERNAL DEPLOYMENT FUNCTIONS
    // =============================================================================

    function _deployGovernance(DeploymentConfig memory config) 
        internal 
        returns (address) 
    {
        if (config.useCreate2) {
            bytes memory bytecode = type(StoryGovernance).creationCode;
            bytes32 salt = keccak256(abi.encodePacked(config.salt, "governance"));
            return _deploy2(bytecode, salt);
        }
        return address(new StoryGovernance());
    }

    function _deployAccessManager(DeploymentConfig memory config) 
        internal 
        returns (address) 
    {
        if (config.useCreate2) {
            bytes memory bytecode = type(AccessManager).creationCode;
            bytes32 salt = keccak256(abi.encodePacked(config.salt, "access"));
            return _deploy2(bytecode, salt);
        }
        return address(new AccessManager());
    }

    function _deployEmergencyPause(DeploymentConfig memory config) 
        internal 
        returns (address) 
    {
        if (config.useCreate2) {
            bytes memory bytecode = type(EmergencyPause).creationCode;
            bytes32 salt = keccak256(abi.encodePacked(config.salt, "pause"));
            return _deploy2(bytecode, salt);
        }
        return address(new EmergencyPause());
    }

    function _deployStoryToken(DeploymentConfig memory config) 
        internal 
        returns (address) 
    {
        if (config.useCreate2) {
            bytes memory bytecode = type(StoryToken).creationCode;
            bytes32 salt = keccak256(abi.encodePacked(config.salt, "token"));
            return _deploy2(bytecode, salt);
        }
        return address(new StoryToken());
    }

    function _deployReaderRewards(DeploymentConfig memory config) 
        internal 
        returns (address) 
    {
        if (config.useCreate2) {
            bytes memory bytecode = type(ReaderRewards).creationCode;
            bytes32 salt = keccak256(abi.encodePacked(config.salt, "rewards"));
            return _deploy2(bytecode, salt);
        }
        return address(new ReaderRewards());
    }

    function _deployStoryRegistry(DeploymentConfig memory config) 
        internal 
        returns (address) 
    {
        if (config.useCreate2) {
            bytes memory bytecode = type(StoryRegistry).creationCode;
            bytes32 salt = keccak256(abi.encodePacked(config.salt, "registry"));
            return _deploy2(bytecode, salt);
        }
        return address(new StoryRegistry());
    }

    function _deployChapterNFT(DeploymentConfig memory config) 
        internal 
        returns (address) 
    {
        if (config.useCreate2) {
            bytes memory bytecode = type(ChapterNFT).creationCode;
            bytes32 salt = keccak256(abi.encodePacked(config.salt, "nft"));
            return _deploy2(bytecode, salt);
        }
        return address(new ChapterNFT());
    }

    function _deployVotingManager(address storyToken, DeploymentConfig memory config) 
        internal 
        returns (address) 
    {
        if (config.useCreate2) {
            bytes memory bytecode = abi.encodePacked(
                type(VotingManager).creationCode,
                abi.encode(storyToken)
            );
            bytes32 salt = keccak256(abi.encodePacked(config.salt, "voting"));
            return _deploy2(bytecode, salt);
        }
        return address(new VotingManager(storyToken));
    }

    function _deployRevenueDistributor(DeploymentConfig memory config) 
        internal 
        returns (address) 
    {
        if (config.useCreate2) {
            bytes memory bytecode = type(RevenueDistributor).creationCode;
            bytes32 salt = keccak256(abi.encodePacked(config.salt, "revenue"));
            return _deploy2(bytecode, salt);
        }
        return address(new RevenueDistributor());
    }

    function _deployProposalManager(DeploymentConfig memory config) 
        internal 
        returns (address) 
    {
        if (config.useCreate2) {
            bytes memory bytecode = type(ProposalManager).creationCode;
            bytes32 salt = keccak256(abi.encodePacked(config.salt, "proposals"));
            return _deploy2(bytecode, salt);
        }
        return address(new ProposalManager());
    }

    function _deployPlatformRouter(
        PlatformContracts memory contracts, 
        DeploymentConfig memory config
    ) internal returns (address) {
        if (config.useCreate2) {
            bytes memory bytecode = abi.encodePacked(
                type(StoryPlatformRouter).creationCode,
                abi.encode(
                    contracts.storyRegistry,
                    contracts.chapterNFT,
                    contracts.votingManager,
                    contracts.proposalManager
                )
            );
            bytes32 salt = keccak256(abi.encodePacked(config.salt, "router"));
            return _deploy2(bytecode, salt);
        }
        return address(new StoryPlatformRouter(
            contracts.storyRegistry,
            contracts.chapterNFT,
            contracts.votingManager,
            contracts.proposalManager
        ));
    }

    function _deploy2(bytes memory bytecode, bytes32 salt) internal returns (address) {
        address addr;
        assembly {
            addr := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }
        return addr;
    }

    // =============================================================================
    // SYSTEM CONFIGURATION
    // =============================================================================

    /**
     * @dev Setup all inter-contract roles and permissions atomically
     * @param contracts All deployed contract addresses
     */
    function _setupSystemRoles(PlatformContracts memory contracts) internal {
        // Cast to actual contracts for role setup
        StoryRegistry storyRegistry = StoryRegistry(contracts.storyRegistry);
        ChapterNFT chapterNFT = ChapterNFT(contracts.chapterNFT);
        VotingManager votingManager = VotingManager(contracts.votingManager);
        RevenueDistributor revenueDistributor = RevenueDistributor(contracts.revenueDistributor);
        ProposalManager proposalManager = ProposalManager(contracts.proposalManager);
        StoryGovernance governance = StoryGovernance(contracts.storyGovernance);
        ReaderRewards readerRewards = ReaderRewards(contracts.readerRewards);
        AccessManager accessManager = AccessManager(contracts.accessManager);

        // Core system roles - VotingManager orchestrates everything
        storyRegistry.grantRole(storyRegistry.STORY_MANAGER_ROLE(), contracts.votingManager);
        chapterNFT.grantRole(chapterNFT.MINTER_ROLE(), contracts.votingManager);
        chapterNFT.grantRole(chapterNFT.UPDATER_ROLE(), contracts.votingManager);
        proposalManager.grantRole(proposalManager.PROPOSAL_ADMIN_ROLE(), contracts.votingManager);
        revenueDistributor.grantRole(revenueDistributor.REVENUE_ADMIN_ROLE(), contracts.votingManager);
        
        // Reader rewards managed by ChapterNFT
        readerRewards.grantRole(readerRewards.REWARDS_ADMIN_ROLE(), contracts.chapterNFT);
        
        // Platform admin roles
        governance.grantRole(governance.GOVERNANCE_ADMIN_ROLE(), msg.sender);
        accessManager.grantRole(accessManager.PLATFORM_ADMIN_ROLE(), msg.sender);
        
        // Grant deployer admin access to all contracts
        storyRegistry.grantRole(storyRegistry.DEFAULT_ADMIN_ROLE(), msg.sender);
        chapterNFT.grantRole(chapterNFT.DEFAULT_ADMIN_ROLE(), msg.sender);
        votingManager.grantRole(votingManager.DEFAULT_ADMIN_ROLE(), msg.sender);
        revenueDistributor.grantRole(revenueDistributor.DEFAULT_ADMIN_ROLE(), msg.sender);
        proposalManager.grantRole(proposalManager.DEFAULT_ADMIN_ROLE(), msg.sender);
        readerRewards.grantRole(readerRewards.DEFAULT_ADMIN_ROLE(), msg.sender);
    }

    /**
     * @dev Configure initial system parameters
     */
    function _configureSystem(
        PlatformContracts memory contracts, 
        DeploymentConfig memory config
    ) internal {
        // Set voting duration
        VotingManager(contracts.votingManager).setVotingDuration(config.votingDuration);
        
        // Set proposal fee
        ProposalManager(contracts.proposalManager).setSubmissionFee(config.proposalFee);
        
        // Set initial revenue split (50% author, 30% voters, 20% platform)
        RevenueDistributor(contracts.revenueDistributor).setRevenuePercentages(5000, 3000, 2000);
    }

    // =============================================================================
    // UTILITY FUNCTIONS
    // =============================================================================

    /**
     * @dev Predict addresses for CREATE2 deployment
     */
    function predictAddresses(bytes32 salt) 
        external 
        view 
        returns (PlatformContracts memory predicted) 
    {
        predicted.storyGovernance = _predictAddress(
            type(StoryGovernance).creationCode,
            keccak256(abi.encodePacked(salt, "governance"))
        );
        predicted.storyToken = _predictAddress(
            type(StoryToken).creationCode,
            keccak256(abi.encodePacked(salt, "token"))
        );
        // ... predict other addresses
    }

    function _predictAddress(bytes memory bytecode, bytes32 salt) 
        internal 
        view 
        returns (address) 
    {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(bytecode)
            )
        );
        return address(uint160(uint256(hash)));
    }

    /**
     * @dev Get deployment for specific chain
     */
    function getDeployment(uint256 chainId) 
        external 
        view 
        returns (PlatformContracts memory) 
    {
        return deployments[chainId];
    }

    /**
     * @dev Check if platform is deployed on chain
     */
    function isDeployedOnChain(uint256 chainId) external view returns (bool) {
        return deployments[chainId].storyRegistry != address(0);
    }
}