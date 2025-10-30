enum NativeAccuracy {
  cellular(1),
  wifi(2),
  gps(3),
  navigation(4);

  final int value;
  const NativeAccuracy(this.value);
}
