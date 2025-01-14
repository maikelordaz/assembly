// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {DeployERC1155} from "script/DeployERC1155.s.sol";
import {ERC1155} from "src/ERC1155.sol";

interface IERC1155 {
    function uri(uint256) external view returns (string memory);
    function mint(address, uint, uint) external;
    function balanceOfBatch(
        address[] calldata,
        uint[] calldata
    ) external view returns (uint[] memory);
    function safeTransferFrom(
        address,
        address,
        uint,
        uint,
        bytes memory
    ) external returns (bool);
    function setApprovalForAll(address operator, bool approved) external;
    function safeBatchTransferFrom(
        address from,
        address to,
        uint[] memory,
        uint[] memory,
        bytes memory
    ) external returns (bytes memory);
}

contract ERC1155Test is Test {
    DeployERC1155 public deployer = new DeployERC1155();

    ERC1155 public yulContract;

    address public owner = 0x0000000000000000000000000000000000fffFfF;
    address public alice = 0x0000000000000000000000000000000000AbC123;
    address public bob = 0x0000000000000000000000000000000000123123;
    address public charlie = 0x0000000000000000000000000000000000aBCabc;

    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 amount
    );

    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] amounts
    );

    event ApprovalForAll(
        address indexed account,
        address indexed operator,
        bool approved
    );

    event URI(string value, uint256 indexed id);

    function setUp() public {
        yulContract = ERC1155(deployer.deployContract("ERC1155"));
        yulContract.mint(owner, 1, 10_000);
        vm.startPrank(owner, msg.sender);
    }

    function testBalanceOfOwner() public {
        assertEq(yulContract.balanceOf(owner, 1), 10_000);
    }

    function testBalanceOfWithZeroAddress(uint id) public {
        vm.expectRevert("ERC1155: address zero is not a valid owner");
        yulContract.balanceOf(address(0), id);
    }

    function testBatchBalance(uint amount) public {
        address[] memory addresses = new address[](5);
        addresses[0] = 0xB4bbCc562A3D49A384aFf6481377f2a5c19cf1bF;
        addresses[1] = 0x2D1A0Ead2a42E8b2731E8F6169f0041EC38F7c9a;
        addresses[2] = 0xCA16B6d3D34F781c3E504EC16433EC44b4ac49e6;
        addresses[3] = 0x5fd1a905c827Fd2AdDBCa5D5C4d2170Adcc4c969;
        addresses[4] = 0xFbdc16F71155B583698cfE8658925E6ac94cEB6f;

        uint[] memory ids = new uint[](5);
        ids[0] = 32;
        ids[1] = 64;
        ids[2] = 128;
        ids[3] = 256;
        ids[4] = 512;

        yulContract.mint(addresses[0], ids[0], amount);
        yulContract.mint(addresses[1], ids[1], amount);
        yulContract.mint(addresses[2], ids[2], amount);
        yulContract.mint(addresses[3], ids[3], amount);
        yulContract.mint(addresses[4], ids[4], amount);
    }

    function testBalanceOfBatchMismatched() public {
        address[] memory addresses = new address[](4);
        addresses[0] = 0xB4bbCc562A3D49A384aFf6481377f2a5c19cf1bF;
        addresses[1] = 0x2D1A0Ead2a42E8b2731E8F6169f0041EC38F7c9a;
        addresses[2] = 0xCA16B6d3D34F781c3E504EC16433EC44b4ac49e6;
        addresses[3] = 0x5fd1a905c827Fd2AdDBCa5D5C4d2170Adcc4c969;

        uint[] memory ids = new uint[](5);
        ids[0] = 32;
        ids[1] = 64;
        ids[2] = 128;
        ids[3] = 256;
        ids[4] = 512;
        vm.expectRevert("ERC1155: accounts and ids length mismatch");
        yulContract.balanceOfBatch(addresses, ids);
    }

    function testSetApprovalForAll(address operator, bool approved) public {
        vm.assume(operator != owner);

        vm.expectEmit(true, true, false, true);
        emit ApprovalForAll(owner, operator, approved);
        yulContract.setApprovalForAll(operator, approved);

        assertEq(yulContract.isApprovalForAll(owner, operator), approved);
    }

    function testSetApprovalToSelf(bool approved) public {
        vm.expectRevert("ERC1155: setting approval status for self");
        yulContract.setApprovalForAll(owner, approved);
    }

    function testSafeTransferFromAsOwner(uint8 id, uint8 amount) public {
        vm.assume(id != 1);
        address to = alice;

        assertEq(yulContract.balanceOf(owner, id), 0);

        assertEq(yulContract.balanceOf(to, id), 0);

        yulContract.mint(owner, id, amount);

        assertEq(yulContract.balanceOf(owner, id), amount);

        vm.expectEmit(true, true, true, true);
        emit TransferSingle(owner, owner, to, id, amount);
        yulContract.safeTransferFrom(owner, to, id, amount, "");

        assertEq(yulContract.balanceOf(to, id), amount);

        assertEq(yulContract.balanceOf(owner, id), 0);
    }

    function testSafeTransferFromAsOperator(uint8 id, uint8 amount) public {
        vm.assume(id != 1);

        address to = bob;

        assertEq(yulContract.balanceOf(alice, id), 0);

        assertEq(yulContract.balanceOf(to, id), 0);

        vm.stopPrank();
        vm.startPrank(alice, msg.sender);

        yulContract.setApprovalForAll(owner, true);

        vm.stopPrank();
        vm.startPrank(owner, msg.sender);

        yulContract.mint(alice, id, amount);

        assertEq(yulContract.balanceOf(alice, id), amount);

        yulContract.safeTransferFrom(alice, to, id, amount, "");

        assertEq(yulContract.balanceOf(to, id), amount);

        assertEq(yulContract.balanceOf(alice, id), 0);
    }

    function testSafeTransferFromNotOwner(uint8 id, uint8 amount) public {
        vm.assume(id != 1);

        address to = bob;

        assertEq(yulContract.balanceOf(alice, id), 0);

        assertEq(yulContract.balanceOf(to, id), 0);

        yulContract.mint(alice, id, amount);

        assertEq(yulContract.balanceOf(alice, id), amount);

        vm.expectRevert("ERC1155: caller is not token owner or approved");
        yulContract.safeTransferFrom(alice, to, id, amount, "");
    }

    function testSafeTransferFromToZeroAddress(uint8 id, uint8 amount) public {
        vm.assume(id != 1);

        address to = address(0);

        yulContract.mint(owner, id, amount);

        assertEq(yulContract.balanceOf(owner, id), amount);

        vm.expectRevert("ERC1155: transfer to the zero address");
        yulContract.safeTransferFrom(owner, to, id, amount, "");
    }

    function testSafeTransferFromWithInsufficientBalances() public {
        address to = bob;

        uint amount = 1000;
        uint id = 1010;

        vm.expectRevert("ERC1155: insufficient balance for transfer");
        yulContract.safeTransferFrom(owner, to, id, amount, "");
    }

    function testBurnWithInsufficientBalances() public {
        uint amount = 100;
        uint id = 1010;

        vm.expectRevert("ERC1155: burn amount exceeds balance");
        yulContract.burn(id, amount);
    }

    function testBurnWithZeroAddress() public {
        vm.stopPrank();

        uint id = 1010;
        address zero = address(0);

        vm.prank(zero, msg.sender);
        vm.expectRevert("ERC1155: burn from the zero address");
        yulContract.burn(id, 0);
    }

    function testMintToZeroAddress(uint id, uint amount) public {
        vm.expectRevert("ERC1155: mint to the zero address");
        yulContract.mint(address(0), id, amount);
    }

    function testSafeBatchTransferFrom() public {
        vm.stopPrank();

        vm.startPrank(owner, msg.sender);

        address sender = owner;

        uint[] memory ids = new uint[](5);
        ids[0] = 0xa1;
        ids[1] = 0xb2;
        ids[2] = 0xc3;
        ids[3] = 0xd4;
        ids[4] = 0xe5;

        uint[] memory amounts = new uint[](5);
        amounts[0] = 0xaa;
        amounts[1] = 0xbb;
        amounts[2] = 0xcc;
        amounts[3] = 0xdd;
        amounts[4] = 0xee;

        yulContract.mint(sender, ids[0], amounts[0]);
        yulContract.mint(sender, ids[1], amounts[1]);
        yulContract.mint(sender, ids[2], amounts[2]);
        yulContract.mint(sender, ids[3], amounts[3]);
        yulContract.mint(sender, ids[4], amounts[4]);

        vm.expectEmit(true, true, true, true);
        emit TransferBatch(sender, sender, alice, ids, amounts);
        yulContract.safeBatchTransferFrom(sender, alice, ids, amounts, "");
    }

    function testSimpleMint(uint8 id, uint128 amount) public {
        vm.assume(amount > 0);
        address to = alice;
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(owner, address(0), to, id, amount);
        yulContract.mint(to, id, amount);
    }

    function testSimpleBurn(uint id, uint248 amount) public {
        yulContract.mint(owner, id, amount);

        vm.expectEmit(true, true, true, true);
        emit TransferSingle(owner, owner, address(0), id, amount);
        yulContract.burn(id, amount);

        vm.expectEmit(true, true, true, true);
        emit TransferSingle(owner, owner, address(0), id, amount);

        vm.stopPrank();
    }
}
