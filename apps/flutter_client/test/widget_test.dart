import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavern_headless/core/theme/app_theme.dart';
import 'package:tavern_headless/data/models/session_models.dart';
import 'package:tavern_headless/services/message_derivation.dart';
import 'package:tavern_headless/ui/widgets/app_surface.dart';

void main() {
  group('消息派生', () {
    test('剥离 HTML 卡面并解析行动选项', () {
      const raw = '''
雨声压在窗上。

```html
<!DOCTYPE html><html><body><div>卡片</div></body></html>
```

<SUOT>
1. 推开木门
2. 先听听走廊的动静
</SUOT>
''';
      final derived = deriveMessage(raw);
      expect(derived.markdown, contains('雨声压在窗上。'));
      expect(derived.markdown, isNot(contains('<!DOCTYPE html>')));
      expect(derived.markdown, isNot(contains('<SUOT>')));
      expect(derived.hasCard, isTrue);
      expect(derived.options.map((option) => option.text), [
        '推开木门',
        '先听听走廊的动静',
      ]);
      expect(derived.optionsUnclosed, isFalse);
    });

    test('未闭合的选项块会被标记，且不产生选项', () {
      const raw = '正文\n<SUOT>\n1. 只有开头';
      final derived = deriveMessage(raw);
      expect(derived.options, isEmpty);
      expect(derived.optionsUnclosed, isTrue);
      expect(derived.markdown, '正文');
    });
  });

  group('时间线解析', () {
    test('优先使用 active_pages', () {
      final floor = TimelineFloor.fromJson({
        'id': 'floor-1',
        'floor_no': 3,
        'state': 'committed',
        'created_at': 1700000000000,
        'active_pages': [
          {
            'id': 'page-2',
            'page_no': 2,
            'page_kind': 'reply',
            'messages': [
              {
                'id': 'msg-2',
                'seq': 2,
                'role': 'assistant',
                'content': '当前版本',
              },
            ],
          },
        ],
        'pages': [
          {
            'id': 'page-1',
            'page_no': 1,
            'page_kind': 'reply',
            'is_active': false,
            'messages': [
              {
                'id': 'msg-1',
                'seq': 1,
                'role': 'assistant',
                'content': '旧版本',
              },
            ],
          },
        ],
      });
      expect(floor.activePages.single.id, 'page-2');
      expect(floor.activePages.single.messages.single.content, '当前版本');
    });

    test('缺少 active_pages 时回退到 is_active 的页面', () {
      final floor = TimelineFloor.fromJson({
        'id': 'floor-2',
        'floor_no': 4,
        'state': 'committed',
        'created_at': 1700000000000,
        'pages': [
          {
            'id': 'page-a',
            'page_no': 1,
            'page_kind': 'reply',
            'is_active': false,
            'messages': <Object?>[],
          },
          {
            'id': 'page-b',
            'page_no': 2,
            'page_kind': 'reply',
            'is_active': true,
            'messages': <Object?>[],
          },
        ],
      });
      expect(floor.activePages.single.id, 'page-b');
    });
  });

  testWidgets('提示条可以渲染', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(
          scheme: ColorScheme.fromSeed(seedColor: AppTheme.seed),
          brightness: Brightness.light,
        ),
        home: const Scaffold(
          body: AppBanner(
            message: '测试提示',
            color: Colors.orange,
          ),
        ),
      ),
    );
    expect(find.text('测试提示'), findsOneWidget);
  });
}
