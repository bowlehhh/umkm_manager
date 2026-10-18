enum PhoneVerificationPurpose { registration, passwordRecovery }

class PhoneVerificationArguments {
  const PhoneVerificationArguments({
    required this.phone,
    required this.purpose,
    this.contactEmail,
  });

  final String phone;
  final PhoneVerificationPurpose purpose;
  final String? contactEmail;
}
