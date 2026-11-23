-- Wrap tables in a scrolling div so wide tables work on phones.
function Table(el)
  return pandoc.Div({el}, pandoc.Attr("", {"table-wrap"}))
end
