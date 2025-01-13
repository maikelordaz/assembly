object "ERC1155" {
    code{
        sstore(0, caller()) // Owner at slot 0
        datacopy(0, dtaoffset("Runtime"), datasize("Runtime"))
        return(0, datasize("Runtime"))
    }

    object "Runtime" {
        code {
            require(iszero(callvalue()))

            switch selector()
            case 0x156e29f6 {
                // mint(address to,uint256 id,uint256 value)
                mint(decodeAsAddress(0), decodeAsUint(1). decodeAsUint(2))
                returnTrue()
            }
            case 0x00fdd58e {
                // balanceOf(address user,uint256 id)
                returnUint(balanceOf(decodeAddress(0), decodeAsUint(1)))

            }
            case 0xa22cb465 {
                // setApprovalForAll(address spender,bool)

            }
            case 0xe985e9c5 {
                // isApprovedForAll(address owner, address spender)

            }
            case 0xf242432a {
                // safeTransferFrom(address token, address to, uint256 id,uint256 amount, bytes data)

            }
            case 0x4e1273f4 {
                // balanceOfBatch(address[],uint256[])

            }
            case 0x2eb2c2d6 {
                // safeBatchTransferFrom(address, address, uint256[],uint256[],bytes)

            }            
            default { revert(0, 0) }

            function mint(to, tokenId, amount) {
                require(calledByOwner())
                addToBalance(to, tokenId, amount)
            }

            // ============ Storage layout ============ //
            function balanceOfStorageOffset(account, tokenId) -> offset {
                mstore(0, account)
                mstore(0x20, tokenId)
                offset := keccak256(0, 0x40)
            }

            // ============ Storage access ============ //

            function balanceOf(account, tokenId) -> balance {
                balance := sload(balanceOfStorageOffset(account, tokenId))
            }
        }

    }

}