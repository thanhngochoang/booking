import type {
  TaxCodeInfo,
  TaxCodeLookup,
} from './verification_ports.js';

export class FakeTaxCodeLookup implements TaxCodeLookup {
  async lookup(taxCode: string): Promise<TaxCodeInfo | null> {
    const clean = taxCode.trim();
    if (clean.endsWith('0000')) {
      return {
        name: `CÔNG TY TNHH STUDIO ${clean.slice(-4)}`,
        address: '12 Nguyễn Huệ, Phường Sài Gòn, TP. Hồ Chí Minh',
        status: 'inactive',
        kind: 'company',
      };
    }

    if (clean.length === 12) {
      return {
        name: 'HỘ KINH DOANH STUDIO THỬ',
        address: '12 Nguyễn Huệ, Phường Sài Gòn, TP. Hồ Chí Minh',
        status: 'active',
        kind: 'household',
      };
    }

    const last4 = clean.slice(-4);
    return {
      name: `CÔNG TY TNHH STUDIO THỬ ${last4}`,
      address: '12 Nguyễn Huệ, Phường Sài Gòn, TP. Hồ Chí Minh',
      status: 'active',
      kind: 'company',
    };
  }
}
