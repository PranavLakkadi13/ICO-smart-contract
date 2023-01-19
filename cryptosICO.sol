// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// the ERC20 standards Interface to be followed ----->
interface ERC20Standard{
    // function name() external view returns (string memory);
    // function symbol() external view returns (string memory);
    // function decimals() external view returns (uint8);
    
    // this 3 functions are the mandatory functions to be implemented 
    function totalSupply() external view returns(uint);
    function balanceOf(address tokenowner) external view returns(uint);
    function transfer(address to, uint256 tokens) external returns(bool);

    // this next 3 functions are used as creditor
    // where eg account A gives permission to account B permission to spend money of account A upto a limit
    // very similar to the credit card -->
    function transferFrom(address from, address to, uint256 tokens) external returns (bool);
    function approve(address spender, uint256 tokens) external returns (bool);
    function allowance(address tokenowner, address spender) external view returns (uint);

    event Transfer(address indexed from, address indexed to, uint256 tokens);
    event Approval(address indexed tokenowner, address indexed spender, uint256 tokens);

}

//  MY ERC20 contract starts here --->
contract Cryptos is ERC20Standard {
    // since we created the public variable we by default created the above mentioned functions
    string public name = "cryptos"; 
    string public symbol = "CRPT";
    uint public decimals = 0;

    uint public override totalSupply;

    address public founder;
    mapping(address => uint) public balances;

    mapping(address => mapping(address => uint)) allowed;
    // 0x12111... (owner) allows 0x1111223.. (spender) --> 1000 tokens;
    // allowed[0x12111...][0x11111123..] = 1000 tokens;

    constructor() {
        totalSupply = 1000000;
        founder = msg.sender;
        balances[founder] = totalSupply;
    }

    function balanceOf(address tokenowner) public view override returns(uint){
        return balances[tokenowner];
    }

    function transfer(address to, uint256 tokens) public virtual override returns(bool){
        require(balances[msg.sender] >= tokens, "ERROR: low on balance");

        balances[to] += tokens;
        balances[msg.sender] -= tokens;

        emit Transfer(msg.sender, to, tokens);
        return true;
    }

    // the allowance function is like a getter function for the allowed mapping
    function allowance(address tokenowner, address spender) public view override returns(uint){
        return allowed[tokenowner][spender];
    }

    function approve(address spender, uint256 tokens) public override returns(bool){
        require(balances[msg.sender] >= tokens, "Error: low on balance");
        require(tokens > 0);

        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender,spender,tokens);
        
        return true;
    }

    function transferFrom(address from, address to, uint256 tokens) public virtual override returns(bool){
        require(allowed[from][msg.sender] >= tokens);
        require(balances[from] >= tokens);
        
        balances[from] -= tokens;
        allowed[from][msg.sender] -= tokens;
        balances[to] += tokens;

        emit Transfer(from, to, tokens);
        return true;
    }
}

// ICO contract starts here ----->
contract CryptosICO is Cryptos {
    address public admin;
    address payable public deposit;
    uint public tokenprice = 0.001 ether; // 1ether = 1000 CRPT or 1 CRPT for 0.001 ether
    uint public hardcap = 300 ether; // max ether the contract can receive
    uint public raised_amount;
    // here block.timestamp refers to the time in SECONDS in unix epoch 
    uint public sale_start = block.timestamp;
    uint public sale_end = block.timestamp + 604800; // ico end in a week 
    uint public trade_start = sale_end + 604800; // the tokens can be transfered/traded after a week of the ico
    uint public max_investment = 5 ether;
    uint public min_investment = 0.1 ether;

    enum State {BeforeStart, Running, AfterEnd, Halted}
    State public icoState;

    constructor(address payable _deposit){
        admin = msg.sender;
        icoState = State.BeforeStart;
        deposit = _deposit;
    }

    modifier OnlyAdmin() {
        require(msg.sender == admin, "Error you are not the admin");
        _;
    }

    function halt() public OnlyAdmin {
        icoState = State.Halted;
    }

    function reusume() public OnlyAdmin {
        icoState = State.Running;
    }

    function change_Deposit_Address(address payable newdeposit) public OnlyAdmin {
        deposit = newdeposit;
    }

    function get_currrent_state() public view returns(State){
        if (icoState == State.Halted){
            return State.Halted;
        }
        else if(block.timestamp < sale_start){
            return State.BeforeStart;
        }
        else if(block.timestamp >= sale_start && block.timestamp <= sale_end){
            return State.Running;
        }
        else{
            return State.AfterEnd;
        }
    }

    event Invest(address investor, uint value_invested, uint tokens_received);

    function invest() payable public returns(bool){
        icoState = get_currrent_state();
        require(icoState == State.Running, "Error: ico is not currently running");

        require(msg.value >= min_investment && msg.value <= max_investment, "Error: value sent either to high or low");
        raised_amount += msg.value;
        require(raised_amount <= hardcap, "Error: Raised amount reached hardcap NO MORE INVESTMENTS ACCEPTED");

        uint tokens = msg.value / tokenprice;

        balances[msg.sender] += tokens;
        balances[founder] -= tokens;

        deposit.transfer(msg.value);

        emit Invest(msg.sender,msg.value,tokens);

        return true;
    }

    receive() payable external {
        invest();
    }

    function transfer(address to, uint256 tokens) public override returns(bool) {
        require(block.timestamp > trade_start,"Error: tokens non-transferable as they are locked up");
        // the super keyword is used when using a feature of the parent contract in a inherited contract
        // Cryptos.transfer(to,tokens); // this is another way to write super
        // so this function makes sure that only after the require statement is true 
        // we can implement the inherited transfer function 
        super.transfer(to,tokens); 

        return true;
    }

    function transferFrom(address from, address to, uint256 tokens) public override returns(bool) {
        require(block.timestamp > trade_start,"Error: tokens non-transferable as they are locked up");
        // it is similar to the transfer process ----->
        super.transferFrom(from,to,tokens);
        
        return true;
    }

    function burn() public returns(bool) {
        icoState = get_currrent_state();
        require(icoState == State.AfterEnd, "Error: you cant burn tokens before the end of the ico");
        balances[founder] = 0;

        return true;
    }
}
