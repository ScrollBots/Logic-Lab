import 'dart:math' as math;

class BooleanParseException implements Exception {
  const BooleanParseException(this.message, {this.position = 0});

  final String message;

  /// Zero-based character offset in the original input, or 0 for semantic
  /// errors that do not point at a token.
  final int position;

  @override
  String toString() => message;
}

abstract class BoolExpr {
  const BoolExpr();

  Set<String> collectVariables();
  bool evaluate(Map<String, bool> values);
  String toExpressionString();

  @override
  String toString() => toExpressionString();
}

class BoolConstant extends BoolExpr {
  const BoolConstant(this.value);

  final bool value;

  @override
  Set<String> collectVariables() => <String>{};

  @override
  bool evaluate(Map<String, bool> values) => value;

  @override
  String toExpressionString() => value ? '1' : '0';
}

class BoolVariable extends BoolExpr {
  const BoolVariable(this.name);

  final String name;

  @override
  Set<String> collectVariables() => <String>{name};

  @override
  bool evaluate(Map<String, bool> values) {
    final bool? value = values[name];
    if (value == null) {
      throw ArgumentError('مقدار متغیر $name مشخص نشده است.');
    }
    return value;
  }

  @override
  String toExpressionString() => name;
}

class BoolNot extends BoolExpr {
  const BoolNot(this.operand);

  final BoolExpr operand;

  @override
  Set<String> collectVariables() => operand.collectVariables();

  @override
  bool evaluate(Map<String, bool> values) => !operand.evaluate(values);

  @override
  String toExpressionString() {
    final String inner = operand.toExpressionString();
    if (operand is BoolBinary || operand is BoolNot) {
      return '!($inner)';
    }
    return '!$inner';
  }
}

enum BooleanOperator {
  and('&'),
  xor('^'),
  or('|');

  const BooleanOperator(this.symbol);

  final String symbol;

  int get precedence => switch (this) {
    BooleanOperator.or => 1,
    BooleanOperator.xor => 2,
    BooleanOperator.and => 3,
  };

  String get persianName => switch (this) {
    BooleanOperator.and => 'و منطقی',
    BooleanOperator.xor => 'یای انحصاری',
    BooleanOperator.or => 'یا منطقی',
  };
}

class BoolBinary extends BoolExpr {
  const BoolBinary(this.operator, this.left, this.right);

  final BooleanOperator operator;
  final BoolExpr left;
  final BoolExpr right;

  @override
  Set<String> collectVariables() {
    return <String>{...left.collectVariables(), ...right.collectVariables()};
  }

  @override
  bool evaluate(Map<String, bool> values) {
    return switch (operator) {
      BooleanOperator.and => left.evaluate(values) && right.evaluate(values),
      BooleanOperator.or => left.evaluate(values) || right.evaluate(values),
      BooleanOperator.xor => left.evaluate(values) != right.evaluate(values),
    };
  }

  @override
  String toExpressionString() {
    final int precedence = operator.precedence;
    final String leftString = _wrap(left, precedence, isRight: false);
    final String rightString = _wrap(right, precedence, isRight: true);
    return '$leftString ${operator.symbol} $rightString';
  }

  String _wrap(BoolExpr child, int parentPrecedence, {required bool isRight}) {
    if (child is BoolBinary) {
      final int childPrecedence = child.operator.precedence;
      final bool needsWrap = childPrecedence < parentPrecedence;
      if (needsWrap) {
        return '(${child.toExpressionString()})';
      }
    }
    if (child is BoolConstant || child is BoolVariable || child is BoolNot) {
      return child.toExpressionString();
    }
    return '(${child.toExpressionString()})';
  }
}

/// Recursive-descent parser. Supported grammar:
///
/// ```
/// expression := xor (OR xor)*
/// xor        := and (XOR and)*
/// and        := unary (AND unary)*
/// unary      := NOT unary | primary
/// primary    := variable | 0 | 1 | '(' expression ')'
/// ```
///
/// Symbols and English keywords are both accepted. Variables are identifiers
/// (`A`, `input1`); reserved operator words cannot be variable names.
class BooleanExpressionParser {
  BooleanExpressionParser._(this.source) : _tokens = _Lexer(source).lex();

  final String source;
  final List<_Token> _tokens;
  int _index = 0;

  static BoolExpr parse(String source) {
    if (source.trim().isEmpty) {
      throw const BooleanParseException('عبارت بولی خالی است.');
    }
    final BooleanExpressionParser parser = BooleanExpressionParser._(source);
    final BoolExpr expression = parser._parseOr();
    if (parser._peek.type != _TokenType.eof) {
      final _Token token = parser._peek;
      throw BooleanParseException(
        'توکن اضافی «${token.lexeme}» در عبارت وجود دارد.',
        position: token.position,
      );
    }
    return expression;
  }

  _Token get _peek => _tokens[_index];

  _Token _advance() => _tokens[_index++];

  bool _match(_TokenType type) {
    if (_peek.type == type) {
      _advance();
      return true;
    }
    return false;
  }

  BoolExpr _parseOr() {
    BoolExpr left = _parseXor();
    while (_match(_TokenType.orOp)) {
      final BoolExpr right = _parseXor();
      left = BoolBinary(BooleanOperator.or, left, right);
    }
    return left;
  }

  BoolExpr _parseXor() {
    BoolExpr left = _parseAnd();
    while (_match(_TokenType.xorOp)) {
      final BoolExpr right = _parseAnd();
      left = BoolBinary(BooleanOperator.xor, left, right);
    }
    return left;
  }

  BoolExpr _parseAnd() {
    BoolExpr left = _parseUnary();
    while (_match(_TokenType.andOp)) {
      final BoolExpr right = _parseUnary();
      left = BoolBinary(BooleanOperator.and, left, right);
    }
    return left;
  }

  BoolExpr _parseUnary() {
    if (_match(_TokenType.notOp)) {
      return BoolNot(_parseUnary());
    }
    return _parsePrimary();
  }

  BoolExpr _parsePrimary() {
    final _Token token = _peek;
    switch (token.type) {
      case _TokenType.variable:
        _advance();
        return BoolVariable(token.lexeme);
      case _TokenType.constant:
        _advance();
        return BoolConstant(token.lexeme == '1');
      case _TokenType.notOp:
        _advance();
        return BoolNot(_parsePrimary());
      case _TokenType.leftParen:
        _advance();
        if (_peek.type == _TokenType.rightParen) {
          throw BooleanParseException(
            'داخل پرانتز خالی است.',
            position: token.position,
          );
        }
        final BoolExpr inner = _parseOr();
        if (!_match(_TokenType.rightParen)) {
          throw BooleanParseException(
            'برای پرانتز باز، پرانتز بسته پیدا نشد.',
            position: token.position,
          );
        }
        return inner;
      case _TokenType.rightParen:
        throw BooleanParseException(
          'پرانتز بسته بدون پرانتز باز آمده است.',
          position: token.position,
        );
      case _TokenType.andOp:
      case _TokenType.orOp:
      case _TokenType.xorOp:
        throw BooleanParseException(
          'عملگر «${token.lexeme}» به عملوند نیاز دارد.',
          position: token.position,
        );
      case _TokenType.unknown:
        throw BooleanParseException(
          'نماد «${token.lexeme}» پشتیبانی نمی‌شود. از &، |، !، ^ یا پرانتز استفاده کنید.',
          position: token.position,
        );
      case _TokenType.eof:
        throw BooleanParseException(
          'عبارت ناقص است؛ پس از این نقطه به عملوند نیاز است.',
          position: source.length,
        );
    }
  }
}

enum _TokenType {
  variable,
  constant,
  andOp,
  orOp,
  xorOp,
  notOp,
  leftParen,
  rightParen,
  unknown,
  eof,
}

class _Token {
  const _Token(this.type, this.lexeme, this.position);

  final _TokenType type;
  final String lexeme;
  final int position;
}

class _Lexer {
  _Lexer(this.source);

  final String source;
  int _offset = 0;

  List<_Token> lex() {
    final List<_Token> tokens = <_Token>[];
    while (_offset < source.length) {
      final String char = source[_offset];
      if (_isWhitespace(char)) {
        _offset++;
        continue;
      }
      if (char == '(') {
        tokens.add(_Token(_TokenType.leftParen, char, _offset++));
        continue;
      }
      if (char == ')') {
        tokens.add(_Token(_TokenType.rightParen, char, _offset++));
        continue;
      }
      if (char == '!' || char == '~' || char == '¬') {
        tokens.add(_Token(_TokenType.notOp, char, _offset++));
        continue;
      }
      if (char == '&') {
        final int start = _offset;
        _offset++;
        if (_offset < source.length && source[_offset] == '&') {
          _offset++;
        }
        tokens.add(
          _Token(_TokenType.andOp, source.substring(start, _offset), start),
        );
        continue;
      }
      if (char == '*' || char == '.' || char == '·' || char == '∧') {
        tokens.add(_Token(_TokenType.andOp, char, _offset++));
        continue;
      }
      if (char == '|') {
        final int start = _offset;
        _offset++;
        if (_offset < source.length && source[_offset] == '|') {
          _offset++;
        }
        tokens.add(
          _Token(_TokenType.orOp, source.substring(start, _offset), start),
        );
        continue;
      }
      if (char == '+' || char == '∨') {
        tokens.add(_Token(_TokenType.orOp, char, _offset++));
        continue;
      }
      if (char == '^' || char == '⊕') {
        tokens.add(_Token(_TokenType.xorOp, char, _offset++));
        continue;
      }
      if (_isDigit(char)) {
        final int start = _offset;
        _offset++;
        final String lexeme = source.substring(start, _offset);
        if (lexeme == '0' || lexeme == '1') {
          tokens.add(_Token(_TokenType.constant, lexeme, start));
        } else {
          tokens.add(_Token(_TokenType.unknown, lexeme, start));
        }
        continue;
      }
      if (_isIdentifierStart(char)) {
        final int start = _offset;
        _offset++;
        while (_offset < source.length && _isIdentifierPart(source[_offset])) {
          _offset++;
        }
        final String word = source.substring(start, _offset);
        final String upper = word.toUpperCase();
        tokens.add(switch (upper) {
          'AND' => _Token(_TokenType.andOp, word, start),
          'OR' => _Token(_TokenType.orOp, word, start),
          'XOR' => _Token(_TokenType.xorOp, word, start),
          'NOT' => _Token(_TokenType.notOp, word, start),
          _ => _Token(_TokenType.variable, word, start),
        });
        continue;
      }
      tokens.add(_Token(_TokenType.unknown, char, _offset++));
    }
    tokens.add(_Token(_TokenType.eof, '', source.length));
    return tokens;
  }

  static bool _isWhitespace(String char) => char.trim().isEmpty;
  static bool _isDigit(String char) =>
      char.codeUnitAt(0) >= 0x30 && char.codeUnitAt(0) <= 0x39;

  static bool _isIdentifierStart(String char) {
    final int code = char.codeUnitAt(0);
    return (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122) ||
        code == 0x5F;
  }

  static bool _isIdentifierPart(String char) {
    return _isIdentifierStart(char) || _isDigit(char);
  }
}

class ExpressionTruthRow {
  const ExpressionTruthRow(this.inputs, this.output);

  final Map<String, bool> inputs;
  final bool output;
}

class ExpressionTruthTable {
  const ExpressionTruthTable({
    required this.expression,
    required this.variables,
    required this.rows,
  });

  final BoolExpr expression;
  final List<String> variables;
  final List<ExpressionTruthRow> rows;

  static ExpressionTruthTable generate(
    BoolExpr expression, {
    int maxVariables = 8,
  }) {
    final List<String> variables =
        expression.collectVariables().toList()..sort();
    if (variables.length > maxVariables) {
      throw BooleanParseException(
        'این عبارت ${variables.length} متغیر دارد؛ حداکثر $maxVariables متغیر پشتیبانی می‌شود.',
      );
    }
    final int combinations = 1 << variables.length;
    final List<ExpressionTruthRow> rows = <ExpressionTruthRow>[];
    for (int combination = 0; combination < combinations; combination++) {
      final Map<String, bool> values = <String, bool>{};
      for (int i = 0; i < variables.length; i++) {
        values[variables[i]] =
            ((combination >> (variables.length - i - 1)) & 1) == 1;
      }
      rows.add(ExpressionTruthRow(values, expression.evaluate(values)));
    }
    return ExpressionTruthTable(
      expression: expression,
      variables: List<String>.unmodifiable(variables),
      rows: List<ExpressionTruthRow>.unmodifiable(rows),
    );
  }
}

class SimplificationResult {
  const SimplificationResult({
    required this.original,
    required this.simplifiedText,
    required this.exact,
    required this.method,
    required this.message,
    this.simplified,
    this.variableCount = 0,
    this.termCount = 0,
    this.literalCount = 0,
    this.verified = false,
  });

  final BoolExpr original;
  final String? simplifiedText;
  final BoolExpr? simplified;
  final bool exact;
  final bool verified;
  final String method;
  final String message;
  final int variableCount;
  final int termCount;
  final int literalCount;
}

class BooleanSimplifier {
  const BooleanSimplifier._();

  static const int exactVariableLimit = 6;
  static const int _searchLimit = 200000;

  /// Quine–McCluskey prime implicants plus an exhaustive branch-and-bound
  /// cover search. A result is only labelled "exact" after the simplified
  /// expression is re-parsed and compared with the original for every
  /// assignment. For more than six variables we explicitly decline to claim a
  /// minimum rather than presenting an unverified heuristic as exact.
  static SimplificationResult simplify(BoolExpr expression) {
    final List<String> variables =
        expression.collectVariables().toList()..sort();
    if (variables.length > exactVariableLimit) {
      return SimplificationResult(
        original: expression,
        simplifiedText: null,
        exact: false,
        method: 'کوئین–مک‌کلاسکی',
        message:
            'برای بیش از ${_fa(exactVariableLimit)} متغیر، جست‌وجوی جامع حداقل‌سازی در این نسخه انجام نمی‌شود؛ بنابراین نتیجه‌ای به‌عنوان «حداقل قطعی» ارائه نشده است.',
        variableCount: variables.length,
      );
    }

    final int count = 1 << variables.length;
    final Set<int> minterms = <int>{};
    for (int assignment = 0; assignment < count; assignment++) {
      final Map<String, bool> values = <String, bool>{};
      for (int i = 0; i < variables.length; i++) {
        values[variables[i]] =
            ((assignment >> (variables.length - i - 1)) & 1) == 1;
      }
      if (expression.evaluate(values)) {
        minterms.add(assignment);
      }
    }

    if (minterms.isEmpty) {
      return _constantResult(
        expression,
        variables.length,
        '0',
        isTautology: false,
      );
    }
    if (minterms.length == count) {
      return _constantResult(
        expression,
        variables.length,
        '1',
        isTautology: true,
      );
    }

    final List<_Implicant> primes = _primeImplicants(
      minterms,
      variables.length,
    );
    final Set<int> allCovered = <int>{};
    final Map<int, List<_Implicant>> coversByMinterm =
        <int, List<_Implicant>>{};
    for (final int minterm in minterms) {
      coversByMinterm[minterm] =
          primes.where((_Implicant p) => p.covers.contains(minterm)).toList();
    }
    for (final _Implicant prime in primes) {
      allCovered.addAll(prime.covers);
    }
    if (!allCovered.containsAll(minterms)) {
      return SimplificationResult(
        original: expression,
        simplifiedText: null,
        exact: false,
        method: 'کوئین–مک‌کلاسکی',
        message: 'پوشش کامل ایمپلیکانت‌ها پیدا نشد؛ نتیجه‌ای ارائه نمی‌شود.',
        variableCount: variables.length,
      );
    }

    final Set<_Implicant> essential = <_Implicant>{};
    for (final int minterm in minterms) {
      final List<_Implicant> cover = coversByMinterm[minterm]!;
      if (cover.length == 1) {
        essential.add(cover.first);
      }
    }
    final Set<int> coveredByEssentials = <int>{};
    for (final _Implicant prime in essential) {
      coveredByEssentials.addAll(prime.covers);
    }
    final Set<int> remaining = minterms.difference(coveredByEssentials);

    final List<List<_Implicant>> bestSolutions = <List<_Implicant>>[];
    int? bestTermCount;
    int? bestLiteralCount;
    int visits = 0;
    bool exhausted = true;

    void search(Set<int> uncovered, List<_Implicant> chosen, int literalCount) {
      visits++;
      if (visits > _searchLimit) {
        exhausted = false;
        return;
      }
      if (bestTermCount != null && chosen.length >= bestTermCount!) {
        return;
      }
      if (uncovered.isEmpty) {
        final List<_Implicant> full = <_Implicant>[...essential, ...chosen];
        final int terms = full.length;
        if (bestTermCount == null || terms < bestTermCount!) {
          bestTermCount = terms;
          bestLiteralCount = literalCount;
          bestSolutions
            ..clear()
            ..add(full);
        } else if (terms == bestTermCount && literalCount == bestLiteralCount) {
          bestSolutions.add(full);
        } else if (terms == bestTermCount &&
            (bestLiteralCount == null || literalCount < bestLiteralCount!)) {
          bestLiteralCount = literalCount;
          bestSolutions
            ..clear()
            ..add(full);
        }
        return;
      }

      int pivot = uncovered.first;
      int pivotCoverCount = coversByMinterm[pivot]!.length;
      for (final int minterm in uncovered) {
        final int candidateCount = coversByMinterm[minterm]!.length;
        if (candidateCount < pivotCoverCount) {
          pivot = minterm;
          pivotCoverCount = candidateCount;
        }
      }
      final List<_Implicant> candidates =
          coversByMinterm[pivot]!
              .where((_Implicant p) => !essential.contains(p))
              .toList()
            ..sort((_Implicant a, _Implicant b) {
              final int sizeA = a.covers.length;
              final int sizeB = b.covers.length;
              if (sizeA != sizeB) {
                return sizeB.compareTo(sizeA);
              }
              return a.mask.compareTo(b.mask);
            });
      for (final _Implicant candidate in candidates) {
        if (chosen.contains(candidate)) {
          continue;
        }
        if (!exhausted) {
          return;
        }
        if (bestTermCount != null && chosen.length + 1 >= bestTermCount!) {
          continue;
        }
        final Set<int> nextUncovered = uncovered.difference(candidate.covers);
        search(nextUncovered, <_Implicant>[
          ...chosen,
          candidate,
        ], literalCount + _literalCount(candidate, variables.length));
      }
    }

    search(remaining, <_Implicant>[], 0);
    if (!exhausted || bestSolutions.isEmpty) {
      return SimplificationResult(
        original: expression,
        simplifiedText: null,
        exact: false,
        method: 'کوئین–مک‌کلاسکی',
        message:
            'جست‌وجوی دقیق به سقف محاسباتی رسید؛ برای جلوگیری از ادعای نادرست، نتیجه‌ای به‌عنوان حداقل ارائه نشده است.',
        variableCount: variables.length,
      );
    }

    final List<_Implicant> solution = bestSolutions.first;
    final String text = _implicantsToExpression(solution, variables);
    BoolExpr? simplified;
    bool verified = false;
    try {
      simplified = BooleanExpressionParser.parse(text);
      final Set<String> simplifiedVars = simplified.collectVariables();
      // The simplified expression may use fewer variables than the original
      // (that is what a minimisation is for), but it must not introduce a
      // variable that the original does not contain.
      final bool noNewVariables = simplifiedVars.every(variables.contains);
      if (noNewVariables) {
        verified = true;
        for (int assignment = 0; assignment < count; assignment++) {
          final Map<String, bool> values = <String, bool>{};
          for (int i = 0; i < variables.length; i++) {
            values[variables[i]] =
                ((assignment >> (variables.length - i - 1)) & 1) == 1;
          }
          if (expression.evaluate(values) != simplified.evaluate(values)) {
            verified = false;
            break;
          }
        }
      }
    } on BooleanParseException {
      verified = false;
    }

    if (!verified) {
      return SimplificationResult(
        original: expression,
        simplifiedText: null,
        exact: false,
        method: 'کوئین–مک‌کلاسکی',
        message:
            'عبارت ساده‌شده بازسازی شد اما اعتبارسنجی جامع آن موفق نبود؛ بنابراین نتیجه نمایش داده نمی‌شود.',
        variableCount: variables.length,
      );
    }

    return SimplificationResult(
      original: expression,
      simplifiedText: text,
      simplified: simplified!,
      exact: true,
      verified: verified,
      method: 'کوئین–مک‌کلاسکی + پوشش جامع',
      message:
          'کمینه‌بودن با شمارش همه ترکیب‌های ${variables.length} متغیر تأیید شد.',
      variableCount: variables.length,
      termCount: solution.length,
      literalCount: solution.fold<int>(
        0,
        (int sum, _Implicant p) => sum + _literalCount(p, variables.length),
      ),
    );
  }

  static SimplificationResult _constantResult(
    BoolExpr original,
    int variableCount,
    String value, {
    required bool isTautology,
  }) {
    final BoolExpr simplified = BoolConstant(isTautology);
    return SimplificationResult(
      original: original,
      simplifiedText: value,
      simplified: simplified,
      exact: true,
      verified: true,
      method: 'تحلیل جدول حقیقت',
      message: 'عبارت برای همه ترکیب‌ها ثابت است.',
      variableCount: variableCount,
      termCount: isTautology ? 0 : 1,
      literalCount: 0,
    );
  }

  static List<_Implicant> _primeImplicants(Set<int> minterms, int n) {
    List<_Implicant> current =
        minterms
            .map(
              (int minterm) => _Implicant(
                mask: (1 << n) - 1,
                bits: minterm,
                covers: <int>{minterm},
              ),
            )
            .toList();
    final List<_Implicant> primes = <_Implicant>[];

    while (current.isNotEmpty) {
      final Set<int> used = <int>{};
      final Map<String, _Implicant> next = <String, _Implicant>{};
      for (int i = 0; i < current.length; i++) {
        for (int j = i + 1; j < current.length; j++) {
          final _Implicant? merged = _combine(current[i], current[j]);
          if (merged != null) {
            used
              ..add(i)
              ..add(j);
            next['${merged.mask}:${merged.bits}'] = merged;
          }
        }
      }
      for (int i = 0; i < current.length; i++) {
        if (!used.contains(i)) {
          primes.add(current[i]);
        }
      }
      current = next.values.toList();
    }
    return primes;
  }

  static _Implicant? _combine(_Implicant a, _Implicant b) {
    if (a.mask != b.mask) {
      return null;
    }
    final int differing = a.bits ^ b.bits;
    if (differing == 0 || (differing & (differing - 1)) != 0) {
      return null;
    }
    if ((a.mask & differing) == 0) {
      return null;
    }
    final int newMask = a.mask & ~differing;
    return _Implicant(
      mask: newMask,
      bits: a.bits & newMask,
      covers: <int>{...a.covers, ...b.covers},
    );
  }

  static int _literalCount(_Implicant implicant, int _) {
    return _bitCount(implicant.mask);
  }

  static int _bitCount(int value) {
    int count = 0;
    while (value != 0) {
      value &= value - 1;
      count++;
    }
    return count;
  }

  static String _implicantsToExpression(
    List<_Implicant> implicants,
    List<String> variables,
  ) {
    final List<_Implicant> sorted = List<_Implicant>.from(implicants)
      ..sort((_Implicant a, _Implicant b) {
        final int bitsA = _bitCount(a.mask);
        final int bitsB = _bitCount(b.mask);
        if (bitsA != bitsB) {
          return bitsB.compareTo(bitsA);
        }
        return a.bits.compareTo(b.bits);
      });
    final List<String> terms = <String>[];
    for (final _Implicant implicant in sorted) {
      if (implicant.mask == 0) {
        return '1';
      }
      final List<String> literals = <String>[];
      for (int i = 0; i < variables.length; i++) {
        final int bit = 1 << (variables.length - i - 1);
        if ((implicant.mask & bit) == 0) {
          continue;
        }
        final bool positive = (implicant.bits & bit) != 0;
        literals.add('${positive ? '' : '!'}${variables[i]}');
      }
      terms.add(literals.length == 1 ? literals.first : literals.join(' & '));
    }
    return terms.isEmpty ? '0' : terms.join(' | ');
  }

  static String _fa(int n) => n.toString();
}

class _Implicant {
  const _Implicant({
    required this.mask,
    required this.bits,
    required this.covers,
  });

  final int mask;
  final int bits;
  final Set<int> covers;

  @override
  bool operator ==(Object other) {
    return other is _Implicant && other.mask == mask && other.bits == bits;
  }

  @override
  int get hashCode => Object.hash(mask, bits);
}

class ExpressionComparisonResult {
  const ExpressionComparisonResult({
    required this.left,
    required this.right,
    required this.variables,
    required this.equivalent,
    required this.mismatchCount,
    required this.leftTruthTable,
    required this.rightTruthTable,
  });

  final BoolExpr left;
  final BoolExpr right;
  final List<String> variables;
  final bool equivalent;
  final int mismatchCount;
  final ExpressionTruthTable leftTruthTable;
  final ExpressionTruthTable rightTruthTable;

  String get summary {
    if (equivalent) {
      return 'دو عبارت برای همه ترکیب‌ها رفتار یکسانی دارند و هم‌ارزند.';
    }
    if (variables.length > 8) {
      return 'مقایسه بیش از ۸ متغیر پشتیبانی نمی‌شود.';
    }
    return 'دو عبارت در $mismatchCount ترکیب خروجی متفاوت دارند و هم‌ارز نیستند.';
  }
}

class BooleanExpressionTools {
  const BooleanExpressionTools._();

  static ExpressionComparisonResult compare(BoolExpr left, BoolExpr right) {
    final Set<String> variableSet = <String>{
      ...left.collectVariables(),
      ...right.collectVariables(),
    };
    final List<String> variables = variableSet.toList()..sort();
    if (variables.length > 8) {
      throw BooleanParseException(
        'مقایسه بیش از ۸ متغیر امکان‌پذیر نیست؛ عبارت را ساده‌تر کنید.',
      );
    }
    final int count = 1 << variables.length;
    int mismatches = 0;
    final List<ExpressionTruthRow> leftRows = <ExpressionTruthRow>[];
    final List<ExpressionTruthRow> rightRows = <ExpressionTruthRow>[];
    for (int combination = 0; combination < count; combination++) {
      final Map<String, bool> values = <String, bool>{};
      for (int i = 0; i < variables.length; i++) {
        values[variables[i]] =
            ((combination >> (variables.length - i - 1)) & 1) == 1;
      }
      final bool l = left.evaluate(values);
      final bool r = right.evaluate(values);
      if (l != r) {
        mismatches++;
      }
      leftRows.add(ExpressionTruthRow(values, l));
      rightRows.add(ExpressionTruthRow(values, r));
    }
    return ExpressionComparisonResult(
      left: left,
      right: right,
      variables: List<String>.unmodifiable(variables),
      equivalent: mismatches == 0,
      mismatchCount: mismatches,
      leftTruthTable: ExpressionTruthTable(
        expression: left,
        variables: List<String>.unmodifiable(variables),
        rows: List<ExpressionTruthRow>.unmodifiable(leftRows),
      ),
      rightTruthTable: ExpressionTruthTable(
        expression: right,
        variables: List<String>.unmodifiable(variables),
        rows: List<ExpressionTruthRow>.unmodifiable(rightRows),
      ),
    );
  }

  static String variableSummary(BoolExpr expression) {
    final List<String> variables =
        expression.collectVariables().toList()..sort();
    if (variables.isEmpty) {
      return 'بدون متغیر';
    }
    return variables.join('، ');
  }

  static String expressionStats(BoolExpr expression) {
    final int variables = expression.collectVariables().length;
    final int combinations = variables > 20 ? 0 : 1 << variables;
    return '$combinations ترکیب';
  }
}

extension BooleanMath on bool {
  bool get asBit => this;

  int get asInt => this ? 1 : 0;
}

int booleanCombinationCount(int variables) {
  if (variables < 0) {
    throw ArgumentError.value(variables, 'variables');
  }
  if (variables > 20) {
    return 1 << 20;
  }
  return math.max(1, 1 << variables);
}
