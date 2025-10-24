// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console.sol";

import "../src/OrganisationFactory.sol";
import "../src/Organisation.sol";
import "../src/utils/structs.sol";
import "../src/utils/errors.sol";
import "../src/TreeNft.sol";

import "../src/token-contracts/CareToken.sol";
import "../src/token-contracts/PlanterToken.sol";
import "../src/token-contracts/LegacyToken.sol";

contract OrganisationFactoryTest is Test {
    OrganisationFactory private factory;
    TreeNft private treeNft;
    CareToken public careToken;
    LegacyToken public legacyToken;

    address private owner = address(0x1);
    address private user1 = address(0x2);
    address private user2 = address(0x3);
    address private user3 = address(0x4);
    address private user4 = address(0x5);

    string constant NAME1 = "Test Organisation";
    string constant DESCRIPTION1 = "This is a test organisation.";
    string constant PHOTO_HASH1 = "QmTestPhotoHash";
    string constant NAME2 = "Test Organisation";
    string constant DESCRIPTION2 = "This is a test organisation.";
    string constant PHOTO_HASH2 = "QmTestPhotoHash";

    function setUp() public {
        vm.startPrank(owner);

        careToken = new CareToken(owner);
        legacyToken = new LegacyToken(owner);

        treeNft = new TreeNft(address(careToken), address(legacyToken));

        careToken.transferOwnership(address(treeNft));
        legacyToken.transferOwnership(address(treeNft));

        vm.stopPrank();

        assertEq(careToken.owner(), address(treeNft));
        assertEq(legacyToken.owner(), address(treeNft));

        assertEq(address(treeNft.careTokenContract()), address(careToken));
        assertEq(address(treeNft.legacyToken()), address(legacyToken));

        vm.startPrank(owner);
        factory = new OrganisationFactory(address(treeNft));
        vm.stopPrank();
    }

    function test_Constructor() public view {
        // This test checks if the constructor initializes the factory correctly by verifying the owner, treeNFTContract, and organisation count.

        assertEq(factory.owner(), owner);
        assertEq(factory.treeNFTContract(), address(treeNft));
        assertEq(factory.getOrganisationCount(), 0);
    }

    function test_CreateOrganisation() public {
        // This test checks if the createOrganisation function works correctly by creating an organisation and verifying its details.

        vm.prank(user1);
        (uint256 orgId, address orgAddress) = factory.createOrganisation(NAME1, DESCRIPTION1, PHOTO_HASH1);
        assertEq(orgId, 0);
        assertEq(factory.getOrganisationCount(), 1);
        (
            address organizationAddress,
            string memory name,
            string memory description,
            string memory photoIpfsHash,
            address[] memory owners,
            address[] memory members,
            uint256 timeOfCreation
        ) = factory.getOrganisationInfo(orgAddress);
        assert(organizationAddress == orgAddress);
        assertEq(name, NAME1);
        assertEq(description, DESCRIPTION1);
        assertEq(photoIpfsHash, PHOTO_HASH1);
        assertEq(owners[0], user1);
        assertEq(members.length, 1);
        assertEq(timeOfCreation, block.timestamp);
    }

    function test_getMyOrganisations() public {
        // This test checks if the getMyOrganisations function returns the correct organisation details for a user.

        vm.prank(user1);
        factory.createOrganisation(NAME1, DESCRIPTION1, PHOTO_HASH1);
        vm.stopPrank();
        vm.prank(user2);
        factory.createOrganisation(NAME2, DESCRIPTION2, PHOTO_HASH2);
        vm.stopPrank();

        vm.startPrank(user1);
        (address[] memory user1Orgs, uint256 count1) = factory.getMyOrganisations(0, 10);
        vm.stopPrank();
        vm.startPrank(user2);
        (address[] memory user2Orgs, uint256 count2) = factory.getMyOrganisations(0, 10);
        vm.stopPrank();

        assertEq(user1Orgs.length, 1);
        assertEq(count1, 1);
        assertEq(user2Orgs.length, 1);
        assertEq(count2, 1);
    }

    function test_getAllOrganisations() public {
        // This test checks if the factory can return all organisations correctly.

        vm.prank(user1);
        factory.createOrganisation(NAME1, DESCRIPTION1, PHOTO_HASH1);
        vm.stopPrank();
        vm.prank(user2);
        factory.createOrganisation(NAME2, DESCRIPTION2, PHOTO_HASH2);
        vm.stopPrank();

        (OrganisationDetails[] memory orgs, uint256 totalCount) = factory.getAllOrganisationDetails(0, 10);
        assertEq(orgs.length, 2);
        assertEq(totalCount, 2);
        assertEq(orgs[0].name, NAME1);
        assertEq(orgs[0].description, DESCRIPTION1);
        assertEq(orgs[0].organisationPhoto, PHOTO_HASH1);
        assertEq(orgs[0].ownerCount, 1);
        assertEq(orgs[0].memberCount, 1);
        assertEq(orgs[1].name, NAME2);
        assertEq(orgs[1].description, DESCRIPTION2);
        assertEq(orgs[1].organisationPhoto, PHOTO_HASH2);
        assertEq(orgs[1].ownerCount, 1);
        assertEq(orgs[1].memberCount, 1);
    }

    function test_getAllOrganisationIDs() public {
        // This test checks if the factory can return all organisation IDs correctly.

        vm.prank(user1);
        factory.createOrganisation(NAME1, DESCRIPTION1, PHOTO_HASH1);
        vm.stopPrank();
        vm.prank(user2);
        factory.createOrganisation(NAME2, DESCRIPTION2, PHOTO_HASH2);
        vm.stopPrank();

        (address[] memory orgAddresses, uint256 totalCount) = factory.getAllOrganisations(0, 10);
        assertEq(orgAddresses.length, 2);
        assertEq(totalCount, 2);
    }

    function test_getUserOrganisationsAsOwner() public {
        // This test checks if getUserOrganisationsAsOwner returns correct organizations where user is owner

        // User1 creates 2 organizations (will be owner of both)
        vm.prank(user1);
        (, address org1) = factory.createOrganisation("Org1", "Description1", "Photo1");
        vm.stopPrank();

        vm.prank(user1);
        (, address org2) = factory.createOrganisation("Org2", "Description2", "Photo2");
        vm.stopPrank();

        // User2 creates 1 organization
        vm.prank(user2);
        factory.createOrganisation("Org3", "Description3", "Photo3");
        vm.stopPrank();

        // Get user1's organizations as owner
        (OrganisationDetails[] memory orgs, uint256 totalCount) = factory.getUserOrganisationsAsOwner(user1, 0, 10);

        assertEq(totalCount, 2);
        assertEq(orgs.length, 2);
        assertEq(orgs[0].contractAddress, org1);
        assertEq(orgs[1].contractAddress, org2);
        assertEq(orgs[0].ownerCount, 1);
        assertEq(orgs[1].ownerCount, 1);
    }

    function test_getUserOrganisationsAsOwnerPagination() public {
        // This test checks pagination works correctly for owner organizations

        // User1 creates 5 organizations
        address[] memory orgAddresses = new address[](5);
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(user1);
            (, address orgAddr) = factory.createOrganisation(
                string(abi.encodePacked("Org", vm.toString(i))),
                string(abi.encodePacked("Desc", vm.toString(i))),
                string(abi.encodePacked("Photo", vm.toString(i)))
            );
            orgAddresses[i] = orgAddr;
            vm.stopPrank();
        }

        // Test pagination: offset 0, limit 2
        (OrganisationDetails[] memory orgs1, uint256 totalCount1) = factory.getUserOrganisationsAsOwner(user1, 0, 2);
        assertEq(totalCount1, 5);
        assertEq(orgs1.length, 2);
        assertEq(orgs1[0].contractAddress, orgAddresses[0]);
        assertEq(orgs1[1].contractAddress, orgAddresses[1]);

        // Test pagination: offset 2, limit 2
        (OrganisationDetails[] memory orgs2, uint256 totalCount2) = factory.getUserOrganisationsAsOwner(user1, 2, 2);
        assertEq(totalCount2, 5);
        assertEq(orgs2.length, 2);
        assertEq(orgs2[0].contractAddress, orgAddresses[2]);
        assertEq(orgs2[1].contractAddress, orgAddresses[3]);

        // Test pagination: offset 4, limit 2 (should return only 1)
        (OrganisationDetails[] memory orgs3, uint256 totalCount3) = factory.getUserOrganisationsAsOwner(user1, 4, 2);
        assertEq(totalCount3, 5);
        assertEq(orgs3.length, 1);
        assertEq(orgs3[0].contractAddress, orgAddresses[4]);

        // Test pagination: offset beyond total (should return empty array)
        (OrganisationDetails[] memory orgs4, uint256 totalCount4) = factory.getUserOrganisationsAsOwner(user1, 10, 2);
        assertEq(totalCount4, 5);
        assertEq(orgs4.length, 0);
    }

    function test_getUserOrganisationsAsMember() public {
        // This test checks if getUserOrganisationsAsMember returns correct organizations where user is only a member

        // User1 creates organization
        vm.prank(user1);
        (, address org1) = factory.createOrganisation("Org1", "Description1", "Photo1");
        vm.stopPrank();

        // User1 adds user2 as member (not owner)
        vm.prank(user1);
        Organisation(org1).addMember(user2);
        vm.stopPrank();

        // User2 should have 0 owner orgs and 1 member org
        (OrganisationDetails[] memory ownerOrgs, uint256 ownerCount) = factory.getUserOrganisationsAsOwner(user2, 0, 10);
        assertEq(ownerCount, 0);
        assertEq(ownerOrgs.length, 0);

        (OrganisationDetails[] memory memberOrgs, uint256 memberCount) =
            factory.getUserOrganisationsAsMember(user2, 0, 10);
        assertEq(memberCount, 1);
        assertEq(memberOrgs.length, 1);
        assertEq(memberOrgs[0].contractAddress, org1);
    }

    function test_getUserOrganisationsAsMemberPagination() public {
        // This test checks pagination works correctly for member organizations

        // User1 creates 3 organizations and adds user2 as member to all
        address[] memory orgAddresses = new address[](3);
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(user1);
            (, address orgAddr) = factory.createOrganisation(
                string(abi.encodePacked("Org", vm.toString(i))),
                string(abi.encodePacked("Desc", vm.toString(i))),
                string(abi.encodePacked("Photo", vm.toString(i)))
            );
            orgAddresses[i] = orgAddr;
            vm.stopPrank();

            vm.prank(user1);
            Organisation(orgAddr).addMember(user2);
            vm.stopPrank();
        }

        // Test pagination: offset 0, limit 2
        (OrganisationDetails[] memory orgs1, uint256 totalCount1) = factory.getUserOrganisationsAsMember(user2, 0, 2);
        assertEq(totalCount1, 3);
        assertEq(orgs1.length, 2);

        // Test pagination: offset 2, limit 2 (should return only 1)
        (OrganisationDetails[] memory orgs2, uint256 totalCount2) = factory.getUserOrganisationsAsMember(user2, 2, 2);
        assertEq(totalCount2, 3);
        assertEq(orgs2.length, 1);
    }

    function test_promoteToOwner() public {
        // This test checks if promoting a member to owner updates the role mappings correctly

        // User1 creates organization
        vm.prank(user1);
        (, address org1) = factory.createOrganisation("Org1", "Description1", "Photo1");
        vm.stopPrank();

        // User1 adds user2 as member
        vm.prank(user1);
        Organisation(org1).addMember(user2);
        vm.stopPrank();

        // Initially, user2 should be only a member
        (, uint256 ownerCount1) = factory.getUserOrganisationsAsOwner(user2, 0, 10);
        (, uint256 memberCount1) = factory.getUserOrganisationsAsMember(user2, 0, 10);
        assertEq(ownerCount1, 0);
        assertEq(memberCount1, 1);

        // Promote user2 to owner
        vm.prank(user1);
        Organisation(org1).makeOwner(user2);
        vm.stopPrank();

        // After promotion, user2 should be owner and not in member-only list
        (OrganisationDetails[] memory ownerOrgs2, uint256 ownerCount2) =
            factory.getUserOrganisationsAsOwner(user2, 0, 10);
        (, uint256 memberCount2) = factory.getUserOrganisationsAsMember(user2, 0, 10);
        assertEq(ownerCount2, 1);
        assertEq(memberCount2, 0);
        assertEq(ownerOrgs2[0].contractAddress, org1);
    }

    function test_getMyOrganisationsAsOwner() public {
        // This test checks if getMyOrganisationsAsOwner returns correct organizations for the caller

        vm.prank(user1);
        (, address org1) = factory.createOrganisation("Org1", "Description1", "Photo1");
        vm.stopPrank();

        vm.prank(user1);
        (, address org2) = factory.createOrganisation("Org2", "Description2", "Photo2");
        vm.stopPrank();

        vm.prank(user1);
        (OrganisationDetails[] memory orgs, uint256 totalCount) = factory.getMyOrganisationsAsOwner(0, 10);
        vm.stopPrank();

        assertEq(totalCount, 2);
        assertEq(orgs.length, 2);
        assertEq(orgs[0].contractAddress, org1);
        assertEq(orgs[1].contractAddress, org2);
    }

    function test_getMyOrganisationsAsMember() public {
        // This test checks if getMyOrganisationsAsMember returns correct organizations for the caller

        vm.prank(user1);
        (, address org1) = factory.createOrganisation("Org1", "Description1", "Photo1");
        vm.stopPrank();

        vm.prank(user1);
        Organisation(org1).addMember(user2);
        vm.stopPrank();

        vm.prank(user2);
        (OrganisationDetails[] memory orgs, uint256 totalCount) = factory.getMyOrganisationsAsMember(0, 10);
        vm.stopPrank();

        assertEq(totalCount, 1);
        assertEq(orgs.length, 1);
        assertEq(orgs[0].contractAddress, org1);
    }

    function test_mixedRolesAcrossOrganizations() public {
        // This test checks if a user can be owner in some orgs and member in others

        // User1 creates org1, user2 creates org2
        vm.prank(user1);
        (, address org1) = factory.createOrganisation("Org1", "Description1", "Photo1");
        vm.stopPrank();

        vm.prank(user2);
        (, address org2) = factory.createOrganisation("Org2", "Description2", "Photo2");
        vm.stopPrank();

        // User1 adds user2 as member to org1
        vm.prank(user1);
        Organisation(org1).addMember(user2);
        vm.stopPrank();

        // User2 should be owner of 1 org (org2) and member of 1 org (org1)
        (OrganisationDetails[] memory ownerOrgs, uint256 ownerCount) = factory.getUserOrganisationsAsOwner(user2, 0, 10);
        (OrganisationDetails[] memory memberOrgs, uint256 memberCount) =
            factory.getUserOrganisationsAsMember(user2, 0, 10);

        assertEq(ownerCount, 1);
        assertEq(memberCount, 1);
        assertEq(ownerOrgs[0].contractAddress, org2);
        assertEq(memberOrgs[0].contractAddress, org1);
    }

    function test_emptyResultsForUserWithNoOrganizations() public view {
        // This test checks if empty arrays are returned for users with no organizations

        (OrganisationDetails[] memory ownerOrgs, uint256 ownerCount) = factory.getUserOrganisationsAsOwner(user4, 0, 10);
        (OrganisationDetails[] memory memberOrgs, uint256 memberCount) =
            factory.getUserOrganisationsAsMember(user4, 0, 10);

        assertEq(ownerCount, 0);
        assertEq(ownerOrgs.length, 0);
        assertEq(memberCount, 0);
        assertEq(memberOrgs.length, 0);
    }

    function test_zeroLimitReturnsEmptyArray() public {
        // This test checks if limit of 0 returns empty array

        vm.prank(user1);
        factory.createOrganisation("Org1", "Description1", "Photo1");
        vm.stopPrank();

        (OrganisationDetails[] memory orgs, uint256 totalCount) = factory.getUserOrganisationsAsOwner(user1, 0, 0);

        assertEq(totalCount, 1);
        assertEq(orgs.length, 0);
    }
}
