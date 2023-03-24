"""
This script listens for new MintRequest events emitted by a smart contract and
handles them by minting a new token for the user who made the request. The ID of
the token to be minted is determined based on probabilities defined in the
determine_token_id and determine_token_id_crystal functions. If any events were
missed due to connection issues or downtime, the script processes them before
continuing to listen for new events.

Author: Isekai Dev
"""

import time
from web3 import Web3
from web3.middleware import geth_poa_middleware
from oracle_config import provider_url, private_key, contract_address, contract_abi

w3 = Web3(Web3.HTTPProvider(provider_url))
w3.middleware_onion.inject(geth_poa_middleware, layer=0)
account = w3.eth.account.privateKeyToAccount(private_key)

contract = w3.eth.contract(address=Web3.toChecksumAddress(contract_address), abi=contract_abi)

def generate_random_number():
    """Generates a random number between 0 and 10000."""
    import random
    return random.randint(0, 10000)

def determine_token_id(random_number):
    """
    Determines the ID of the token to be minted based on probabilities.

    Args:
        random_number (int): A random number between 0 and 10000.

    Returns:
        int: The ID of the token to be minted.
    """
    probabilities = [2300, 2300, 2300, 700, 700, 700, 300, 300, 300, 49, 49, 2]
    current_sum = 0

    for i, probability in enumerate(probabilities):
        current_sum += probability
        if random_number < current_sum:
            return i + 1
    return 1

def determine_token_id_crystal(random_number):
    """
    Determines the ID of the token to be minted based on probabilities.
    Probabilities reflect Crystals mint method, which are LP
    farm rewards.

    Args:
        random_number (int): A random number between 0 and 10000.

    Returns:
        int: The ID of the token to be minted.
    """
    # minting odds are determined here
    probabilities = [0, 0, 0, 2333, 2333, 2333, 833, 833, 833, 249, 249, 4]
    current_sum = 0

    for i, probability in enumerate(probabilities):
        current_sum += probability
        if random_number < current_sum:
            return i + 1
    return 1

def handle_mint_request(event):
    """
    Handles a MintRequest event by generating a random number to determine the
    token ID and sending a transaction to the smart contract to mint the token
    for the user.

    Args:
        event (dict): A dictionary containing information about the event.
    """
    user = event["args"]["user"]
    nonce = event["args"]["nonce"]
    token_id = determine_token_id(generate_random_number())

    txn = contract.functions.mint(user, token_id, nonce, b"").buildTransaction({
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