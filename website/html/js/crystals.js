// Create the contract instance
// Replace ABI and season number (maybe load from dropdown?)
const seasonnft = new web3.eth.Contract(season0_abi, season0_addr);

// Request mint with crystals
async function requestMintWithCrystals(amount) {
  const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
  const account = accounts[0];
  await seasonnft.methods.requestMintCrystals(amount).send({ from: account });
}

// Add event listener for mint with crystals
const mintWithCrystalsButton = document.getElementById('mint-with-crystals-button');
mintWithCrystalsButton.addEventListener('click', async () => {
  const amount = 1; // Replace with the desired amount
  await requestMintWithCrystals(amount);
});

// Listen for MintProcessed events
seasonnft.events.MintProcessed({}, (error, event) => {
  if (error) {
    console.error('Error in event:', error);
  } else {
    const { user, tokenIds, nonce } = event.returnValues;
    console.log(`Mint processed for user ${user} with tokenIds ${tokenIds} and nonce ${nonce}`);
    // Update the UI based on the new tokens
  }
});
