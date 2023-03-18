import time
from web3 import Web3
from web3.middleware import geth_poa_middleware
from config import provider_url, private_key, contract_address, contract_abi

w3 = Web3(Web3.HTTPProvider(provider_url))
w3.middleware_onion.inject(geth_poa_middleware, layer=0)
account = w3.eth.account.privateKeyToAccount(private_key)

contract = w3.eth.contract(address=Web3.toChecksumAddress(contract_address), abi=contract_abi)

def generate_random_number():
    import random
    return random.randint(0, 100)

def determine_token_id(random_number):
    # minting odds are determined here
    probabilities = [69, 15, 10, 5, 1]
    current_sum = 0

    for i, probability in enumerate(probabilities):
        current_sum += probability
        if random_number < current_sum:
            return i + 1
    return 1

def handle_mint_request(event):
    user = event["args"]["user"]
    nonce = event["args"]["nonce"]
    token_id = determine_token_id(generate_random_number())

    txn = contract.functions.mint(user, token_id, 1, nonce, b"").buildTransaction({
        "from": account.address,
        "gas": 200000,
        "gasPrice": w3.eth.gasPrice,
        "nonce": w3.eth.getTransactionCount(account.address),
    })
    signed_txn = w3.eth.account.signTransaction(txn, private_key)
    txn_hash = w3.eth.sendRawTransaction(signed_txn.rawTransaction)
    txn_receipt = w3.eth.waitForTransactionReceipt(txn_hash)

def process_missed_events():
    last_processed_nonce = contract.functions.lastProcessedNonce().call()
    missed_events = contract.events.MintRequest.createFilter(
        fromBlock=0, argument_filters={"nonce": last_processed_nonce + 1}
    ).get_all_entries()

    for event in missed_events:
        handle_mint_request(event)

def main():
    while True:
        try:
            process_missed_events()
            event_filter = contract.events.MintRequest.createFilter(fromBlock="latest")
            while True:
                events = event_filter.get_new_entries()
                for event in events:
                    handle_mint_request(event)
                time.sleep(5)
        except Exception as e:
            print(f"Error occurred: {e}")
            time.sleep(10)

if __name__ == "__main__":
    main()