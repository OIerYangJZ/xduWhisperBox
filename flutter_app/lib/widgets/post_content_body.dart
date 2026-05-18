import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import '../core/config/app_config.dart';

class PostContentBody extends StatelessWidget {
  const PostContentBody({
    super.key,
    required this.content,
    this.contentFormat = 'plain',
    this.markdownSource = '',
    this.selectable = false,
  });

  final String content;
  final String contentFormat;
  final String markdownSource;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final String normalizedFormat = contentFormat.trim().toLowerCase();
    final String markdownData =
        markdownSource.isNotEmpty ? markdownSource : content;
    if (normalizedFormat != 'markdown' || markdownData.trim().isEmpty) {
      final TextStyle? style = Theme.of(
        context,
      ).textTheme.bodyLarge?.copyWith(height: 1.6);
      if (selectable) {
        return SelectableText(content, style: style);
      }
      return Text(
        content,
        style: style,
      );
    }

    return MarkdownBody(
      data: markdownData,
      selectable: selectable,
      softLineBreak: true,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      inlineSyntaxes: <md.InlineSyntax>[
        _InlineMathSyntax(),
      ],
      blockSyntaxes: <md.BlockSyntax>[
        _BlockMathSyntax(),
      ],
      builders: <String, MarkdownElementBuilder>{
        'math-inline': _MathElementBuilder(isBlock: false),
        'math-block': _MathElementBuilder(isBlock: true),
      },
      sizedImageBuilder: (MarkdownImageConfig config) {
        final String resolvedUrl = AppConfig.resolveUrl(config.uri.toString());
        final String rawSemanticLabel = (config.alt ?? config.title ?? '').trim();
        final String semanticLabel =
            rawSemanticLabel.isEmpty ? '图片' : rawSemanticLabel;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              resolvedUrl,
              width: config.width ?? double.infinity,
              height: config.height,
              fit: BoxFit.contain,
              semanticLabel: semanticLabel,
              loadingBuilder: (
                BuildContext context,
                Widget child,
                ImageChunkEvent? loadingProgress,
              ) {
                if (loadingProgress == null) {
                  return child;
                }
                return Container(
                  constraints: const BoxConstraints(minHeight: 120),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(strokeWidth: 2.4),
                );
              },
              errorBuilder: (
                BuildContext context,
                Object error,
                StackTrace? stackTrace,
              ) {
                return Container(
                  constraints: const BoxConstraints(minHeight: 120),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(16),
                  child: const Text(
                    '图片加载失败',
                    style: TextStyle(color: Colors.black54),
                  ),
                );
              },
            ),
          ),
        );
      },
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.7),
        blockquote: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.74),
              height: 1.6,
            ),
        code: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
        codeblockDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _MathElementBuilder extends MarkdownElementBuilder {
  _MathElementBuilder({required this.isBlock});

  final bool isBlock;

  @override
  bool isBlockElement() => isBlock;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final String source = (element.attributes['tex'] ?? element.textContent).trim();
    if (source.isEmpty) {
      return const SizedBox.shrink();
    }
    final Widget math = Math.tex(
      source,
      mathStyle: isBlock ? MathStyle.display : MathStyle.text,
      textStyle: preferredStyle ?? parentStyle,
      onErrorFallback: (FlutterMathException error) {
        return Text(
          source,
          style: (preferredStyle ?? parentStyle)?.copyWith(
            fontFamily: 'monospace',
            color: Theme.of(context).colorScheme.error,
          ),
        );
      },
    );
    if (!isBlock) {
      return Text.rich(
        TextSpan(
          children: <InlineSpan>[
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: math,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: math,
      ),
    );
  }
}

class _InlineMathSyntax extends md.InlineSyntax {
  _InlineMathSyntax() : super(r'(?<!\$)\$([^\$\n]+?)(?<!\\)\$(?!\$)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final String expression = (match.group(1) ?? '').trim();
    if (expression.isEmpty) {
      return false;
    }
    final md.Element element = md.Element.text('math-inline', expression)
      ..attributes['tex'] = expression;
    parser.addNode(element);
    return true;
  }
}

class _BlockMathSyntax extends md.BlockSyntax {
  @override
  bool canParse(md.BlockParser parser) {
    return parser.current.content.trim().startsWith(r'$$');
  }

  @override
  RegExp get pattern => RegExp(r'^\$\$');

  @override
  md.Node parse(md.BlockParser parser) {
    final String firstLine = parser.current.content.trim();
    parser.advance();

    final StringBuffer buffer = StringBuffer();
    if (firstLine.length > 4 && firstLine.endsWith(r'$$')) {
      buffer.write(firstLine.substring(2, firstLine.length - 2).trim());
    } else {
      final String leading = firstLine.substring(2).trim();
      if (leading.isNotEmpty) {
        buffer.writeln(leading);
      }
      while (!parser.isDone) {
        final String line = parser.current.content;
        final String trimmed = line.trim();
        if (trimmed.endsWith(r'$$')) {
          final String trailing = trimmed.substring(0, trimmed.length - 2).trim();
          if (trailing.isNotEmpty) {
            buffer.writeln(trailing);
          }
          parser.advance();
          break;
        }
        buffer.writeln(line);
        parser.advance();
      }
    }

    final String expression = buffer.toString().trim();
    final md.Element element = md.Element.empty('math-block')
      ..attributes['tex'] = expression;
    return element;
  }
}
