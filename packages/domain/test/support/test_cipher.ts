import type { AccountCipher } from '../../src/payout_ports.js';

export const TEST_CIPHER: AccountCipher = {
  async encrypt(plain: string): Promise<string> {
    return 'enc:' + plain.split('').reverse().join('');
  },
  async decrypt(enc: string): Promise<string> {
    if (!enc.startsWith('enc:')) throw new Error('invalid_ciphertext');
    return enc.slice(4).split('').reverse().join('');
  },
};
