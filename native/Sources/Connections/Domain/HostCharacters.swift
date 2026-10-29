func validHostCharacters(_ value: String) -> Bool {
  value.utf8.allSatisfy { byte in
    (65...90).contains(byte) || (97...122).contains(byte) || (48...57).contains(byte)
      || [45, 46, 58, 95].contains(byte)
  }
}
