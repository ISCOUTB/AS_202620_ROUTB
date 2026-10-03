/// Iniciales que se pintan en un avatar cuando no hay foto de perfil.
///
/// Si el nombre está vacío devuelve `?` para que el avatar nunca quede vacío.
String initialsOf(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) {
    final word = words.first;
    return word.substring(0, word.length >= 2 ? 2 : 1).toUpperCase();
  }
  return '${words.first[0]}${words.last[0]}'.toUpperCase();
}