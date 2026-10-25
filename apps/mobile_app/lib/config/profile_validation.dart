bool isValidBodyMetric(String value) {
  final number = double.tryParse(value.trim());
  return number != null && number.isFinite && number > 0;
}
