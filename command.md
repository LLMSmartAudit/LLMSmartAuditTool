python -m venv myenv   

# 进入python Environment
source myenv/bin/activate

# Environment
pip freeze > requirements.txt

# Requirements File
pip install -r requirements.txt

# How to Deactivate a Virtual Environment
deactivate

# How to use Streamlit
streamlit run app.py

# How to use FastApi
uvicorn app:app --host 0.0.0.0 --port 10000

conda activate ChatDev_conda_env
cd /Users/weizhiyuan/Documents/code/SC_ChatDev/SC_ChatDev


OPENAI_API_KEY=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
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
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

GPT4
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
export OPENAI_API_KEY="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"


export OPENAI_API_KEY="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"
export OPENAI_API_KEY="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"
export OPENAI_API_KEY="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"
export OPENAI_API_KEY="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"
export OPENAI_API_KEY="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"
export OPENAI_API_KEY="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"
export OPENAI_API_KEY="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"

setopt NO_NOMATCH


python3 run.py --task "classic snake game" --name "snake"
python run.py --config "Metaxyz" --task "Drive more people to subscribe to my newsletter called AI Far where i share how to build AI products" --name "AIFarNewsletter"


python3 run.py --org "AIFar" --config "SmartContract" --task "pragma solidity ^0.4.0; contract IntegerOverflowAdd { mapping (address => uint256) public balanceOf; function transfer(address _to, uint256 _value) public{ require(balanceOf[msg.sender] >= _value); balanceOf[msg.sender] -= _value; balanceOf[_to] += _value; }}" --name "AISmartContract"


python3 run.py --org 'AIFar' --config 'SmartContract' --task '###pragma solidity ^0.4.0;contract TimeLock {mapping(address => uint) public balances;mapping(address => uint) public lockTime;function deposit() public payable {balances[msg.sender] += msg.value;lockTime[msg.sender] = now + 1 weeks;}function increaseLockTime(uint _secondsToIncrease) public {lockTime[msg.sender] += _secondsToIncrease;}function withdraw() public {require(balances[msg.sender] > 0);require(now > lockTime[msg.sender]);uint transferValue = balances[msg.sender];balances[msg.sender] = 0;msg.sender.transfer(transferValue);}}###' --name 'AISmartContract'


python3 run.py --org 'AIFarTest' --config 'TestSmartContract' --task '######' --name 'AISmartContractShots'


python3 run.py --org "AIFar" --config "SmartContract" --task "pragma solidity ^0.7.0;contract Delegate {address public owner;constructor(address _owner) public {owner = _owner;}function pwn() public {owner = msg.sender;}}contract Delegation {address public owner;Delegate delegate;constructor(address _delegateAddress) public {delegate = Delegate(_delegateAddress);owner = msg.sender;}fallback() external {(bool result,) = address(delegate).delegatecall(msg.data);if (result) {this;}}}" --name "4_FarSC" --model GPT_4_TURBO

## Broad Analysis mode
python run.py --org "AIFar" --config "SmartContract" --task "$(cat ./proc_label/proc_safecontract/balancer.sol)" --name "3_FarSC_BA"

python run.py --org "AIFar" --config "SmartContract" --task "$(cat ./3_MarginRouter.sol)" --name "4_FarSC" --model GPT_4_TURBO

python run.py --org "AIFar" --config "SmartContract" --task "$(cat 3_MarginRouter.sol)" --name "4_FarSC" --model GPT_4_TURBO


## Target Analysis mode
python run.py --org "AIFar" --config "SmartContractTA" --task '''''' --name "4_FarSC" --model GPT_4_TURBO

python run.py --org "AIFar" --config "SmartContractTA" --task "$(cat ./proc_code3rena/5_Pools.sol)" --name "4_FarSC_TA" --model GPT_4_TURBO