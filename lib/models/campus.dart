enum Campus {
  imadegawa('今出川'),
  kyotanabe('京田辺'),
  both('両キャンパス');

  final String label;
  const Campus(this.label);

  factory Campus.fromString(String name) {
    return Campus.values.firstWhere(
      (c) => c.name == name,
      orElse: () => Campus.both,
    );
  }
}
