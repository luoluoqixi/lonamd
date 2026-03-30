/// Markdown AST node type IDs, mirroring @lezer/markdown's Type enum.
///
/// This defines all node types used in the Markdown syntax tree.
/// Block nodes represent structural elements, inline nodes represent
/// text-level formatting, and mark/token nodes represent syntax markers.
enum MdNodeType {
  /// Root document node
  document(1),

  // Block nodes
  /// Indented code block (4+ space indent)
  codeBlock(2),

  /// Fenced code block (``` or ~~~ delimited)
  fencedCode(3),

  /// Blockquote container (> prefix)
  blockquote(4),

  /// Horizontal rule (---, ***, ___)
  horizontalRule(5),

  /// Bullet list container (-, +, *)
  bulletList(6),

  /// Ordered list container (1., 1))
  orderedList(7),

  /// Single list item
  listItem(8),

  /// ATX heading level 1 (# Heading)
  atxHeading1(9),

  /// ATX heading level 2 (## Heading)
  atxHeading2(10),

  /// ATX heading level 3
  atxHeading3(11),

  /// ATX heading level 4
  atxHeading4(12),

  /// ATX heading level 5
  atxHeading5(13),

  /// ATX heading level 6
  atxHeading6(14),

  /// Setext heading level 1 (=== underline)
  setextHeading1(15),

  /// Setext heading level 2 (--- underline)
  setextHeading2(16),

  /// HTML block
  htmlBlock(17),

  /// Link reference definition ([label]: url "title")
  linkReference(18),

  /// Paragraph (default fallback block)
  paragraph(19),

  /// HTML comment block (<!-- ... -->)
  commentBlock(20),

  /// Processing instruction block (<? ... ?>)
  processingInstructionBlock(21),

  // Inline nodes
  /// Escaped character (\!)
  escape(22),

  /// HTML entity (&#123; &amp;)
  entity(23),

  /// Hard line break (\ or 2+ spaces at end)
  hardBreak(24),

  /// Emphasis (*text* or _text_)
  emphasis(25),

  /// Strong emphasis (**text** or __text__)
  strongEmphasis(26),

  /// Link ([text](url))
  link(27),

  /// Image (![alt](src))
  image(28),

  /// Inline code (`code`)
  inlineCode(29),

  /// HTML tag inline
  htmlTag(30),

  /// Inline comment (<!-- ... -->)
  comment(31),

  /// Processing instruction inline (<? ... ?>)
  processingInstruction(32),

  /// Autolink (<http://url>)
  autolink(33),

  // Mark/token nodes
  /// Header mark (# or === underline)
  headerMark(34),

  /// Quote mark (>)
  quoteMark(35),

  /// List mark (-, *, +, 1.)
  listMark(36),

  /// Link mark ([ ] ( ))
  linkMark(37),

  /// Emphasis mark (* or _)
  emphasisMark(38),

  /// Code mark (` or ``)
  codeMark(39),

  /// Code text content
  codeText(40),

  /// Code info string (language)
  codeInfo(41),

  /// Link title ("title")
  linkTitle(42),

  /// Link label ([label])
  linkLabel(43),

  /// URL part of links
  url(44),

  // GFM extension nodes
  /// Strikethrough (~~text~~)
  strikethrough(45),

  /// Strikethrough mark (~~)
  strikethroughMark(46),

  /// Table block
  table(47),

  /// Table header row
  tableHeader(48),

  /// Table data row
  tableRow(49),

  /// Table cell
  tableCell(50),

  /// Table delimiter (| or --- row)
  tableDelimiter(51),

  /// Task list item
  task(52),

  /// Task marker ([ ] or [x])
  taskMarker(53),

  /// Highlight (==text==)
  highlight(54),

  /// Highlight mark (==)
  highlightMark(55);

  final int id;
  const MdNodeType(this.id);

  /// Whether this is a block-level node
  bool get isBlock => id >= 1 && id <= 21;

  /// Whether this is an inline node
  bool get isInline => id >= 22 && id <= 33;

  /// Whether this is a container block (can contain other blocks)
  bool get isBlockContext {
    return this == document ||
        this == blockquote ||
        this == bulletList ||
        this == orderedList ||
        this == listItem;
  }

  /// Whether this is a leaf block (contains inline content)
  bool get isLeafBlock {
    return isBlock && !isBlockContext;
  }

  /// Get ATX heading type for a given level (1-6)
  static MdNodeType atxHeading(int level) {
    assert(level >= 1 && level <= 6);
    return MdNodeType.values.firstWhere((t) => t.id == 8 + level);
  }
}
