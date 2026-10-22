enum SplitType {
  equal,
  exact,
  percentage,
  shares;

  String get displayName {
    switch (this) {
      case SplitType.equal:
        return 'Split Equally';
      case SplitType.exact:
        return 'Exact Amounts';
      case SplitType.percentage:
        return 'Percentages (%)';
      case SplitType.shares:
        return 'By Shares';
    }
  }

  String get shortName {
    switch (this) {
      case SplitType.equal:
        return 'Equal';
      case SplitType.exact:
        return 'Exact';
      case SplitType.percentage:
        return 'Percent';
      case SplitType.shares:
        return 'Shares';
    }
  }
}
