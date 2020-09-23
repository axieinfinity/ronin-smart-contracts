import { Web3Pool } from '@axie/web3-pool';
import { isNil } from 'lodash';

const privateKeys = [];
const AlicePK = process.env.PK;
const BobPK = process.env.PK_BOB;
const CharliesPK = process.env.PK_CHARLIES;
const EzrealPK = process.env.PK_EZREAL;

if (!isNil(AlicePK)) {
  privateKeys.push(AlicePK);
}

if (!isNil(BobPK)) {
  privateKeys.push(BobPK);
}

if (!isNil(CharliesPK)) {
  privateKeys.push(CharliesPK);
}

if (!isNil(EzrealPK)) {
  privateKeys.push(EzrealPK);
}

const URIs = [];
const uri = process.env.SIDECHAIN_URI;
if (!isNil(uri)) {
  URIs.push(uri);
}

export const web3Pool = Web3Pool.fromUris(
  'ethereum',
  URIs, {
  privateKeys,
});
