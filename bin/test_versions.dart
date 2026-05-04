void main() {
  int compareVersions(String v1, String v2) {
    try {
      String cleanV1 = v1.split('+')[0].split('-')[0].trim();
      String cleanV2 = v2.split('+')[0].split('-')[0].trim();

      List<int> v1Parts = cleanV1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      List<int> v2Parts = cleanV2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < 3; i++) {
        int p1 = i < v1Parts.length ? v1Parts[i] : 0;
        int p2 = i < v2Parts.length ? v2Parts[i] : 0;
        if (p1 < p2) return -1;
        if (p1 > p2) return 1;
      }
      return 0;
    } catch (e) {
      print('Version compare error: $e');
      return 0;
    }
  }

  print('1.0.0 vs 1.1.0: \${compareVersions("1.0.0", "1.1.0")}');
  print('1.0.0+1 vs 1.1.0: \${compareVersions("1.0.0+1", "1.1.0")}');
  print('1.1.0 vs 1.0.0: \${compareVersions("1.1.0", "1.0.0")}');
}
