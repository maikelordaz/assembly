// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

interface IERC1155 {
    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 value
    );

    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    function balanceOf(
        address owner,
        uint256 id
    ) external view returns (uint256);

    function balanceOfBatch(
        address[] memory owners,
        uint256[] memory tokenIds
    ) external view returns (uint256[] memory balances);

    function isApprovedForAll(
        address owner,
        address spender
    ) external view returns (bool);

    function setApprovalForAll(address operator, bool approved) external;

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes calldata data
    ) external;

    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

    function mintBatch(
        address to,
        uint256[] memory id,
        uint256[] memory value,
        bytes calldata data
    ) external;

    function burn(address from, uint256 id, uint256 amount) external;

    function burnBatch(
        address from,
        uint256[] memory id,
        uint256[] memory value
    ) external;

    function supportsInterface(bytes4 interfaceID) external view returns (bool);

    function uri(uint256 id) external view returns (string memory);

    function setURI(string memory) external;
}
