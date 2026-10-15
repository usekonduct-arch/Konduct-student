import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'strings_ha.dart';
import 'strings_pcm.dart';
import 'strings_yo.dart';

/// The languages the app speaks. English is the source: every other language is a table of
/// English text → translation (strings_*.dart), and anything without a translation stays English.
enum Lang {
  en('en', 'English', 'English'),
  pcm('pcm', 'Naijá', 'Nigerian Pidgin'),
  yo('yo', 'Yorùbá', 'Yoruba'),
  ha('ha', 'Hausa', 'Hausa');

  const Lang(this.code, this.nativeName, this.englishName);

  /// What the backend stores on users/{uid}.lang (konduct-backend domain/i18n.ts).
  final String code;

  /// The language's name in itself, for the picker.
  final String nativeName;
  final String englishName;

  /// The phone's text-to-speech language tags to try for spoken alerts, best first.
  List<String> get speech => switch (this) {
    Lang.en || Lang.pcm => const ['en-NG', 'en-GB', 'en-US'],
    Lang.yo => const ['yo-NG', 'yo'],
    Lang.ha => const ['ha-NG', 'ha'],
  };

  static Lang? fromCode(String? code) => Lang.values.where((l) => l.code == code).firstOrNull;
}

/// The app's language. Every [Text] in the app translates through it, so changing the language
/// redraws every screen at once (see text.dart).
class L10n extends ChangeNotifier {
  L10n._();
  static final instance = L10n._();
  static const _key = 'konduct.lang';

  Lang _lang = Lang.en;
  Lang get lang => _lang;

  /// Told about every change, for example to save the language on the server for push notifications.
  final _listeners = <void Function(Lang)>[];
  void onChanged(void Function(Lang) f) => _listeners.add(f);

  /// The saved choice; on first run, the phone's language when the app has it.
  Future<void> load() async {
    Lang? saved;
    try {
      saved = Lang.fromCode((await SharedPreferences.getInstance()).getString(_key));
    } catch (_) {}
    final device = WidgetsBinding.instance.platformDispatcher.locales.map((l) => Lang.fromCode(l.languageCode)).nonNulls.firstOrNull;
    _use(saved ?? device ?? Lang.en);
  }

  Future<void> set(Lang l) async {
    if (l == _lang) return;
    _use(l);
    try {
      await (await SharedPreferences.getInstance()).setString(_key, l.code);
    } catch (_) {}
    for (final f in _listeners) {
      f(l);
    }
  }

  void _use(Lang l) {
    _lang = l;
    _memo.clear();
    notifyListeners();
  }

  @visibleForTesting
  void debugSet(Lang l) => _use(l);
}

/// Puts the language above the app so [Text] widgets can depend on it and redraw when it changes.
class L10nScope extends InheritedNotifier<L10n> {
  L10nScope({super.key, required super.child}) : super(notifier: L10n.instance);

  /// Registers [context] for language changes and returns the language.
  static Lang watch(BuildContext context) => context.dependOnInheritedWidgetOfExactType<L10nScope>()?.notifier?.lang ?? L10n.instance.lang;
}

/// The current language's table.
Map<String, String> _table(Lang l) => switch (l) {
  Lang.en => const {},
  Lang.pcm => pcmStrings,
  Lang.yo => yoStrings,
  Lang.ha => haStrings,
};

/// A table entry with {placeholders}, compiled to a pattern: "Hi, {name}" matches "Hi, Ada".
class _Template {
  _Template(String source, this.out) : weight = source.replaceAll(_slot, '').length {
    final pattern = StringBuffer('^');
    var i = 0;
    for (final m in _slot.allMatches(source)) {
      pattern
        ..write(RegExp.escape(source.substring(i, m.start)))
        ..write('(.+?)');
      names.add(m.group(1)!);
      i = m.end;
    }
    pattern
      ..write(RegExp.escape(source.substring(i)))
      ..write(r'$');
    re = RegExp(pattern.toString(), dotAll: true);
  }

  late final RegExp re;
  final names = <String>[];
  final String out;

  /// Literal characters: a template that says more wins over a shorter one that also matches.
  final int weight;

  String? apply(String text) {
    final m = re.firstMatch(text);
    if (m == null) return null;
    // A value can itself be English that has a translation ("{park}: {detail}"); names, plates and
    // amounts have none and pass through. Each value is shorter than the text, so this ends.
    final values = {for (var i = 0; i < names.length; i++) names[i]: tr(m.group(i + 1)!)};
    return fill(out, values);
  }
}

final _slot = RegExp(r'\{([a-zA-Z0-9_]+)\}');

String fill(String template, Map<String, Object?> values) =>
    template.replaceAllMapped(_slot, (m) => values.containsKey(m.group(1)) ? '${values[m.group(1)]}' : m.group(0)!);

final _templates = <Lang, List<_Template>>{};

List<_Template> _templatesOf(Lang l) => _templates[l] ??= [
  for (final e in _table(l).entries)
    if (e.key.contains('{')) _Template(e.key, e.value),
]..sort((a, b) => b.weight.compareTo(a.weight));

final _memo = <String, String>{};

String? _one(Lang l, String text) {
  final table = _table(l);
  final exact = table[text];
  if (exact != null) return exact;
  for (final t in _templatesOf(l)) {
    final out = t.apply(text);
    if (out != null) return out;
  }
  return null;
}

/// [text] in the app's language. Exact matches first, then templates ("{n} min ago"), then the
/// parts of "a · b · c" one by one. Text with no translation comes back as it is, so names,
/// plates, codes and amounts pass straight through.
///
/// With [args], [text] is itself a template: `tr('Pay {name}?', {'name': n})`.
String tr(String text, [Map<String, Object?>? args]) {
  final l = L10n.instance.lang;
  if (args != null) {
    final t = l == Lang.en ? null : _table(l)[text];
    return fill(t ?? text, args);
  }
  if (l == Lang.en || text.isEmpty) return text;
  final hit = _memo[text];
  if (hit != null) return hit;
  var out = _one(l, text);
  if (out == null && text.contains(' · ')) out = text.split(' · ').map((p) => _one(l, p) ?? p).join(' · ');
  out ??= text;
  // Countdowns and amounts make endless new strings; don't let the memo grow without bound.
  if (_memo.length > 4000) _memo.clear();
  return _memo[text] = out;
}

const _monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Oct" in the app's language (month 1-12).
String monthShort(int month) => tr(_monthsEn[month - 1]);
