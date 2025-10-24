// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../lib/forge-std/src/Test.sol";
import "../src/TreeNft.sol";
import "../src/token-contracts/CareToken.sol";
import "../src/token-contracts/LegacyToken.sol";
import "../src/token-contracts/PlanterToken.sol";
import "../src/utils/structs.sol";
import "../src/utils/errors.sol";

contract TreeNftVerificationTest is Test {
    TreeNft public treeNft;
    CareToken public careToken;
    LegacyToken public legacyToken;

    address public owner = address(0x1);
    address public planter = address(0x2);
    address public verifier1 = address(0x3);
    address public verifier2 = address(0x4);

    // Events for testing
    event VerificationRemoved(uint256 indexed verificationId, uint256 indexed treeNftId, address indexed verifier);

    uint256 public constant LATITUDE = 45 * 1e6;
    uint256 public constant LONGITUDE = 90 * 1e6;
    string public constant SPECIES = "Oak";
    string public constant IMAGE_URI = "ipfs://image";
    string public constant QR_HASH = "ipfs://qr";
    string public constant METADATA = "metadata";
    string public constant GEOHASH = "geohash";
    uint256 public constant NUM_TREES = 10;

    function setUp() public {
        vm.startPrank(owner);
        careToken = new CareToken(owner);
        legacyToken = new LegacyToken(owner);
        treeNft = new TreeNft(address(careToken), address(legacyToken));
        careToken.transferOwnership(address(treeNft));
        legacyToken.transferOwnership(address(treeNft));
        vm.stopPrank();
    }

    function test_verifyTree() public {
        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(verifier1);
        string[] memory proofs = new string[](1);
        proofs[0] = "proof1";
        treeNft.verify(0, proofs, "verified");

        assertTrue(treeNft.isVerified(0, verifier1));

        address planterTokenAddr = treeNft.s_userToPlanterTokenAddress(verifier1);
        PlanterToken planterToken = PlanterToken(planterTokenAddr);
        assertEq(planterToken.balanceOf(planter), NUM_TREES * 1e18);
    }

    function test_cannotVerifyOwnTree() public {
        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(planter);
        string[] memory proofs = new string[](1);
        proofs[0] = "proof1";
        vm.expectRevert(CannotVerifyOwnTree.selector);
        treeNft.verify(0, proofs, "verified");
    }

    function test_cannotVerifyTwice() public {
        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(verifier1);
        string[] memory proofs = new string[](1);
        proofs[0] = "proof1";
        treeNft.verify(0, proofs, "verified");

        vm.prank(verifier1);
        vm.expectRevert(AlreadyVerified.selector);
        treeNft.verify(0, proofs, "verified again");
    }

    function test_multipleVerifiers() public {
        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(verifier1);
        string[] memory proofs1 = new string[](1);
        proofs1[0] = "proof1";
        treeNft.verify(0, proofs1, "verified by v1");

        vm.prank(verifier2);
        string[] memory proofs2 = new string[](1);
        proofs2[0] = "proof2";
        treeNft.verify(0, proofs2, "verified by v2");

        assertTrue(treeNft.isVerified(0, verifier1));
        assertTrue(treeNft.isVerified(0, verifier2));

        address planterToken1 = treeNft.s_userToPlanterTokenAddress(verifier1);
        address planterToken2 = treeNft.s_userToPlanterTokenAddress(verifier2);

        assertEq(PlanterToken(planterToken1).balanceOf(planter), NUM_TREES * 1e18);
        assertEq(PlanterToken(planterToken2).balanceOf(planter), NUM_TREES * 1e18);
    }

    function test_removeVerification() public {
        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(verifier1);
        string[] memory proofs = new string[](1);
        proofs[0] = "proof1";
        treeNft.verify(0, proofs, "verified");
        assertTrue(treeNft.isVerified(0, verifier1));
        address planterTokenAddr = treeNft.s_userToPlanterTokenAddress(verifier1);
        PlanterToken planterToken = PlanterToken(planterTokenAddr);
        assertEq(planterToken.balanceOf(planter), NUM_TREES * 1e18);

        vm.prank(planter);
        treeNft.removeVerification(0, verifier1);
        assertTrue(treeNft.isVerified(0, verifier1));
        (TreeNftVerification[] memory verifications,,) = treeNft.getTreeNftVerifiersPaginated(0, 0, 50);
        assertEq(verifications.length, 0);
        (Tree[] memory verifiedTrees,) = treeNft.getVerifiedTreesByUserPaginated(verifier1, 0, 50);
        assertEq(verifiedTrees.length, 0);
        assertEq(planterToken.balanceOf(planter), 0);
    }

    function test_removeVerificationCompleteCleanup() public {
        vm.prank(verifier1);
        treeNft.registerUserProfile("Verifier1", "ipfs://profile1");

        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(verifier1);
        string[] memory proofs1 = new string[](1);
        proofs1[0] = "proof1";
        treeNft.verify(0, proofs1, "verified by v1");

        vm.prank(verifier2);
        string[] memory proofs2 = new string[](1);
        proofs2[0] = "proof2";
        treeNft.verify(0, proofs2, "verified by v2");
        assertTrue(treeNft.isVerified(0, verifier1));
        assertTrue(treeNft.isVerified(0, verifier2));
        (TreeNftVerification[] memory verificationsBeforeRemoval,,) = treeNft.getTreeNftVerifiersPaginated(0, 0, 100);
        assertEq(verificationsBeforeRemoval.length, 2);
        vm.prank(planter);
        treeNft.removeVerification(0, verifier1);
        assertTrue(treeNft.isVerified(0, verifier1));
        assertTrue(treeNft.isVerified(0, verifier2));

        (TreeNftVerification[] memory verificationsAfterRemoval,,) = treeNft.getTreeNftVerifiersPaginated(0, 0, 100);
        assertEq(verificationsAfterRemoval.length, 1);
        assertEq(verificationsAfterRemoval[0].verifier, verifier2);
        UserDetails memory verifier1Details = treeNft.getUserProfile(verifier1);
        assertEq(verifier1Details.verificationsRevoked, 1);
    }

    function test_removeVerificationTokenBurning() public {
        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(verifier1);
        string[] memory proofs = new string[](1);
        proofs[0] = "proof1";
        treeNft.verify(0, proofs, "verified");
        address planterTokenAddr = treeNft.s_userToPlanterTokenAddress(verifier1);
        PlanterToken planterToken = PlanterToken(planterTokenAddr);
        uint256 initialBalance = planterToken.balanceOf(planter);
        assertEq(initialBalance, NUM_TREES * 1e18);
        vm.prank(planter);
        treeNft.removeVerification(0, verifier1);

        uint256 finalBalance = planterToken.balanceOf(planter);
        assertEq(finalBalance, 0);
    }

    function test_removeVerificationArrayCleanup() public {
        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, "Tree1", IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(planter);
        treeNft.mintNft(
            LATITUDE + 1000, LONGITUDE + 1000, "Tree2", IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES
        );

        vm.startPrank(verifier1);
        string[] memory proofs = new string[](1);
        proofs[0] = "proof1";
        treeNft.verify(0, proofs, "verified tree 0");
        treeNft.verify(1, proofs, "verified tree 1");
        vm.stopPrank();

        (Tree[] memory verifiedTreesBefore,) = treeNft.getVerifiedTreesByUserPaginated(verifier1, 0, 50);
        assertEq(verifiedTreesBefore.length, 2);
        vm.prank(planter);
        treeNft.removeVerification(0, verifier1);
        (Tree[] memory verifiedTreesAfter,) = treeNft.getVerifiedTreesByUserPaginated(verifier1, 0, 50);
        assertEq(verifiedTreesAfter.length, 1);
        assertEq(verifiedTreesAfter[0].id, 1);
    }

    function test_removeNonexistentVerification() public {
        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(planter);
        vm.expectRevert(VerificationNotFound.selector);
        treeNft.removeVerification(0, verifier1);
    }

    function test_removeVerificationEmitsEvent() public {
        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(verifier1);
        string[] memory proofs = new string[](1);
        proofs[0] = "proof1";
        treeNft.verify(0, proofs, "verified");
        vm.prank(planter);
        vm.expectEmit(true, true, true, false);
        emit VerificationRemoved(0, 0, verifier1);
        treeNft.removeVerification(0, verifier1);
    }

    function test_removeVerificationWithInsufficientTokens() public {
        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(verifier1);
        string[] memory proofs = new string[](1);
        proofs[0] = "proof1";
        treeNft.verify(0, proofs, "verified");

        address planterTokenAddr = treeNft.s_userToPlanterTokenAddress(verifier1);
        PlanterToken planterToken = PlanterToken(planterTokenAddr);
        vm.prank(planter);
        planterToken.transfer(address(0x999), (NUM_TREES * 1e18) / 2);

        uint256 balanceBeforeRemoval = planterToken.balanceOf(planter);
        assertLt(balanceBeforeRemoval, NUM_TREES * 1e18);
        vm.prank(planter);
        treeNft.removeVerification(0, verifier1);
        assertTrue(treeNft.isVerified(0, verifier1));
        (TreeNftVerification[] memory verifications,,) = treeNft.getTreeNftVerifiersPaginated(0, 0, 100);
        assertEq(verifications.length, 0);
    }

    function test_onlyOwnerCanRemoveVerification() public {
        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(verifier1);
        string[] memory proofs = new string[](1);
        proofs[0] = "proof1";
        treeNft.verify(0, proofs, "verified");

        vm.prank(verifier2);
        vm.expectRevert(NotTreeOwner.selector);
        treeNft.removeVerification(0, verifier1);
    }

    function test_getTreeNftVerifiers() public {
        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(verifier1);
        string[] memory proofs1 = new string[](1);
        proofs1[0] = "proof1";
        treeNft.verify(0, proofs1, "verified by v1");

        vm.prank(verifier2);
        string[] memory proofs2 = new string[](1);
        proofs2[0] = "proof2";
        treeNft.verify(0, proofs2, "verified by v2");

        (TreeNftVerification[] memory verifications,,) = treeNft.getTreeNftVerifiersPaginated(0, 0, 100);
        assertEq(verifications.length, 2);
        assertEq(verifications[0].verifier, verifier1);
        assertEq(verifications[1].verifier, verifier2);
    }

    function test_getVerifiedTreesByUser() public {
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        vm.prank(planter);
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(planter);
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        string[] memory proofs = new string[](1);
        proofs[0] = "proof1";

        vm.prank(verifier1);
        treeNft.verify(0, proofs, "verified tree 0");

        vm.prank(verifier1);
        treeNft.verify(1, proofs, "verified tree 1");

        (Tree[] memory verifiedTrees,) = treeNft.getVerifiedTreesByUserPaginated(verifier1, 0, 50);

        assertEq(verifiedTrees.length, 2);
        assertEq(verifiedTrees[0].id, 0);
        assertEq(verifiedTrees[1].id, 1);
    }

    function test_verificationIncreasesRevocationCounter() public {
        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(verifier1);
        treeNft.registerUserProfile("Verifier1", "ipfs://profile");

        vm.prank(verifier1);
        string[] memory proofs = new string[](1);
        proofs[0] = "proof1";
        treeNft.verify(0, proofs, "verified");

        vm.prank(planter);
        treeNft.removeVerification(0, verifier1);

        UserDetails memory userDetails = treeNft.getUserProfile(verifier1);
        assertEq(userDetails.verificationsRevoked, 1);
    }

    function test_cannotVerifyInvalidTree() public {
        vm.prank(verifier1);
        string[] memory proofs = new string[](1);
        proofs[0] = "proof1";
        vm.expectRevert(InvalidTreeID.selector);
        treeNft.verify(999, proofs, "verified");
    }

    function test_planterTokenCreatedOnFirstVerification() public {
        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        address planterTokenBefore = treeNft.s_userToPlanterTokenAddress(verifier1);
        assertEq(planterTokenBefore, address(0));

        vm.prank(verifier1);
        string[] memory proofs = new string[](1);
        proofs[0] = "proof1";
        treeNft.verify(0, proofs, "verified");

        address planterTokenAfter = treeNft.s_userToPlanterTokenAddress(verifier1);
        assertTrue(planterTokenAfter != address(0));
    }

    function test_removeVerificationTwiceFails() public {
        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(verifier1);
        string[] memory proofs = new string[](1);
        proofs[0] = "proof1";
        treeNft.verify(0, proofs, "verified");

        vm.prank(planter);
        treeNft.removeVerification(0, verifier1);

        vm.prank(planter);
        vm.expectRevert(VerificationNotFound.selector);
        treeNft.removeVerification(0, verifier1);
    }

    function test_removeVerificationAfterMultipleVerifications() public {
        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, "Tree1", IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(planter);
        treeNft.mintNft(
            LATITUDE + 1000, LONGITUDE + 1000, "Tree2", IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES
        );

        vm.prank(planter);
        treeNft.mintNft(
            LATITUDE + 2000, LONGITUDE + 2000, "Tree3", IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES
        );

        vm.startPrank(verifier1);
        string[] memory proofs = new string[](1);
        proofs[0] = "proof1";
        treeNft.verify(0, proofs, "verified tree 0");
        treeNft.verify(1, proofs, "verified tree 1");
        treeNft.verify(2, proofs, "verified tree 2");
        vm.stopPrank();

        (Tree[] memory verifiedTrees,) = treeNft.getVerifiedTreesByUserPaginated(verifier1, 0, 50);
        assertEq(verifiedTrees.length, 3);

        vm.prank(planter);
        treeNft.removeVerification(1, verifier1);
        (Tree[] memory remainingTrees,) = treeNft.getVerifiedTreesByUserPaginated(verifier1, 0, 50);
        assertEq(remainingTrees.length, 2);

        bool hasTree0 = false;
        bool hasTree2 = false;
        for (uint256 i = 0; i < remainingTrees.length; i++) {
            if (remainingTrees[i].id == 0) hasTree0 = true;
            if (remainingTrees[i].id == 2) hasTree2 = true;
        }
        assertTrue(hasTree0, "Tree 0 should still be verified");
        assertTrue(hasTree2, "Tree 2 should still be verified");
        assertTrue(treeNft.isVerified(1, verifier1));
    }

    function test_removeVerificationPreservesOtherVerifiers() public {
        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(verifier1);
        string[] memory proofs1 = new string[](1);
        proofs1[0] = "proof1";
        treeNft.verify(0, proofs1, "verified by v1");

        vm.prank(verifier2);
        string[] memory proofs2 = new string[](1);
        proofs2[0] = "proof2";
        treeNft.verify(0, proofs2, "verified by v2");

        address thirdVerifier = address(0x5);
        vm.prank(thirdVerifier);
        string[] memory proofs3 = new string[](1);
        proofs3[0] = "proof3";
        treeNft.verify(0, proofs3, "verified by v3");

        assertTrue(treeNft.isVerified(0, verifier1));
        assertTrue(treeNft.isVerified(0, verifier2));
        assertTrue(treeNft.isVerified(0, thirdVerifier));

        (TreeNftVerification[] memory allVerifications,,) = treeNft.getTreeNftVerifiersPaginated(0, 0, 100);
        assertEq(allVerifications.length, 3);

        vm.prank(planter);
        treeNft.removeVerification(0, verifier2);

        assertTrue(treeNft.isVerified(0, verifier1));
        assertTrue(treeNft.isVerified(0, verifier2));
        assertTrue(treeNft.isVerified(0, thirdVerifier));

        (TreeNftVerification[] memory remainingVerifications,,) = treeNft.getTreeNftVerifiersPaginated(0, 0, 100);
        assertEq(remainingVerifications.length, 2);
    }

    function test_getUserVerifierTokenDetailsPaginated() public {
        // Register user and mint trees

        vm.prank(verifier1);
        treeNft.registerUserProfile("Verifier1", "ipfs://profile1");

        string[] memory photos = new string[](1);
        photos[0] = "photo1";

        vm.prank(planter);
        treeNft.mintNft(LATITUDE, LONGITUDE, "Tree1", IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(planter);
        treeNft.mintNft(
            LATITUDE + 1000, LONGITUDE + 1000, "Tree2", IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES
        );

        vm.prank(planter);
        treeNft.mintNft(
            LATITUDE + 2000, LONGITUDE + 2000, "Tree3", IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES
        );

        // Verifier1 verifies all trees
        vm.prank(verifier1);
        string[] memory proofs = new string[](1);
        proofs[0] = "proof1";
        treeNft.verify(0, proofs, "verified tree 0");

        vm.prank(verifier1);
        treeNft.verify(1, proofs, "verified tree 1");

        vm.prank(verifier1);
        treeNft.verify(2, proofs, "verified tree 2");

        (VerificationDetails[] memory details1, uint256 totalCount1) =
            treeNft.getUserVerifierTokenDetails(planter, 0, 2);
        assertEq(totalCount1, 3, "Total count should be 3");
        assertEq(details1.length, 2, "Should return 2 items with limit=2");
        assertEq(details1[0].verifier, verifier1);
        assertEq(details1[1].verifier, verifier1);
        assertEq(details1[0].numberOfTrees, 3 * NUM_TREES * 1e18);
        assertEq(details1[1].numberOfTrees, 3 * NUM_TREES * 1e18);

        (VerificationDetails[] memory details2, uint256 totalCount2) =
            treeNft.getUserVerifierTokenDetails(planter, 2, 2);
        assertEq(details2.length, 1);
        assertEq(totalCount2, 3);
        assertEq(details2[0].verifier, verifier1);
        assertEq(details2[0].numberOfTrees, 3 * NUM_TREES * 1e18);

        (VerificationDetails[] memory details3, uint256 totalCount3) =
            treeNft.getUserVerifierTokenDetails(planter, 5, 2);
        assertEq(details3.length, 0);
        assertEq(totalCount3, 3);
    }

    function test_getUserVerifierTokenDetailsEmptyUser() public view {
        // Test with user who has no verifications
        (VerificationDetails[] memory details, uint256 totalCount) =
            treeNft.getUserVerifierTokenDetails(verifier1, 0, 10);
        assertEq(details.length, 0);
        assertEq(totalCount, 0);
    }

    function test_getUserVerifierTokenDetailsWithTokenBalances() public {
        // Register user and mint tree
        vm.prank(verifier1);
        treeNft.registerUserProfile("Verifier1", "ipfs://profile1");

        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(verifier1);
        string[] memory proofs = new string[](1);
        proofs[0] = "proof1";
        treeNft.verify(0, proofs, "verified");

        (VerificationDetails[] memory details, uint256 totalCount) = treeNft.getUserVerifierTokenDetails(planter, 0, 10);
        assertEq(details.length, 1);
        assertEq(totalCount, 1);

        address planterTokenAddr = treeNft.s_userToPlanterTokenAddress(verifier1);
        PlanterToken planterToken = PlanterToken(planterTokenAddr);
        assertEq(details[0].numberOfTrees, planterToken.balanceOf(planter));
        assertEq(details[0].numberOfTrees, NUM_TREES * 1e18);
        assertEq(details[0].verifierPlanterTokenAddress, planterTokenAddr);
        assertEq(details[0].description, "verified");
        assertFalse(details[0].isHidden);
    }

    function test_getUserVerifierTokenDetailsWithHiddenVerifications() public {
        // Register users and mint tree
        vm.prank(verifier1);
        treeNft.registerUserProfile("Verifier1", "ipfs://profile1");

        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(verifier1);
        string[] memory proofs = new string[](1);
        proofs[0] = "proof1";
        treeNft.verify(0, proofs, "verified");

        vm.prank(planter);
        treeNft.removeVerification(0, verifier1);

        (VerificationDetails[] memory details, uint256 totalCount) = treeNft.getUserVerifierTokenDetails(planter, 0, 10);
        assertEq(details.length, 1);
        assertEq(totalCount, 1);
        assertTrue(details[0].isHidden); // Should be marked as hidden
        assertEq(details[0].verifier, verifier1);
    }

    function test_getUserVerifierTokenDetailsPaginationBoundaries() public {
        // Register user and mint tree

        vm.prank(verifier1);
        treeNft.registerUserProfile("Verifier1", "ipfs://profile1");

        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        // Verifier1 verifies the tree
        vm.prank(verifier1);
        string[] memory proofs = new string[](1);
        proofs[0] = "proof1";
        treeNft.verify(0, proofs, "verified");

        (VerificationDetails[] memory details1, uint256 totalCount1) =
            treeNft.getUserVerifierTokenDetails(planter, 0, 100);
        assertEq(details1.length, 1);
        assertEq(totalCount1, 1);

        (VerificationDetails[] memory details2, uint256 totalCount2) =
            treeNft.getUserVerifierTokenDetails(planter, 1, 10);
        assertEq(details2.length, 0);
        assertEq(totalCount2, 1);

        (VerificationDetails[] memory details3, uint256 totalCount3) =
            treeNft.getUserVerifierTokenDetails(planter, 0, 0);
        assertEq(details3.length, 0);
        assertEq(totalCount3, 1);
    }

    function test_cannotReverifyAfterRemoval() public {
        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(verifier1);
        string[] memory proofs = new string[](1);
        proofs[0] = "proof1";
        treeNft.verify(0, proofs, "verified");
        assertTrue(treeNft.isVerified(0, verifier1));

        vm.prank(planter);
        treeNft.removeVerification(0, verifier1);
        assertTrue(treeNft.isVerified(0, verifier1));

        vm.prank(verifier1);
        vm.expectRevert(AlreadyVerified.selector);
        treeNft.verify(0, proofs, "try to verify again");
    }

    function test_removeVerificationOptimized() public {
        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(verifier1);
        string[] memory proofs = new string[](1);
        proofs[0] = "proof1";
        treeNft.verify(0, proofs, "verified");

        address planterTokenAddr = treeNft.s_userToPlanterTokenAddress(verifier1);
        PlanterToken planterToken = PlanterToken(planterTokenAddr);
        assertEq(planterToken.balanceOf(planter), NUM_TREES * 1e18);

        uint256 verificationId = 0;
        uint256 verifierArrayIndex = 0;
        uint256 verifiedTreesArrayIndex = 0;
        uint256 userVerificationIndex = 0;
        uint256 verifierTokenAddrIndex = 0;

        vm.prank(planter);
        treeNft.removeVerificationOptimized(
            verificationId, verifierArrayIndex, verifiedTreesArrayIndex, userVerificationIndex, verifierTokenAddrIndex
        );

        (TreeNftVerification[] memory verifications,,) = treeNft.getTreeNftVerifiersPaginated(0, 0, 100);
        assertEq(verifications.length, 0);
        assertEq(planterToken.balanceOf(planter), 0);
    }

    function test_removeVerificationOptimizedWithMultipleVerifiers() public {
        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(verifier1);
        string[] memory proofs1 = new string[](1);
        proofs1[0] = "proof1";
        treeNft.verify(0, proofs1, "verified by v1");

        vm.prank(verifier2);
        string[] memory proofs2 = new string[](1);
        proofs2[0] = "proof2";
        treeNft.verify(0, proofs2, "verified by v2");

        uint256 verificationId = 1;
        uint256 verifierArrayIndex = 1;
        uint256 verifiedTreesArrayIndex = 0;
        uint256 userVerificationIndex = 1;
        uint256 verifierTokenAddrIndex = 1;

        vm.prank(planter);
        treeNft.removeVerificationOptimized(
            verificationId, verifierArrayIndex, verifiedTreesArrayIndex, userVerificationIndex, verifierTokenAddrIndex
        );

        (TreeNftVerification[] memory verifications,,) = treeNft.getTreeNftVerifiersPaginated(0, 0, 100);
        assertEq(verifications.length, 1);
        assertEq(verifications[0].verifier, verifier1);
    }

    function test_removeVerificationOptimizedInvalidVerificationId() public {
        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(verifier1);
        string[] memory proofs = new string[](1);
        proofs[0] = "proof1";
        treeNft.verify(0, proofs, "verified");

        vm.prank(planter);
        vm.expectRevert(VerificationNotFound.selector);
        treeNft.removeVerificationOptimized(999, 0, 0, 0, 0);
    }

    function test_removeVerificationOptimizedInvalidVerifierIndex() public {
        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(verifier1);
        string[] memory proofs = new string[](1);
        proofs[0] = "proof1";
        treeNft.verify(0, proofs, "verified");

        vm.prank(planter);
        vm.expectRevert(VerificationNotFound.selector);
        treeNft.removeVerificationOptimized(0, 999, 0, 0, 0);
    }

    function test_removeVerificationOptimizedInvalidTreeIndex() public {
        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(verifier1);
        string[] memory proofs = new string[](1);
        proofs[0] = "proof1";
        treeNft.verify(0, proofs, "verified");

        vm.prank(planter);
        vm.expectRevert(VerificationNotFound.selector);
        treeNft.removeVerificationOptimized(0, 0, 999, 0, 0);
    }

    function test_removeVerificationOptimizedInvalidUserVerificationIndex() public {
        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(verifier1);
        string[] memory proofs = new string[](1);
        proofs[0] = "proof1";
        treeNft.verify(0, proofs, "verified");

        vm.prank(planter);
        vm.expectRevert(VerificationNotFound.selector);
        treeNft.removeVerificationOptimized(0, 0, 0, 999, 0);
    }

    function test_removeVerificationOptimizedOnlyOwner() public {
        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(verifier1);
        string[] memory proofs = new string[](1);
        proofs[0] = "proof1";
        treeNft.verify(0, proofs, "verified");

        vm.prank(verifier2);
        vm.expectRevert(NotTreeOwner.selector);
        treeNft.removeVerificationOptimized(0, 0, 0, 0, 0);
    }

    function test_removeVerificationOptimizedAlreadyHidden() public {
        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(verifier1);
        string[] memory proofs = new string[](1);
        proofs[0] = "proof1";
        treeNft.verify(0, proofs, "verified");

        vm.prank(planter);
        treeNft.removeVerificationOptimized(0, 0, 0, 0, 0);

        vm.prank(planter);
        vm.expectRevert(VerificationNotFound.selector);
        treeNft.removeVerificationOptimized(0, 0, 0, 0, 0);
    }

    function test_removeVerificationOptimizedEmitsEvent() public {
        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(verifier1);
        string[] memory proofs = new string[](1);
        proofs[0] = "proof1";
        treeNft.verify(0, proofs, "verified");

        vm.prank(planter);
        vm.expectEmit(true, true, true, false);
        emit VerificationRemoved(0, 0, verifier1);
        treeNft.removeVerificationOptimized(0, 0, 0, 0, 0);
    }

    function test_removeVerificationOptimizedWithInsufficientTokens() public {
        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(verifier1);
        string[] memory proofs = new string[](1);
        proofs[0] = "proof1";
        treeNft.verify(0, proofs, "verified");

        address planterTokenAddr = treeNft.s_userToPlanterTokenAddress(verifier1);
        PlanterToken planterToken = PlanterToken(planterTokenAddr);

        vm.prank(planter);
        planterToken.transfer(address(0x999), (NUM_TREES * 1e18) / 2);

        vm.prank(planter);
        treeNft.removeVerificationOptimized(0, 0, 0, 0, 0);

        (TreeNftVerification[] memory verifications,,) = treeNft.getTreeNftVerifiersPaginated(0, 0, 100);
        assertEq(verifications.length, 0);
    }

    function test_removeVerificationOptimizedRevocationCounter() public {
        vm.prank(verifier1);
        treeNft.registerUserProfile("Verifier1", "ipfs://profile");

        vm.prank(planter);
        string[] memory photos = new string[](1);
        photos[0] = "photo1";
        treeNft.mintNft(LATITUDE, LONGITUDE, SPECIES, IMAGE_URI, QR_HASH, METADATA, GEOHASH, photos, NUM_TREES);

        vm.prank(verifier1);
        string[] memory proofs = new string[](1);
        proofs[0] = "proof1";
        treeNft.verify(0, proofs, "verified");

        vm.prank(planter);
        treeNft.removeVerificationOptimized(0, 0, 0, 0, 0);

        UserDetails memory userDetails = treeNft.getUserProfile(verifier1);
        assertEq(userDetails.verificationsRevoked, 1);
    }
}
