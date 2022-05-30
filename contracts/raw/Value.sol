// Adapted from https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol

interface IERC20 {
    function totalSupply() external view returns (uint256 ts);
    function getBalanceOf(address account) external view returns (uint256 bal);
    function doTransfer(address recipient, uint256 amount) external returns (bool success);
    function allowance(address owner, address spender) external view returns (uint256 allowed);
    function approve(address spender, uint256 amount) external returns (bool approved);
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool success);
}

/* Adapted from https://github.com/dapphub/ds-token/blob/master/src/token.sol,
 * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol
 */

contract Token {
    mapping (address => uint) public  balanceOf;
    mapping (address => mapping (address => uint))  public  allowance;
    uint totalSupply;

    function getBalanceOf(address usr) external returns (uint balance) {
        return balanceOf[usr];
    }

    function getTotalSupply() public view returns (uint tS) {
        return totalSupply;
    }

    function approve(address guy, uint wad) public returns (bool appr) {
        allowance[msg.sender][guy] = wad;
        return true;
    }

    function doTransfer(address dst, uint wad) public returns (bool success) {
        success = transferFrom(msg.sender, dst, wad);
        return success;
    }

    function transferFrom(address src, address dst, uint wad)
        public
        returns (bool success)
    {
        require(balanceOf[src] >= wad);

        if (src != msg.sender && allowance[src][msg.sender] != 9999999999) {
            require(allowance[src][msg.sender] >= wad);
            allowance[src][msg.sender] -= wad;
        }

        balanceOf[src] -= wad;
        balanceOf[dst] += wad;

        return true;
    }
}

/* Adapted from https://bscscan.com/address/0x7a8ac384d3a9086afcc13eb58e90916f17affc89#code
 * Vulnerable_at_lines: 149 or 158
 */

contract Value {
    uint256 public constant BLOCKS_PER_DAY = 28800;

    // governance
    address public operator;
    address public reserveFund;

    // flags
    bool public initialized = false;
    bool public publicAllowed = false;

    // address public exchangeProxy;
    uint256 private _locked = 0;

    // Info of each user.
    struct UserInfo {
        uint256 amount;
        mapping(address => uint256) rewardDebt;
        mapping(address => uint256) reward;
        mapping(address => uint256) accumulatedEarned; // will accumulate every time user harvest
        mapping(address => uint256) lockReward;
        mapping(address => uint256) lockRewardReleased;
        uint256 lastStakeTime;
    }

    // Info of each rewardPool funding.
    struct RewardPoolInfo {
        address rewardToken; // Address of rewardPool token contract.
        uint256 lastRewardBlock; // Last block number that rewardPool distribution occurs.
        uint256 rewardPerBlock; // Reward token amount to distribute per block.
        uint256 accRewardPerShare; // Accumulated rewardPool per share, times 1e18.
        uint256 totalPaidRewards;
    }

    uint256 public startRewardBlock;
    uint256 public endRewardBlock;

    address public wbnb;
    address public busd;
    address public stakeToken;

    mapping(address => RewardPoolInfo) public rewardPoolInfo;

    // Info of each user that stakes LP tokens.
    mapping(address => UserInfo) public userInfo;

    /* ========== Modifiers =============== */

    modifier onlyOperator() {
        require(operator == msg.sender, "ProfitSharingRewardPool: caller is not the operator");
        _;
    }

    modifier onlyReserveFund() {
        require(reserveFund == msg.sender || operator == msg.sender, "ProfitSharingRewardPool: caller is not the reserveFund");
        _;
    }

    modifier lock() {
        require(_locked == 0, "ProfitSharingRewardPool: LOCKED");
        _locked = 1;
        _;
        _locked = 0;
    }

    modifier notInitialized() {
        require(!initialized, "ProfitSharingRewardPool: initialized");
        _;
    }

    modifier checkPublicAllow() {
        require(publicAllowed || msg.sender == operator, "!operator nor !publicAllowed");
        _;
    }

    /* ========== GOVERNANCE ========== */

    function initialize(
        address _stakeToken,
        address _wbnb,
        address _busd,
        address _reserveFund,
        uint256 _startRewardBlock
    ) public notInitialized {
        stakeToken = _stakeToken;
        wbnb = _wbnb;
        busd = _busd;
        reserveFund = _reserveFund;
        startRewardBlock = _startRewardBlock;
        endRewardBlock = _startRewardBlock;

        operator = msg.sender;
        _locked = 0;
    }

    function setOperator(address _operator) external onlyOperator {
        operator = _operator;
    }

    function getStakeToken() external returns (address _token) {
        return stakeToken;
    }

    function setReserveFund(address _reserveFund) external onlyReserveFund {
        reserveFund = _reserveFund;
    }

    // Deposit LP tokens
    function _deposit(address _account, uint256 _amount) internal lock {
        UserInfo storage user = userInfo[_account];
        user.amount = user.amount + _amount;
    }

    function deposit(uint256 _amount) external {
        Token(stakeToken).transferFrom(msg.sender, address(this), _amount);
        _deposit(msg.sender, _amount);
    }

    function depositFor(address _account, uint256 _amount) external {
        Token(stakeToken).transferFrom(msg.sender, address(this), _amount);
        _deposit(_account, _amount);
    }

    // Withdraw LP tokens.
    function _withdraw(address _account, uint256 _amount) internal lock {
        UserInfo storage user = userInfo[_account];
        // getAllRewards(_account);
        if (_amount > 0) {
            user.amount = user.amount - _amount;
            Token staked;
            staked = Token(stakeToken);
            staked.doTransfer(_account, _amount);
        }
    }

    function withdraw(uint256 _amount) external {
        _withdraw(msg.sender, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint _amount) external lock {
        UserInfo storage user = userInfo[msg.sender];
        uint256 _amount = user.amount;
        user.amount = 0;
        user.rewardDebt[wbnb] = 0;
        user.rewardDebt[busd] = 0;
        user.reward[wbnb] = 0;
        user.reward[busd] = 0;
        Token(stakeToken).doTransfer(msg.sender, _amount);
    }

    function _safeTokenTransfer(
        address _token,
        address _to,
        uint256 _amount
    ) internal {
        uint256 _tokenBal;
        _tokenBal = Token(_token).getBalanceOf(address(this));
        if (_amount > _tokenBal) {
            _amount = _tokenBal;
        }
        if (_amount > 0) {
            Token(_token).doTransfer(_to, _amount);
        }
    }

    // This function allows governance to take unsupported tokens out of the contract. This is in an effort to make someone whole, should they seriously mess up.
    // There is no guarantee governance will vote to return these. It also allows for removal of airdropped tokens.
    function governanceRecoverUnsupported(
        address _token,
        uint256 amount,
        address to
    ) external onlyOperator() {
        require(_token != stakeToken, "stakeToken");
        Token(_token).doTransfer(to, amount);
    }
}