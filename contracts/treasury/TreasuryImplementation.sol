//SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./interfaces/TreasuryStorageV2.sol";

contract TreasuryImplementation is
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    TreasuryStorageV2
{
    using SafeERC20Upgradeable for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    address constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    /**
     * @notice Triggered when CommunityAdmin has been updated
     *
     * @param oldCommunityAdmin   Old communityAdmin address
     * @param newCommunityAdmin   New communityAdmin address
     */
    event CommunityAdminUpdated(
        address indexed oldCommunityAdmin,
        address indexed newCommunityAdmin
    );

    /**
     * @notice Triggered when lpPercentage has been updated
     *
     * @param oldLpPercentage   Old lpPercentage address
     * @param newLpPercentage   New lpPercentage address
     */
    event LpPercentageUpdated(uint256 oldLpPercentage, uint256 newLpPercentage);

    /**
     * @notice Triggered when an amount of an ERC20 has been transferred from this contract to an address
     *
     * @param token               ERC20 token address
     * @param to                  Address of the receiver
     * @param amount              Amount of the transaction
     */
    event TransferERC20(address indexed token, address indexed to, uint256 amount);

    /**
     * @notice Triggered when a token has been set
     *
     * @param tokenAddress                      Address of the token
     */
    event TokenSet(address indexed tokenAddress);

    /**
     * @notice Triggered when a token has been removed
     *
     * @param tokenAddress        Address of the token
     */
    event TokenRemoved(address indexed tokenAddress);

    /**
     * @notice Triggered when a token has been set
     *
     * @param tokenAddress           Address of the token
     * @param amountIn               Amount changed
     * @param amountOutMin           Minimum amount out
     * @param exchangePath           Exchange path
     * @param amountsOut             Value of the final amount out
     */
    event AmountConverted(
        address indexed tokenAddress,
        uint256 amountIn,
        uint256 amountOutMin,
        bytes exchangePath,
        uint256 amountsOut
    );

    /**
     * @notice Enforces sender to be communityAdmin or owner
     */
    modifier onlyCommunityAdminOrOwner() {
        require(
            msg.sender == address(communityAdmin) || msg.sender == owner(),
            "Treasury: NOT_COMMUNITY_ADMIN AND NOT_OWNER"
        );
        _;
    }

    /**
     * @notice Enforces sender to DAO or impactMarketCouncil
     */
    modifier onlyOwnerOrImpactMarketCouncil() {
        require(
            msg.sender == owner() || msg.sender == address(communityAdmin.impactMarketCouncil()),
            "Treasury: caller is not the owner nor ImpactMarketCouncil"
        );
        _;
    }

    /**
     * @notice Enforces sender to be owner or council or donationMiner
     */
    modifier onlyOwnerOrImpactMarketCouncilOrDonationMiner() {
        require(
            msg.sender == address(communityAdmin) || msg.sender == owner() || msg.sender == address(donationMiner),
                "Treasury: caller is not the owner nor ImpactMarketCouncil nor donationMiner"
        );
        _;
    }

    /**
     * @notice Used to initialize a new Treasury contract
     *
     * @param _communityAdmin    Address of the CommunityAdmin contract
     */
    function initialize(ICommunityAdmin _communityAdmin) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();

        communityAdmin = _communityAdmin;
    }

    /**
     * @notice Returns the current implementation version
     */
    function getVersion() external pure override returns (uint256) {
        return 2;
    }

    /**
     * @notice Returns if an address is an accepted token
     *
     * @param _tokenAddress token address to be checked
     * @return bool true if the tokenAddress is an accepted token
     */
    function isToken(address _tokenAddress) public view override returns (bool) {
        return _tokenList.contains(_tokenAddress);
    }

    /**
     * @notice Returns the address of a token from tokenList
     *
     * @param _index index of the token
     * @return address of the token
     */
    function tokenListAt(uint256 _index) external view override returns (address) {
        return _tokenList.at(_index);
    }

    /**
     * @notice Returns the number of tokens
     *
     * @return uint256 number of tokens
     */
    function tokenListLength() external view override returns (uint256) {
        return _tokenList.length();
    }

    /**
     * @notice Updates the CommunityAdmin contract address
     *
     * @param _newCommunityAdmin address of the new CommunityAdmin contract
     */
    function updateCommunityAdmin(ICommunityAdmin _newCommunityAdmin)
        external
        override
        onlyOwnerOrImpactMarketCouncil
    {
        emit CommunityAdminUpdated(address(communityAdmin), address(_newCommunityAdmin));
        communityAdmin = _newCommunityAdmin;
    }

    /**
     * @notice Updates the PACT contract address
     *
     * @param _newPACT address of the new PACT contract
     */
    function updatePACT(IERC20 _newPACT) external override onlyOwnerOrImpactMarketCouncil {
        PACT = _newPACT;
    }

    /**
     * @notice Updates the DonationMiner contract address
     *
     * @param _newDonationMiner address of the new DonationMiner contract
     */
    function updateDonationMiner(IDonationMiner _newDonationMiner) external override onlyOwnerOrImpactMarketCouncil {
        donationMiner = _newDonationMiner;
    }

    /**
     * @notice Updates the LpSwap contract address
     *
     * @param _newLpSwap address of the new LpSwap contract
     */
    function updateLpSwap(ITreasuryLpSwap _newLpSwap)
        external
        override
        onlyOwnerOrImpactMarketCouncil
    {
        lpSwap = _newLpSwap;
    }

    function updateLpPercentage(uint256 _newLpPercentage)
        external
        override
        onlyOwnerOrImpactMarketCouncil
    {
        emit LpPercentageUpdated(lpPercentage, _newLpPercentage);

        lpPercentage = _newLpPercentage;
    }

    /**
     * @notice Transfers an amount of an ERC20 from this contract to an address
     *
     * @param _token address of the ERC20 token
     * @param _to address of the receiver
     * @param _amount amount of the transaction
     */
    function transfer(
        IERC20 _token,
        address _to,
        uint256 _amount
    ) external override onlyCommunityAdminOrOwner nonReentrant {
        _token.safeTransfer(_to, _amount);

        emit TransferERC20(address(_token), _to, _amount);
    }

    function setToken(
        address _tokenAddress,
        uint256 _rate,
        LpStrategy _lpStrategy,
        uint256 _lpPercentage,
        uint256 _lpMinLimit,
        uint256 _uniswapNFTPositionManagerId,
        bytes memory _exchangePathToCUSD,
        bytes memory _exchangePathToPACT
    ) public override onlyOwnerOrImpactMarketCouncil {
        require(_rate > 0, "Treasury::setToken: Invalid rate");

        emit TokenSet(_tokenAddress);

        tokens[_tokenAddress].rate = _rate;
        tokens[_tokenAddress].lpStrategy = _lpStrategy;
        tokens[_tokenAddress].lpPercentage = _lpPercentage;
        tokens[_tokenAddress].lpMinLimit = _lpMinLimit;

        if (_uniswapNFTPositionManagerId > 0) {
            require(
                lpSwap.uniswapNFTPositionManager().ownerOf(_uniswapNFTPositionManagerId) ==
                    address(lpSwap),
                "Treasury::setToken: invalid uniswapNFTPositionManagerId"
            );
            tokens[_tokenAddress].uniswapNFTPositionManagerId = _uniswapNFTPositionManagerId;
        }

        if (_exchangePathToCUSD.length > 0) {
            require(
                lpSwap.uniswapQuoter().quoteExactInput(_exchangePathToCUSD, 1e18) > 0,
                "Treasury::setToken: invalid exchangePathToCUSD"
            );

            tokens[_tokenAddress].exchangePathToCUSD = _exchangePathToCUSD;
        }

        if (_exchangePathToPACT.length > 0) {
            require(
                lpSwap.uniswapQuoter().quoteExactInput(_exchangePathToPACT, 1e18) > 0,
                "Treasury::setToken: invalid exchangePathToPACT"
            );

            tokens[_tokenAddress].exchangePathToPACT = _exchangePathToPACT;
        }

        _tokenList.add(_tokenAddress);
    }

    function removeToken(address _tokenAddress) external override onlyOwnerOrImpactMarketCouncil {
        require(_tokenList.contains(_tokenAddress), "Treasury::removeToken: this is not a token");

        tokens[_tokenAddress].rate = 0;
        tokens[_tokenAddress].lpStrategy = LpStrategy.NONE;
        tokens[_tokenAddress].lpPercentage = 0;
        tokens[_tokenAddress].lpMinLimit = 0;
        tokens[_tokenAddress].uniswapNFTPositionManagerId = 0;
        delete tokens[_tokenAddress].exchangePathToCUSD;
        delete tokens[_tokenAddress].exchangePathToPACT;

        _tokenList.remove(_tokenAddress);

        emit TokenRemoved(_tokenAddress);
    }

    function getConvertedAmount(address _tokenAddress, uint256 _amount)
        external
        override
        returns (uint256)
    {
        require(isToken(_tokenAddress), "Treasury::getConvertedAmount: this is not a valid token");

        Token memory _token = tokens[_tokenAddress];

        uint256 _convertedAmount = _token.exchangePathToCUSD.length == 0
            ? _amount
            : lpSwap.uniswapQuoter().quoteExactInput(_token.exchangePathToCUSD, _amount);

        return (_convertedAmount * _token.rate) / 1e18;
    }

    function convertAmount(
        address _tokenAddress,
        uint256 _amountIn,
        uint256 _amountOutMin,
        bytes memory _exchangePath
    ) external override onlyOwnerOrImpactMarketCouncil {
        require(
            _tokenList.contains(_tokenAddress),
            "Treasury::convertAmount: this is not a valid token"
        );

        if (_exchangePath.length == 0) {
            _exchangePath = tokens[_tokenAddress].exchangePathToCUSD;
        }

        IERC20(_tokenAddress).approve(address(lpSwap.uniswapRouter()), _amountIn);

        // Executes the swap.
        uint256 _amountOut = lpSwap.uniswapRouter().exactInput(
            IUniswapRouter02.ExactInputParams({
                path: _exchangePath,
                recipient: address(this),
                amountIn: _amountIn,
                amountOutMinimum: _amountOutMin
            })
        );

        emit AmountConverted(_tokenAddress, _amountIn, _amountOutMin, _exchangePath, _amountOut);
    }

//    /**
//     * @notice Transfers an amount of an ERC20 from the sender to this contract
//     *
//     * @param _erc20Token address of the ERC20 token
//     * @param _amount amount of the transaction
//     */
//    function transferToTreasury(IERC20 _erc20Token, uint256 _amount)
//        external
//        override
//        nonReentrant
//    {
//        _erc20Token.safeTransferFrom(msg.sender, address(this), _amount);
//
//        Token storage _token = tokens[address(_erc20Token)];
//
//        uint256 _tokenAmountToUseInLp;
//
//        if (_token.lpStrategy == LpStrategy.MainCoin) {
//            _tokenAmountToUseInLp = _amount / 10;
//        } else if (_token.lpStrategy == LpStrategy.SecondaryCoin) {
//            _tokenAmountToUseInLp = _amount;
//        }
//
//        if (_tokenAmountToUseInLp > 0) {
//            _erc20Token.approve(address(lpSwap), _tokenAmountToUseInLp);
//            lpSwap.addToLp(_erc20Token, _tokenAmountToUseInLp);
//        }
//    }

    function useFundsForLP() external override onlyOwnerOrImpactMarketCouncilOrDonationMiner {
        uint256 _tokenLength = _tokenList.length();

        Token memory _token;

        for (uint256 _index; _index < _tokenLength; _index++) {
            _token = tokens[_tokenList.at(_index)];
            if (_token.lpPercentage > 0) {
                IERC20 _erc20Token = IERC20(_tokenList.at(_index));
                uint256 _balance = _erc20Token.balanceOf(address(this));

                if (_balance > _token.lpMinLimit) {
                    uint256 _tokenAmountToUseInLp = _balance * _token.lpPercentage / 100e18;
                    _erc20Token.approve(address(lpSwap), _tokenAmountToUseInLp);
                    lpSwap.addToLp(_erc20Token, _tokenAmountToUseInLp);
                }
            }
        }
    }

    function collectFees(uint256 _uniswapNFTPositionManagerId)
        external
        override
        onlyOwnerOrImpactMarketCouncil
    {
        (, , address _token0Address, address _token1Address, , , , , , , , ) = lpSwap
            .uniswapNFTPositionManager()
            .positions(_uniswapNFTPositionManagerId);

        require(
            _token0Address == address(PACT) || _token1Address == address(PACT),
            "Treasury::collectFees invalid uniswapNFTPositionManagerId"
        );

        (uint256 _amount0, uint256 _amount1) = lpSwap.collectFees(_uniswapNFTPositionManagerId);

        IERC20 _erc20Token;
        uint256 _pactAmount;
        uint256 _tokenAmount;

        if (_token0Address == address(PACT)) {
            _erc20Token = IERC20(_token1Address);
            _pactAmount = _amount0;
            _tokenAmount = _amount1;
        } else {
            _erc20Token = IERC20(_token0Address);
            _pactAmount = _amount1;
            _tokenAmount = _amount0;
        }

        Token memory _token = tokens[address(_erc20Token)];

        uint256 _pactToBurn;
        if (_token.lpStrategy == LpStrategy.SecondaryCoin) {
            _erc20Token.approve(address(lpSwap.uniswapRouter()), _tokenAmount);

            lpSwap.uniswapRouter().exactInput(
                IUniswapRouter02.ExactInputParams({
                    path: _token.exchangePathToCUSD,
                    recipient: address(this),
                    amountIn: _tokenAmount / 2,
                    amountOutMinimum: 0
                })
            );

            _pactToBurn = lpSwap.uniswapRouter().exactInput(
                IUniswapRouter02.ExactInputParams({
                    path: _token.exchangePathToPACT,
                    recipient: address(this),
                    amountIn: _tokenAmount / 2,
                    amountOutMinimum: 0
                })
            );
        }

        _pactToBurn += _pactAmount;

        PACT.transfer(DEAD_ADDRESS, _pactToBurn);
    }
}
