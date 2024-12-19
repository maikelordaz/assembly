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
            // mint(address to,uint256 id,uint256 value)
            case 0x156e29f6 {
                mint(decodeAsAddress(0), decodeAsUint(1). decodeAsUint(2))
                returnTrue()
            }
            // balanceOf(address user,uint256 id)
            case 0x00fdd58e {}
            // setApprovalForAll(address spender,bool)
            case 0xa22cb465 {}
            // isApprovedForAll(address owner, address spender)
            case 0xe985e9c5 {}
            // safeTransferFrom(address token, address to, uint256 id,uint256 amount, bytes data)
            case 0xf242432a {}
            // balanceOfBatch(address[],uint256[])
            case 0x4e1273f4 {}
            // safeBatchTransferFrom(address, address, uint256[],uint256[],bytes)
            case 0x2eb2c2d6 {}
            
            default { revert(0, 0) }

            function mint(to, tokenId, amount) {
                require(calledByOwner())
                addToBalance(to, tokenId, amount)
            }
        }

    }

}