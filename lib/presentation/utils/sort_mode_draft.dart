List<T> moveDraftItem<T>({
  required List<T> items,
  required int fromIndex,
  required int toIndex,
}) {
  if (fromIndex < 0 ||
      fromIndex >= items.length ||
      toIndex < 0 ||
      toIndex >= items.length ||
      fromIndex == toIndex) {
    return List<T>.unmodifiable(items);
  }

  final List<T> nextItems = List<T>.from(items);
  final T movedItem = nextItems.removeAt(fromIndex);
  nextItems.insert(toIndex, movedItem);
  return List<T>.unmodifiable(nextItems);
}

List<T> moveDraftItemUp<T>(List<T> items, int index) {
  return moveDraftItem(items: items, fromIndex: index, toIndex: index - 1);
}

List<T> moveDraftItemDown<T>(List<T> items, int index) {
  return moveDraftItem(items: items, fromIndex: index, toIndex: index + 1);
}

List<T> moveDraftItemToTop<T>(List<T> items, int index) {
  return moveDraftItem(items: items, fromIndex: index, toIndex: 0);
}

List<T> moveDraftItemToBottom<T>(List<T> items, int index) {
  return moveDraftItem(
    items: items,
    fromIndex: index,
    toIndex: items.length - 1,
  );
}

bool idsInSameOrder<T>(
  List<T> left,
  List<T> right, {
  required int Function(T item) idOf,
}) {
  if (left.length != right.length) {
    return false;
  }
  for (int index = 0; index < left.length; index += 1) {
    if (idOf(left[index]) != idOf(right[index])) {
      return false;
    }
  }
  return true;
}
