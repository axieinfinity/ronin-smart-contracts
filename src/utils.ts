import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumberish } from "ethers";
import { arrayify } from "ethers/lib/utils";
import { ethers } from "hardhat";

export const ethToWei = (eth: number) => ethers.utils.parseEther(eth.toString());

export const withdrawalERC20Hash = (withdrawalId: number, user: string, token: string, amount: BigNumberish) =>
  ethers.utils.solidityKeccak256(
    ['string', 'uint256', 'address', 'address', 'uint256'],
    ['withdrawERC20', withdrawalId, user, token, amount]
  );

export const withdrawalERC721Hash = (withdrawalId: number, user: string, token: string, id: BigNumberish) =>
  ethers.utils.solidityKeccak256(
    ['string', 'uint256', 'address', 'address', 'uint256'],
    ['withdrawERC721', withdrawalId, user, token, id]
  );


const sign = async (signer: SignerWithAddress, data: string): Promise<string> => {
  // Ganache return the signatures directly
  const signatures = await signer.signMessage(arrayify(data));
  return `01${signatures.slice(2)}`;
};

export const getCombinedSignatures = async (
  reversed: boolean,
  accounts: SignerWithAddress[],
  data: string
): Promise<{ accounts: string[]; signatures: string }> => {
  const sortedAccounts = accounts.sort((a, b) => a.address.toLowerCase().localeCompare(b.address.toLowerCase()));

  let signatures = '';
  for (const account of sortedAccounts) {
    const signature = await sign(account, data);
    if (reversed) {
      signatures = signature + signatures;
    } else {
      signatures += signature;
    }
  }

  signatures = '0x' + signatures;

  return {
    accounts: sortedAccounts.map((account) => account.address.toLowerCase()),
    signatures,
  };
};
