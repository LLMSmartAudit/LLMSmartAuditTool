# LLMSmartAuditTool

LLMSmartAudit is a tool designed to audit smart contracts using advanced language models.

The benchmark for our tool can be found [here](https://github.com/LLMSmartAudit/SmartContract-benchmark).

<img src='framework.png' height=400>


## 1. Install Environment
pip install -r requirements.txt

## 2. set your openai key
export OPENAI_API_KEY="sky-{}"

## 3. How to use tool
Input your solidity smart contract code into `task`

###  Run BA mode
```python
python3 run.py --org "" --config "SmartContractBA" --task "" --name ""
```

### Run TA mode
```python
python3 run.py --org "" --config "SmartContractTA" --task "" --name ""
```

### Show Results
```python
python3 online_log/app.py
```
open local web http://127.0.0.1:8000/

## 4. Display 
### Chatchain
<img src='chatchain.png' height=400>

### Chatchain
<img src='logvisual.png' height=400>

### Muti-conversions between LLM-based Agents
<img src='AuditExample.png' height=400>

<img src='AuditExample1.png' height=400>
