enum CardStyle {
  style1,
  style2,
}

CardStyle cardStyleFromString(String? value) {
  switch (value) {
    case 'style2':
      return CardStyle.style2;
    case 'style1':
    default:
      return CardStyle.style1;
  }
}
