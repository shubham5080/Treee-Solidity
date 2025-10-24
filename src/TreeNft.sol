// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC721} from "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {Base64} from "../lib/openzeppelin-contracts/contracts/utils/Base64.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Strings} from "../lib/openzeppelin-contracts/contracts/utils/Strings.sol";

import "./utils/structs.sol";
import "./utils/errors.sol";

import "./Organisation.sol";
import "./OrganisationFactory.sol";

import "./token-contracts/CareToken.sol";
import "./token-contracts/LegacyToken.sol";
import "./token-contracts/PlanterToken.sol";

contract TreeNft is ERC721, Ownable {
    uint256 private s_treeTokenCounter;
    uint256 private s_organisationCounter;
    uint256 private s_deathCounter;
    uint256 private s_treeNftVerificationCounter;
    uint256 private s_userCounter;
    uint256 public constant maxLimitForPagination = 50;

    uint256 public minimumTimeToMarkTreeDead = 365 days;
    CareToken public careTokenContract;
    LegacyToken public legacyToken;

    mapping(uint256 => Tree) private s_tokenIDtoTree;
    mapping(uint256 => address) private s_tokenIDtoVerificationContracts;
    mapping(uint256 => address[]) private s_tokenIDtoVerifiers;
    mapping(address => uint256[]) private s_userToNFTs;
    mapping(address => address) public s_userToPlanterTokenAddress;
    mapping(address => address[]) public s_userToVerifierTokenAddresses;

    mapping(uint256 => mapping(address => bool)) private s_tokenIDtoUserVerification;
    mapping(address => uint256[]) private s_verifierToTreeTokenIDs;
    mapping(uint256 => TreeNftVerification) private s_tokenIDtoTreeNftVerfication;
    mapping(uint256 => uint256[]) private s_treeTokenIdToVerifications;
    mapping(address => TreeNftVerification[]) private s_userToVerifications;

    mapping(address => User) s_addressToUser;

    constructor(address _careTokenContract, address _legacyTokenContract)
        Ownable(msg.sender)
        ERC721("TreeNFT", "TREE")
    {
        s_treeTokenCounter = 0;
        s_organisationCounter = 0;
        s_deathCounter = 0;
        s_treeNftVerificationCounter = 0;
        s_userCounter = 0;

        careTokenContract = CareToken(_careTokenContract);
        legacyToken = LegacyToken(_legacyTokenContract);
    }

    event VerificationRemoved(uint256 indexed verificationId, uint256 indexed treeNftId, address indexed verifier);

    function mintNft(
        uint256 latitude,
        uint256 longitude,
        string memory species,
        string memory imageUri,
        string memory qrPhoto,
        string memory metadata,
        string memory geoHash,
        string[] memory initialPhotos,
        uint256 numberOfTrees
    ) public {
        if (latitude > 180 * 1e6) revert InvalidCoordinates();
        if (longitude > 360 * 1e6) revert InvalidCoordinates();

        uint256 tokenId = s_treeTokenCounter;
        s_treeTokenCounter++;

        _mint(msg.sender, tokenId);
        address[] memory ancestors = new address[](1);
        ancestors[0] = msg.sender;

        s_tokenIDtoTree[tokenId] = Tree(
            tokenId,
            latitude,
            longitude,
            block.timestamp,
            type(uint256).max,
            species,
            imageUri,
            qrPhoto,
            metadata,
            initialPhotos,
            geoHash,
            ancestors,
            block.timestamp,
            0,
            numberOfTrees
        );

        s_userToNFTs[msg.sender].push(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (!_exists(tokenId)) revert InvalidTreeID();
        Tree memory tree = s_tokenIDtoTree[tokenId];

        string memory json = string(
            abi.encodePacked(
                '{"name":"TreeNFT #',
                Strings.toString(tokenId),
                '","description":"Tree planted at coordinates ',
                Strings.toString(tree.latitude),
                ",",
                Strings.toString(tree.longitude),
                '","image":"',
                tree.imageUri,
                '","attributes":[{"trait_type":"Latitude","value":',
                Strings.toString(tree.latitude),
                '},{"trait_type":"Longitude","value":',
                Strings.toString(tree.longitude),
                '},{"trait_type":"Planting Date","value":',
                Strings.toString(tree.planting),
                "}]}"
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    function getAllNFTs(uint256 offset, uint256 limit) public view returns (Tree[] memory trees, uint256 totalCount) {
        totalCount = s_treeTokenCounter;
        if (limit > maxLimitForPagination) revert MaximumLimitRequestExceeded();

        if (offset >= totalCount) {
            return (new Tree[](0), totalCount);
        }
        uint256 end = offset + limit;
        if (end > totalCount) {
            end = totalCount;
        }
        uint256 resultLength = end - offset;
        trees = new Tree[](resultLength);
        for (uint256 i = 0; i < resultLength; i++) {
            trees[i] = s_tokenIDtoTree[offset + i];
        }
        return (trees, totalCount);
    }

    function getRecentTreesPaginated(uint256 offset, uint256 limit)
        external
        view
        returns (Tree[] memory paginatedTrees, uint256 totalCount, bool hasMore)
    {
        // This function retrieves recent trees with pagination

        if (limit > 50) revert PaginationLimitExceeded();
        uint256 totalTrees = s_treeTokenCounter;
        if (offset >= totalTrees) return (new Tree[](0), totalTrees, false);
        uint256 available = totalTrees - offset;
        uint256 toReturn = available < limit ? available : limit;
        Tree[] memory result = new Tree[](toReturn);
        for (uint256 i = 0; i < toReturn; i++) {
            uint256 treeIndex = totalTrees - 1 - offset - i;
            result[i] = s_tokenIDtoTree[treeIndex];
        }
        bool hasMoreTrees = offset + toReturn < totalTrees;
        return (result, totalTrees, hasMoreTrees);
    }

    function getNFTsByUserPaginated(address user, uint256 offset, uint256 limit)
        public
        view
        returns (Tree[] memory trees, uint256 totalCount)
    {
        // Get the total number of NFTs for this user

        uint256[] memory userNFTs = s_userToNFTs[user];
        totalCount = userNFTs.length;

        if (offset >= totalCount) {
            return (new Tree[](0), totalCount);
        }
        uint256 end = offset + limit;
        if (end > totalCount) {
            end = totalCount;
        }
        uint256 resultLength = end - offset;
        trees = new Tree[](resultLength);
        for (uint256 i = 0; i < resultLength; i++) {
            uint256 tokenId = userNFTs[offset + i];
            trees[i] = s_tokenIDtoTree[tokenId];
        }

        return (trees, totalCount);
    }

    function getTreeDetailsbyID(uint256 tokenId) public view returns (Tree memory) {
        // This function retrieves details of a specific tree NFT by its ID

        if (!_exists(tokenId)) revert InvalidTreeID();
        return s_tokenIDtoTree[tokenId];
    }

    function verify(uint256 _tokenId, string[] memory _proofHashes, string memory _description) public {
        // This function allows a verifier to verify a tree

        if (!_exists(_tokenId)) revert InvalidTreeID();
        address treeOwner = ownerOf(_tokenId);
        Tree memory tree = s_tokenIDtoTree[_tokenId];
        if (msg.sender == treeOwner) revert CannotVerifyOwnTree();

        if (s_tokenIDtoUserVerification[_tokenId][msg.sender]) {
            revert AlreadyVerified();
        }
        if (s_userToPlanterTokenAddress[msg.sender] == address(0)) {
            PlanterToken newPlanterToken = new PlanterToken(msg.sender);
            s_userToPlanterTokenAddress[msg.sender] = address(newPlanterToken);
        }
        address planterTokenContract = s_userToPlanterTokenAddress[msg.sender];
        PlanterToken planterToken = PlanterToken(planterTokenContract);

        if (!isVerified(_tokenId, msg.sender)) {
            TreeNftVerification memory treeVerification = TreeNftVerification(
                msg.sender, block.timestamp, _proofHashes, _description, false, _tokenId, planterTokenContract
            );
            s_tokenIDtoUserVerification[_tokenId][msg.sender] = true; // mark as verified by the verifier for the tree
            s_tokenIDtoVerifiers[_tokenId].push(msg.sender); // tree to verifiers
            s_verifierToTreeTokenIDs[msg.sender].push(_tokenId); // verifier to verified trees

            s_tokenIDtoTreeNftVerfication[s_treeNftVerificationCounter] = treeVerification; // store the verification
            s_treeTokenIdToVerifications[_tokenId].push(s_treeNftVerificationCounter);
            s_treeNftVerificationCounter++;

            planterToken.mint(ownerOf(_tokenId), tree.numberOfTrees * 1e18);
            s_userToVerifierTokenAddresses[ownerOf(_tokenId)].push(planterTokenContract);

            s_userToVerifications[ownerOf(_tokenId)].push(treeVerification);
        }
    }

    function removeVerification(uint256 _tokenId, address verifier) public {
        // This function facilitates the owner of the tree nft to remove fraudulent verifiers

        if (msg.sender != ownerOf(_tokenId)) revert NotTreeOwner();
        if (!s_tokenIDtoUserVerification[_tokenId][verifier]) {
            revert VerificationNotFound();
        }

        // Check if verification exists and is not already hidden
        bool verificationFound = false;
        uint256[] storage verificationIds = s_treeTokenIdToVerifications[_tokenId];
        for (uint256 i = 0; i < verificationIds.length; i++) {
            TreeNftVerification storage treeNftVerification = s_tokenIDtoTreeNftVerfication[verificationIds[i]];
            if (treeNftVerification.verifier == verifier && !treeNftVerification.isHidden) {
                verificationFound = true;
                break;
            }
        }
        if (!verificationFound) {
            revert VerificationNotFound();
        }

        Tree memory tree = s_tokenIDtoTree[_tokenId];
        address treeOwner = ownerOf(_tokenId);

        address[] storage verifiers = s_tokenIDtoVerifiers[_tokenId];
        for (uint256 i = 0; i < verifiers.length; i++) {
            if (verifiers[i] == verifier) {
                verifiers[i] = verifiers[verifiers.length - 1];
                verifiers.pop();
                break;
            }
        }
        uint256[] storage verifiedTrees = s_verifierToTreeTokenIDs[verifier];
        for (uint256 i = 0; i < verifiedTrees.length; i++) {
            if (verifiedTrees[i] == _tokenId) {
                verifiedTrees[i] = verifiedTrees[verifiedTrees.length - 1];
                verifiedTrees.pop();
                break;
            }
        }

        for (uint256 i = 0; i < verificationIds.length; i++) {
            TreeNftVerification storage treeNftVerification = s_tokenIDtoTreeNftVerfication[verificationIds[i]];
            if (treeNftVerification.verifier == verifier && !treeNftVerification.isHidden) {
                treeNftVerification.isHidden = true;

                // Also update the verification in the user's array
                TreeNftVerification[] storage userVerifications = s_userToVerifications[treeOwner];
                for (uint256 j = 0; j < userVerifications.length; j++) {
                    if (
                        userVerifications[j].treeNftId == _tokenId && userVerifications[j].verifier == verifier
                            && !userVerifications[j].isHidden
                    ) {
                        userVerifications[j].isHidden = true;
                        break;
                    }
                }

                User storage user = s_addressToUser[verifier];
                user.verificationsRevoked++;
                address planterTokenAddr = s_userToPlanterTokenAddress[verifier];
                if (planterTokenAddr != address(0)) {
                    PlanterToken planterToken = PlanterToken(planterTokenAddr);
                    uint256 tokensToReturn = tree.numberOfTrees * 1e18;
                    if (planterToken.balanceOf(treeOwner) >= tokensToReturn) {
                        planterToken.burnFrom(treeOwner, tokensToReturn);
                        address[] storage verifierTokenAddrs = s_userToVerifierTokenAddresses[treeOwner];
                        for (uint256 j = 0; j < verifierTokenAddrs.length; j++) {
                            if (verifierTokenAddrs[j] == planterTokenAddr) {
                                verifierTokenAddrs[j] = verifierTokenAddrs[verifierTokenAddrs.length - 1];
                                verifierTokenAddrs.pop();
                                break;
                            }
                        }
                    }
                }

                emit VerificationRemoved(verificationIds[i], _tokenId, verifier);
                break;
            }
        }
    }

    function removeVerificationOptimized(
        uint256 _verificationId,
        uint256 _verifierArrayIndex,
        uint256 _verifiedTreesArrayIndex,
        uint256 _userVerificationIndex,
        uint256 _verifierTokenAddrIndex
    ) public {
        TreeNftVerification storage verification = s_tokenIDtoTreeNftVerfication[_verificationId];

        if (verification.verifier == address(0)) revert VerificationNotFound();
        if (verification.isHidden) revert VerificationNotFound();

        uint256 tokenId = verification.treeNftId;
        address verifier = verification.verifier;
        address treeOwner = ownerOf(tokenId);

        if (msg.sender != treeOwner) revert NotTreeOwner();

        address[] storage verifiers = s_tokenIDtoVerifiers[tokenId];
        if (_verifierArrayIndex >= verifiers.length || verifiers[_verifierArrayIndex] != verifier) {
            revert VerificationNotFound();
        }

        uint256[] storage verifiedTrees = s_verifierToTreeTokenIDs[verifier];
        if (_verifiedTreesArrayIndex >= verifiedTrees.length || verifiedTrees[_verifiedTreesArrayIndex] != tokenId) {
            revert VerificationNotFound();
        }

        TreeNftVerification[] storage userVerifications = s_userToVerifications[treeOwner];
        if (
            _userVerificationIndex >= userVerifications.length
                || userVerifications[_userVerificationIndex].treeNftId != tokenId
                || userVerifications[_userVerificationIndex].verifier != verifier
                || userVerifications[_userVerificationIndex].isHidden
        ) {
            revert VerificationNotFound();
        }

        verifiers[_verifierArrayIndex] = verifiers[verifiers.length - 1];
        verifiers.pop();

        verifiedTrees[_verifiedTreesArrayIndex] = verifiedTrees[verifiedTrees.length - 1];
        verifiedTrees.pop();

        verification.isHidden = true;
        userVerifications[_userVerificationIndex].isHidden = true;

        User storage user = s_addressToUser[verifier];
        user.verificationsRevoked++;

        address planterTokenAddr = verification.verifierPlanterTokenAddress;
        if (planterTokenAddr != address(0)) {
            PlanterToken planterToken = PlanterToken(planterTokenAddr);
            Tree memory tree = s_tokenIDtoTree[tokenId];
            uint256 tokensToReturn = tree.numberOfTrees * 1e18;

            if (planterToken.balanceOf(treeOwner) >= tokensToReturn) {
                planterToken.burnFrom(treeOwner, tokensToReturn);

                address[] storage verifierTokenAddrs = s_userToVerifierTokenAddresses[treeOwner];
                if (
                    _verifierTokenAddrIndex >= verifierTokenAddrs.length
                        || verifierTokenAddrs[_verifierTokenAddrIndex] != planterTokenAddr
                ) {
                    revert VerificationNotFound();
                }
                verifierTokenAddrs[_verifierTokenAddrIndex] = verifierTokenAddrs[verifierTokenAddrs.length - 1];
                verifierTokenAddrs.pop();
            }
        }

        emit VerificationRemoved(_verificationId, tokenId, verifier);
    }

    function getVerifiedTreesByUserPaginated(address verifier, uint256 offset, uint256 limit)
        public
        view
        returns (Tree[] memory trees, uint256 totalCount)
    {
        // Get the total number of trees verified by this verifier

        if (limit > maxLimitForPagination) revert MaximumLimitRequestExceeded();
        uint256[] memory verifiedTokens = s_verifierToTreeTokenIDs[verifier];
        totalCount = verifiedTokens.length;
        if (offset >= totalCount) {
            return (new Tree[](0), totalCount);
        }
        uint256 end = offset + limit;
        if (end > totalCount) {
            end = totalCount;
        }
        uint256 resultLength = end - offset;
        trees = new Tree[](resultLength);
        for (uint256 i = 0; i < resultLength; i++) {
            uint256 tokenId = verifiedTokens[offset + i];
            trees[i] = s_tokenIDtoTree[tokenId];
        }

        return (trees, totalCount);
    }

    function getTreeNftVerifiersPaginated(uint256 _tokenId, uint256 offset, uint256 limit)
        public
        view
        returns (TreeNftVerification[] memory verifications, uint256 totalCount, uint256 visiblecount)
    {
        // This function retrieves all verifiers for a specific tree with pagination

        uint256[] storage verificationIds = s_treeTokenIdToVerifications[_tokenId];
        totalCount = verificationIds.length;
        uint256 visibleCount = 0;
        for (uint256 i = 0; i < totalCount; i++) {
            if (!s_tokenIDtoTreeNftVerfication[verificationIds[i]].isHidden) {
                visibleCount++;
            }
        }
        if (offset >= visibleCount) {
            return (new TreeNftVerification[](0), totalCount, visibleCount);
        }
        uint256 end = offset + limit;
        if (end > visibleCount) {
            end = visibleCount;
        }
        uint256 resultLength = end - offset;
        verifications = new TreeNftVerification[](resultLength);
        uint256 visibleIndex;
        uint256 resultIndex;
        for (uint256 i = 0; i < totalCount && resultIndex < resultLength; i++) {
            TreeNftVerification memory verification = s_tokenIDtoTreeNftVerfication[verificationIds[i]];
            if (!verification.isHidden) {
                if (visibleIndex >= offset && visibleIndex < end) {
                    verifications[resultIndex] = verification;
                    resultIndex++;
                }
                visibleIndex++;
            }
        }
        return (verifications, totalCount, visibleCount);
    }

    function markDead(uint256 tokenId) public {
        // This function marks a tree as dead

        if (!_exists(tokenId)) revert InvalidTreeID();
        if (s_tokenIDtoTree[tokenId].death != type(uint256).max) {
            revert TreeAlreadyDead();
        }
        if (ownerOf(tokenId) != msg.sender) revert NotTreeOwner();
        if (s_tokenIDtoTree[tokenId].planting + minimumTimeToMarkTreeDead >= block.timestamp) {
            revert MinimumMarkDeadTimeNotReached();
        }

        legacyToken.mint(msg.sender, 1 * 1e18);

        s_tokenIDtoTree[tokenId].death = block.timestamp;
        s_deathCounter++;
    }

    function registerUserProfile(string memory _name, string memory _profilePhoto) public {
        // This function registers a user

        if (s_addressToUser[msg.sender].userAddress != address(0)) {
            revert UserAlreadyRegistered();
        }
        User memory user = User(msg.sender, _profilePhoto, _name, block.timestamp, 0, 0);
        s_addressToUser[msg.sender] = user;
        s_userCounter++;
    }

    function getUserProfile(address userAddress) public view returns (UserDetails memory userDetails) {
        // This function returns the details of the user

        if (s_addressToUser[userAddress].userAddress == address(0)) {
            revert UserNotRegistered();
        }
        User memory storedUserDetails = s_addressToUser[userAddress];
        userDetails.name = storedUserDetails.name;
        userDetails.dateJoined = storedUserDetails.dateJoined;
        userDetails.profilePhoto = storedUserDetails.profilePhoto;
        userDetails.userAddress = storedUserDetails.userAddress;
        userDetails.reportedSpam = storedUserDetails.reportedSpam;
        userDetails.verificationsRevoked = storedUserDetails.verificationsRevoked;
        userDetails.careTokens = careTokenContract.balanceOf(userAddress);
        userDetails.legacyTokens = legacyToken.balanceOf(userAddress);
        return userDetails;
    }

    function getUserVerifierTokenDetails(address userAddress, uint256 offset, uint256 limit)
        public
        view
        returns (VerificationDetails[] memory verifierTokenDetails, uint256 totalCount)
    {
        // This function returns the verifier token details of the user with pagination

        TreeNftVerification[] memory userVerifications = s_userToVerifications[userAddress];
        totalCount = userVerifications.length;
        if (offset >= totalCount) {
            return (new VerificationDetails[](0), totalCount);
        }
        uint256 end = offset + limit;
        if (end > totalCount) {
            end = totalCount;
        }
        uint256 resultLength = end - offset;
        verifierTokenDetails = new VerificationDetails[](resultLength);
        for (uint256 i = 0; i < resultLength; i++) {
            uint256 verificationIndex = offset + i;
            PlanterToken planterToken = PlanterToken(userVerifications[verificationIndex].verifierPlanterTokenAddress);
            verifierTokenDetails[i] = VerificationDetails({
                verifier: userVerifications[verificationIndex].verifier,
                timestamp: userVerifications[verificationIndex].timestamp,
                proofHashes: userVerifications[verificationIndex].proofHashes,
                description: userVerifications[verificationIndex].description,
                isHidden: userVerifications[verificationIndex].isHidden,
                numberOfTrees: planterToken.balanceOf(userAddress),
                verifierPlanterTokenAddress: userVerifications[verificationIndex].verifierPlanterTokenAddress
            });
        }
        return (verifierTokenDetails, totalCount);
    }

    function updateUserDetails(string memory _name, string memory _profilePhoto) public {
        // This function enables a user to change his user details

        if (s_addressToUser[msg.sender].userAddress == address(0)) {
            revert UserNotRegistered();
        }
        s_addressToUser[msg.sender].name = _name;
        s_addressToUser[msg.sender].profilePhoto = _profilePhoto;
    }

    function isVerified(uint256 tokenId, address verifier) public view returns (bool) {
        // This function checks if a verifier has verified a tree

        return s_tokenIDtoUserVerification[tokenId][verifier];
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return tokenId < s_treeTokenCounter && tokenId >= 0;
    }
}
