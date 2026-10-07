import 'package:flutter/foundation.dart';

/// Vietnamese bank catalogue for payout accounts. Mirrors `VN_BANKS` in
/// `packages/domain/src/vn_banks.ts` (a sync test keeps them equal).
@immutable
class VnBank {
  const VnBank({
    required this.code,
    required this.bin,
    required this.shortName,
    required this.name,
  });
  final String code;
  final String bin;
  final String shortName;
  final String name;
}

const List<VnBank> vnBanks = [
  VnBank(
    code: 'VCB',
    bin: '970436',
    shortName: 'Vietcombank',
    name: 'Ngân hàng TMCP Ngoại thương Việt Nam',
  ),
  VnBank(
    code: 'ICB',
    bin: '970415',
    shortName: 'VietinBank',
    name: 'Ngân hàng TMCP Công thương Việt Nam',
  ),
  VnBank(
    code: 'BIDV',
    bin: '970418',
    shortName: 'BIDV',
    name: 'Ngân hàng TMCP Đầu tư và Phát triển Việt Nam',
  ),
  VnBank(
    code: 'VBA',
    bin: '970405',
    shortName: 'Agribank',
    name: 'Ngân hàng Nông nghiệp và Phát triển Nông thôn Việt Nam',
  ),
  VnBank(
    code: 'TCB',
    bin: '970407',
    shortName: 'Techcombank',
    name: 'Ngân hàng TMCP Kỹ thương Việt Nam',
  ),
  VnBank(
    code: 'MB',
    bin: '970422',
    shortName: 'MBBank',
    name: 'Ngân hàng TMCP Quân đội',
  ),
  VnBank(
    code: 'ACB',
    bin: '970416',
    shortName: 'ACB',
    name: 'Ngân hàng TMCP Á Châu',
  ),
  VnBank(
    code: 'VPB',
    bin: '970432',
    shortName: 'VPBank',
    name: 'Ngân hàng TMCP Việt Nam Thịnh Vượng',
  ),
  VnBank(
    code: 'TPB',
    bin: '970423',
    shortName: 'TPBank',
    name: 'Ngân hàng TMCP Tiên Phong',
  ),
  VnBank(
    code: 'STB',
    bin: '970403',
    shortName: 'Sacombank',
    name: 'Ngân hàng TMCP Sài Gòn Thương Tín',
  ),
  VnBank(
    code: 'HDB',
    bin: '970437',
    shortName: 'HDBank',
    name: 'Ngân hàng TMCP Phát triển Thành phố Hồ Chí Minh',
  ),
  VnBank(
    code: 'VIB',
    bin: '970441',
    shortName: 'VIB',
    name: 'Ngân hàng TMCP Quốc tế Việt Nam',
  ),
  VnBank(
    code: 'SHB',
    bin: '970443',
    shortName: 'SHB',
    name: 'Ngân hàng TMCP Sài Gòn - Hà Nội',
  ),
  VnBank(
    code: 'MSB',
    bin: '970426',
    shortName: 'MSB',
    name: 'Ngân hàng TMCP Hàng Hải Việt Nam',
  ),
  VnBank(
    code: 'OCB',
    bin: '970448',
    shortName: 'OCB',
    name: 'Ngân hàng TMCP Phương Đông',
  ),
  VnBank(
    code: 'SEAB',
    bin: '970440',
    shortName: 'SeABank',
    name: 'Ngân hàng TMCP Đông Nam Á',
  ),
  VnBank(
    code: 'EIB',
    bin: '970431',
    shortName: 'Eximbank',
    name: 'Ngân hàng TMCP Xuất Nhập khẩu Việt Nam',
  ),
  VnBank(
    code: 'LPB',
    bin: '970449',
    shortName: 'LPBank',
    name: 'Ngân hàng TMCP Lộc Phát Việt Nam',
  ),
  VnBank(
    code: 'NAB',
    bin: '970428',
    shortName: 'Nam A Bank',
    name: 'Ngân hàng TMCP Nam Á',
  ),
  VnBank(
    code: 'SCB',
    bin: '970429',
    shortName: 'SCB',
    name: 'Ngân hàng TMCP Sài Gòn',
  ),
];

/// The bank with this exact code, or null.
VnBank? bankByCode(String code) {
  for (final b in vnBanks) {
    if (b.code == code) return b;
  }
  return null;
}
