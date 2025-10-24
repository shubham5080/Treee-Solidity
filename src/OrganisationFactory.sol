// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Organisation.sol";
import "./utils/structs.sol";
import "./utils/errors.sol";

contract OrganisationFactory is Ownable {
    address public treeNFTContract;

    mapping(address => Organisation) public s_organisationAddressToOrganisation;
    mapping(address => address[]) public s_userToOrganisations;
    mapping(address => address[]) private s_userToOrganisationsAsOwner;
    mapping(address => address[]) private s_userToOrganisationsAsMember;
    mapping(address => bool) private s_isOrganisation;

    address[] private s_allOrganisations;
    uint256 public paginationLimit = 50;

    constructor(address _treeNFTContract) Ownable(msg.sender) {
        treeNFTContract = _treeNFTContract;
    }

    function createOrganisation(string memory _name, string memory _description, string memory _photoIpfsHash)
        external
        returns (uint256 organisationId, address organisationAddress)
    {
        // This function allows a user to create a new organization.

        if (bytes(_name).length == 0) revert InvalidNameInput();
        if (bytes(_description).length == 0) revert InvalidDescriptionInput();

        Organisation newOrganisation = new Organisation(
            _name, _description, _photoIpfsHash, msg.sender, address(this), treeNFTContract, msg.sender
        );
        organisationAddress = address(newOrganisation);
        s_userToOrganisations[msg.sender].push(organisationAddress);
        s_userToOrganisationsAsOwner[msg.sender].push(organisationAddress);
        s_isOrganisation[organisationAddress] = true;
        s_allOrganisations.push(organisationAddress);
        s_organisationAddressToOrganisation[organisationAddress] = newOrganisation;
        return (organisationId, organisationAddress);
    }

    function getUserOrganisations(address _user, uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory orgs, uint256 totalCount)
    {
        if (limit > paginationLimit) revert PaginationLimitExceeded();
        address[] memory allUserOrgs = s_userToOrganisations[_user];
        totalCount = allUserOrgs.length;
        if (offset >= totalCount) {
            return (new address[](0), totalCount);
        }
        uint256 end = offset + limit;
        if (end > totalCount) {
            end = totalCount;
        }
        uint256 resultLength = end - offset;
        orgs = new address[](resultLength);
        for (uint256 i = 0; i < resultLength; i++) {
            orgs[i] = allUserOrgs[offset + i];
        }
        return (orgs, totalCount);
    }

    function getMyOrganisations(uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory orgs, uint256 totalCount)
    {
        if (limit > paginationLimit) revert PaginationLimitExceeded();
        return this.getUserOrganisations(msg.sender, offset, limit);
    }

    function getAllOrganisations(uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory orgs, uint256 totalCount)
    {
        if (limit > paginationLimit) revert PaginationLimitExceeded();
        totalCount = s_allOrganisations.length;
        if (offset >= totalCount) {
            return (new address[](0), totalCount);
        }
        uint256 end = offset + limit;
        if (end > totalCount) {
            end = totalCount;
        }
        uint256 resultLength = end - offset;
        orgs = new address[](resultLength);
        for (uint256 i = 0; i < resultLength; i++) {
            orgs[i] = s_allOrganisations[offset + i];
        }
        return (orgs, totalCount);
    }

    function getOrganisationCount() external view returns (uint256) {
        // This function retrieves the total number of organisations created.

        return s_allOrganisations.length;
    }

    function addMemberToOrganisation(address _member) external {
        // This function adds a member to an organization (called by Organisation contract)
        if (!s_isOrganisation[msg.sender]) revert InvalidOrganisation();
        if (msg.sender == address(0)) revert OrganisationDoesNotExist();
        s_userToOrganisations[_member].push(msg.sender);

        Organisation org = Organisation(msg.sender);
        if (org.checkOwnership(_member)) {
            s_userToOrganisationsAsOwner[_member].push(msg.sender);
        } else {
            s_userToOrganisationsAsMember[_member].push(msg.sender);
        }
    }

    function promoteToOwner(address _member) external {
        // This function updates the role mapping when a member becomes an owner
        if (!s_isOrganisation[msg.sender]) revert InvalidOrganisation();

        // Remove from member-only array
        address[] storage memberOrgs = s_userToOrganisationsAsMember[_member];
        for (uint256 i; i < memberOrgs.length;) {
            if (memberOrgs[i] == msg.sender) {
                memberOrgs[i] = memberOrgs[memberOrgs.length - 1];
                memberOrgs.pop();
                break;
            }
            unchecked {
                ++i;
            }
        }

        // Add to owner array
        s_userToOrganisationsAsOwner[_member].push(msg.sender);
    }

    function removeMemberFromOrganisation(address _member, bool _wasOwner) external {
        // This function removes a member from an organization (called by Organisation contract)
        if (!s_isOrganisation[msg.sender]) revert InvalidOrganisation();

        // Remove from s_userToOrganisations
        address[] storage userOrgs = s_userToOrganisations[_member];
        for (uint256 i; i < userOrgs.length;) {
            if (userOrgs[i] == msg.sender) {
                userOrgs[i] = userOrgs[userOrgs.length - 1];
                userOrgs.pop();
                break;
            }
            unchecked {
                ++i;
            }
        }

        // Remove from role-specific mapping
        if (_wasOwner) {
            address[] storage ownerOrgs = s_userToOrganisationsAsOwner[_member];
            for (uint256 i; i < ownerOrgs.length;) {
                if (ownerOrgs[i] == msg.sender) {
                    ownerOrgs[i] = ownerOrgs[ownerOrgs.length - 1];
                    ownerOrgs.pop();
                    break;
                }
                unchecked {
                    ++i;
                }
            }
        } else {
            address[] storage memberOrgs = s_userToOrganisationsAsMember[_member];
            for (uint256 i; i < memberOrgs.length;) {
                if (memberOrgs[i] == msg.sender) {
                    memberOrgs[i] = memberOrgs[memberOrgs.length - 1];
                    memberOrgs.pop();
                    break;
                }
                unchecked {
                    ++i;
                }
            }
        }
    }

    function getOrganisationInfo(address _organisationAddress)
        external
        view
        returns (
            address organisationAddress,
            string memory name,
            string memory description,
            string memory photoIpfsHash,
            address[] memory owners,
            address[] memory members,
            uint256 timeOfCreation
        )
    {
        // This function retrieves detailed information about an organization based on its ID.
        if (!s_isOrganisation[_organisationAddress]) {
            revert OrganisationDoesNotExist();
        }
        Organisation org = Organisation(_organisationAddress);
        return org.getOrganisationInfo();
    }

    function getAllOrganisationDetails(uint256 offset, uint256 limit)
        external
        view
        returns (OrganisationDetails[] memory organizationDetails, uint256 totalCount)
    {
        if (limit > paginationLimit) revert PaginationLimitExceeded();
        totalCount = s_allOrganisations.length;
        if (offset >= totalCount) {
            return (new OrganisationDetails[](0), totalCount);
        }
        uint256 end = offset + limit;
        if (end > totalCount) {
            end = totalCount;
        }
        uint256 resultLength = end - offset;
        organizationDetails = new OrganisationDetails[](resultLength);
        for (uint256 i = 0; i < resultLength; i++) {
            address organisationAddress = s_allOrganisations[offset + i];
            Organisation org = Organisation(organisationAddress);
            try org.getOrganisationInfo() returns (
                address orgAddress,
                string memory name,
                string memory description,
                string memory photoIpfsHash,
                address[] memory owners,
                address[] memory members,
                uint256 timeOfCreation
            ) {
                organizationDetails[i] = OrganisationDetails({
                    contractAddress: orgAddress,
                    name: name,
                    description: description,
                    organisationPhoto: photoIpfsHash,
                    owners: owners,
                    members: members,
                    ownerCount: owners.length,
                    memberCount: members.length,
                    isActive: s_isOrganisation[orgAddress],
                    timeOfCreation: timeOfCreation
                });
            } catch {
                organizationDetails[i] = OrganisationDetails({
                    contractAddress: organisationAddress,
                    name: "ERROR: Unable to fetch",
                    description: "ERROR: Contract call failed",
                    organisationPhoto: "",
                    owners: new address[](0),
                    members: new address[](0),
                    ownerCount: 0,
                    memberCount: 0,
                    isActive: false,
                    timeOfCreation: 0
                });
            }
        }

        return (organizationDetails, totalCount);
    }

    function removeOrganisation(address _organisationAddress) external onlyOwner {
        // This function allows the owner to remove an organization from the factory.

        if (s_isOrganisation[_organisationAddress] == false) {
            revert OrganisationDoesNotExist();
        }
        s_isOrganisation[_organisationAddress] = false;
        for (uint256 i = 0; i < s_allOrganisations.length; i++) {
            if (s_allOrganisations[i] == _organisationAddress) {
                s_allOrganisations[i] = s_allOrganisations[s_allOrganisations.length - 1];
                s_allOrganisations.pop();
                break;
            }
        }
    }

    function getTreeNFTContract() external view returns (address) {
        // This function retrieves the address of the Tree NFT contract.
        return treeNFTContract;
    }

    function getUserOrganisationsAsOwner(address _user, uint256 offset, uint256 limit)
        external
        view
        returns (OrganisationDetails[] memory orgs, uint256 totalCount)
    {
        // This function retrieves paginated organizations where the user is an owner/admin

        if (limit > paginationLimit) revert MaximumLimitRequestExceeded();
        address[] memory ownerOrgs = s_userToOrganisationsAsOwner[_user];
        totalCount = ownerOrgs.length;

        if (offset >= totalCount || limit == 0) {
            return (new OrganisationDetails[](0), totalCount);
        }

        uint256 end = offset + limit;
        if (end > totalCount) {
            end = totalCount;
        }
        uint256 resultLength = end - offset;

        orgs = new OrganisationDetails[](resultLength);

        for (uint256 i; i < resultLength;) {
            address orgAddr = ownerOrgs[offset + i];
            Organisation org = Organisation(orgAddr);

            try org.getOrganisationInfo() returns (
                address orgAddress,
                string memory name,
                string memory description,
                string memory photoIpfsHash,
                address[] memory owners,
                address[] memory members,
                uint256 timeOfCreation
            ) {
                orgs[i] = OrganisationDetails({
                    contractAddress: orgAddress,
                    name: name,
                    description: description,
                    organisationPhoto: photoIpfsHash,
                    owners: owners,
                    members: members,
                    ownerCount: owners.length,
                    memberCount: members.length,
                    isActive: s_isOrganisation[orgAddress],
                    timeOfCreation: timeOfCreation
                });
            } catch {
                orgs[i] = OrganisationDetails({
                    contractAddress: orgAddr,
                    name: "ERROR: Unable to fetch",
                    description: "ERROR: Contract call failed",
                    organisationPhoto: "",
                    owners: new address[](0),
                    members: new address[](0),
                    ownerCount: 0,
                    memberCount: 0,
                    isActive: false,
                    timeOfCreation: 0
                });
            }
            unchecked {
                ++i;
            }
        }

        return (orgs, totalCount);
    }

    function getUserOrganisationsAsMember(address _user, uint256 offset, uint256 limit)
        external
        view
        returns (OrganisationDetails[] memory orgs, uint256 totalCount)
    {
        // This function retrieves paginated organizations where the user is a member (but not an owner)

        if (limit > paginationLimit) revert MaximumLimitRequestExceeded();
        address[] memory memberOrgs = s_userToOrganisationsAsMember[_user];
        totalCount = memberOrgs.length;

        if (offset >= totalCount || limit == 0) {
            return (new OrganisationDetails[](0), totalCount);
        }

        uint256 end = offset + limit;
        if (end > totalCount) {
            end = totalCount;
        }
        uint256 resultLength = end - offset;

        orgs = new OrganisationDetails[](resultLength);

        for (uint256 i; i < resultLength;) {
            address orgAddr = memberOrgs[offset + i];
            Organisation org = Organisation(orgAddr);

            try org.getOrganisationInfo() returns (
                address orgAddress,
                string memory name,
                string memory description,
                string memory photoIpfsHash,
                address[] memory owners,
                address[] memory members,
                uint256 timeOfCreation
            ) {
                orgs[i] = OrganisationDetails({
                    contractAddress: orgAddress,
                    name: name,
                    description: description,
                    organisationPhoto: photoIpfsHash,
                    owners: owners,
                    members: members,
                    ownerCount: owners.length,
                    memberCount: members.length,
                    isActive: s_isOrganisation[orgAddress],
                    timeOfCreation: timeOfCreation
                });
            } catch {
                orgs[i] = OrganisationDetails({
                    contractAddress: orgAddr,
                    name: "ERROR: Unable to fetch",
                    description: "ERROR: Contract call failed",
                    organisationPhoto: "",
                    owners: new address[](0),
                    members: new address[](0),
                    ownerCount: 0,
                    memberCount: 0,
                    isActive: false,
                    timeOfCreation: 0
                });
            }
            unchecked {
                ++i;
            }
        }

        return (orgs, totalCount);
    }

    function getMyOrganisationsAsOwner(uint256 offset, uint256 limit)
        external
        view
        returns (OrganisationDetails[] memory orgs, uint256 totalCount)
    {
        // This function retrieves paginated organizations where the caller is an owner/admin
        if (limit > paginationLimit) revert MaximumLimitRequestExceeded();
        return this.getUserOrganisationsAsOwner(msg.sender, offset, limit);
    }

    function getMyOrganisationsAsMember(uint256 offset, uint256 limit)
        external
        view
        returns (OrganisationDetails[] memory orgs, uint256 totalCount)
    {
        // This function retrieves paginated organizations where the caller is a member (but not an owner)

        if (limit > paginationLimit) revert MaximumLimitRequestExceeded();
        return this.getUserOrganisationsAsMember(msg.sender, offset, limit);
    }
}
