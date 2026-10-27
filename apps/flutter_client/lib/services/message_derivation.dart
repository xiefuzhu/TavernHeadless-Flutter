/// 客户端显示派生：把服务端原始消息拆成正文 Markdown 与行动选项。
/// 保存层永远是原始消息，这里的结果只用于显示。
class ActionOption {
  const ActionOption({required this.index, required this.text});

  final int index;
  final String text;
}

class DerivedMessage {
  const DerivedMessage({
    required this.markdown,
    required this.options,
    this.hasCard = false,
    this.optionsUnclosed = false,
    this.isEmptyBody = false,
  });

  final String markdown;
  final List<ActionOption> options;

  /// 消息包含被折叠的 HTML 卡面（M3 才实现受控 WebView 渲染）。
  final bool hasCard;

  /// 有 `<SUOT>` 开标签但没有闭标签，通常是输出预算耗尽。
  final bool optionsUnclosed;

  final bool isEmptyBody;

  bool get hasOptions => options.isNotEmpty;
}

final RegExp _cardBlock = RegExp(
  r'```(?:html)?\s*(<!DOCTYPE html>[\s\S]*?</html>)\s*```',
  caseSensitive: false,
);

final RegExp _suotBlock = RegExp(
  r'<SUOT\b[^>]*>([\s\S]*?)</SUOT>',
  caseSensitive: false,
);

final RegExp _suotOpen = RegExp(r'<SUOT\b', caseSensitive: false);

final RegExp _leadingIndex = RegExp(r'^\s*\d+\s*[.、.)）:：]\s*');

DerivedMessage deriveMessage(String rawContent) {
  final trimmedRaw = rawContent.trim();
  if (trimmedRaw.isEmpty) {
    return const DerivedMessage(
      markdown: '',
      options: [],
      isEmptyBody: true,
    );
  }

  final cards = <String>[];
  var body = rawContent.replaceAllMapped(_cardBlock, (match) {
    cards.add(match.group(1) ?? '');
    return '';
  });

  final options = <ActionOption>[];
  final collectFrom = cards.isEmpty ? body : '$body\n${cards.join('\n')}';
  for (final match in _suotBlock.allMatches(collectFrom)) {
    final block = match.group(1) ?? '';
    for (final line in block.split(RegExp(r'\r?\n'))) {
      final text = _cleanOptionLine(line);
      if (text.isEmpty) {
        continue;
      }
      options.add(ActionOption(index: options.length + 1, text: text));
    }
  }

  body = body.replaceAll(_suotBlock, '');
  final unclosed = _suotOpen.hasMatch(body);
  if (unclosed) {
    // 未闭合说明输出在中途被截断，标签之后的内容都是残缺选项，不应混进正文。
    final index = body.toLowerCase().indexOf('<suot');
    if (index >= 0) {
      body = body.substring(0, index);
    }
    body = body.replaceAll(RegExp(r'<SUOT\b[^>]*>', caseSensitive: false), '');
  }

  return DerivedMessage(
    markdown: body.trim(),
    options: options,
    hasCard: cards.isNotEmpty,
    optionsUnclosed: unclosed,
    isEmptyBody: body.trim().isEmpty && options.isEmpty && cards.isEmpty,
  );
}

String _cleanOptionLine(String line) {
  var value = line
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '');
  value = _decodeEntities(value);
  value = value.replaceAll(_leadingIndex, '');
  value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  return value;
}

String _decodeEntities(String input) {
  return input.replaceAllMapped(
    RegExp(r'&(#x?[0-9a-fA-F]+|[a-zA-Z]+);'),
    (match) {
      final entity = match.group(1) ?? '';
      switch (entity.toLowerCase()) {
        case 'amp':
          return '&';
        case 'lt':
          return '<';
        case 'gt':
          return '>';
        case 'quot':
          return '"';
        case 'apos':
          return "'";
        case 'nbsp':
          return ' ';
      }
      if (entity.startsWith('#x') || entity.startsWith('#X')) {
        final code = int.tryParse(entity.substring(2), radix: 16);
        return code == null ? match.group(0)! : String.fromCharCode(code);
      }
      if (entity.startsWith('#')) {
        final code = int.tryParse(entity.substring(1));
        return code == null ? match.group(0)! : String.fromCharCode(code);
      }
      return match.group(0)!;
    },
  );
}
