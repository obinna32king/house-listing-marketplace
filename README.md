# Sui Move Marketplace DApp

This repository contains the source code for a decentralized marketplace application (dApp) built on the Sui blockchain. The dApp allows users to list and purchase items using the SUI native token.

## Features:

- Sellers can list any type of item.
- Marketplace accepts payment in SUI tokens.
- Buyers can purchase listed items.

## Set up your development environment:

Install the Sui CLI: https://docs.sui.io/guides/developer/getting-started/sui-install
Create a Gitpod workspace or use an existing cloud environment.

Clone this repository:

```Bash
git clone https://github.com/icis-04/dacademarket.git
```
Use code with caution.
Navigate to the project directory:
```Bash
cd dacademarket
```
Use code with caution.

## To deploy the smart contracts:


Create a Sui devnet account and fund it with SUI tokens:

```bash
 sui client
```

Fund the account:
```bash
curl --location --request POST 'https://faucet.devnet.sui.io/gas' \
--header 'Content-Type: application/json' \
--data-raw '{
  "FixedAmountRequest": {
    "recipient": "<your account address>"
  }
}'
```


Publish the package to the devnet:

```Bash
sui client publish --gas-budget 100000000 --skip-dependency-verification
```

* **Copy the package ID from the output.**
* **Export the package ID as an environment variable:**
```Bash
export PACKAGE_ID=<YOUR_PACKAGE_ID>
```

* **Initialize the marketplace:**
```Bash
sui client call --function create --module marketplace --package $PACKAGE_ID --type-args 0x2::sui::SUI --gas-budget 100000000
```

Save the PackageID and the MarketplaceID for use in the frontend

Additional Notes:

This is a basic example of a marketplace dApp. You can extend it to add more features, such as user authentication, reviews, and escrow.
For more information on Sui Move development, please refer to the Sui documentation: https://docs.sui.io/guides/developer/sui-101


# For the frontend


## Sui Marketplace dApp

This README contains comprehensive instructions and explanations for building a functional marketplace dApp on the Sui blockchain, leveraging the Sui SDK and Sui dApp Kit.

## Prerequisites:

- Node.js (version 18 or above recommended)
- Sui Wallet extension installed in your browser
- Basic understanding of JavaScript, React, and Move
### Getting Started:

Clone the Repository:

```Bash
cd marketplace-frontend
```

Install Dependencies:

```Bash
npm install
```

Start the React Server:
```Bash
npm start
```

Put in your PackageID and MarketplaceID gotten from deploying the marketplace
