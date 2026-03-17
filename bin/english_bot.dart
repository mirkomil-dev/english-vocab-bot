import 'dart:io';
import 'dart:math';
import 'package:televerse/telegram.dart';
import 'package:televerse/televerse.dart';
import 'package:http/http.dart' as http;
import 'data.dart'; // data.dart faylingizda wordsData borligiga ishonch hosil qiling

// 1. GLOBAL O'ZGARUVCHILAR
Map<int, Map<String, int>> userStats = {};
const int totalQuestionsPerSession = 5;

void main() async {
  // RENDER PORT FIX
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  server.listen(
    (HttpRequest req) => req.response
      ..write('Bot is live!')
      ..close(),
  );

  final String botToken =
      Platform.environment['BOT_TOKEN'] ?? 'TOKENNI_RENDERDA_SOZLANG';
  Bot bot = Bot(botToken);

  // ASOSIY MENYU
  var mainKeyboard = ReplyKeyboardMarkup(
    keyboard: [
      [
        KeyboardButton(text: "📚 Yangi so'z"),
        KeyboardButton(text: "🧠 O'zimni sinash"),
      ],
      [KeyboardButton(text: "📊 Mening natijam")],
    ],
    resizeKeyboard: true,
  );

  bot.command('start', (ctx) async {
    await ctx.reply(
      "Salom Mirkomil! Ingliz tili botiga xush kelibsiz. 🇬🇧",
      replyMarkup: mainKeyboard,
    );
  });

  // --- YANGI SO'Z VA AUDIO ---
  bot.hears(RegExp(r"Yangi so'z"), (ctx) async {
    final word = wordsData[Random().nextInt(wordsData.length)];
    String msg =
        "🇬🇧 *English:* ${word['en']}\n🇺🇿 *Uzbek:* ${word['uz']}\n\n📝 *Example:* ${word['example']}";
    var kb = InlineKeyboardMarkup(
      inlineKeyboard: [
        [
          InlineKeyboardButton(
            text: "🔊 Talaffuz",
            callbackData: "audio_${word['en']}",
          ),
        ],
      ],
    );
    await ctx.reply(msg, replyMarkup: kb, parseMode: ParseMode.markdown);
  });

  bot.callbackQuery(RegExp(r"audio_.*"), (ctx) async {
    try {
      String word = ctx.callbackQuery!.data!.split('_')[1];
      var response = await http.get(
        Uri.parse(
          "https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=en&q=$word",
        ),
        headers: {"User-Agent": "Mozilla/5.0"},
      );
      if (response.statusCode == 200) {
        await ctx.replyWithVoice(
          InputFile.fromBytes(response.bodyBytes, name: "$word.mp3"),
        );
      }
      await ctx.answerCallbackQuery();
    } catch (e) {
      await ctx.answerCallbackQuery(text: "Xato yuz berdi ❌");
    }
  });

  // --- 🧠 O'ZIMNI SINASH (TEST MANTIQI) ---
  bot.hears(RegExp(r"O'zimni sinash"), (ctx) async {
    final userId = ctx.from?.id ?? 0;
    // Har safar yangi test boshlanganda hisobni nolga tushiramiz
    userStats[userId] = {
      "correct": userStats[userId]?["correct"] ?? 0, // Umumiy to'g'rilar qoladi
      "wrong": userStats[userId]?["wrong"] ?? 0, // Umumiy xatolar qoladi
      "session_score": 0, // Joriydagi ball 0
      "current_index": 0, // Nechanchi savolligi 0
    };
    await sendNextQuestion(ctx, userId);
  });

  bot.callbackQuery(RegExp(r"quiz_.*"), (ctx) async {
    final userId = ctx.from?.id ?? 0;
    if (userStats[userId] == null) return;

    final data = ctx.callbackQuery!.data;

    // Javobni tekshirish
    if (data == "quiz_correct") {
      userStats[userId]!["session_score"] =
          userStats[userId]!["session_score"]! + 1;
      userStats[userId]!["correct"] = userStats[userId]!["correct"]! + 1;
      await ctx.answerCallbackQuery(text: "✅ To'g'ri!");
    } else {
      userStats[userId]!["wrong"] = userStats[userId]!["wrong"]! + 1;
      await ctx.answerCallbackQuery(text: "❌ Noto'g'ri!");
    }

    // Savol raqamini oshirish
    userStats[userId]!["current_index"] =
        userStats[userId]!["current_index"]! + 1;

    // Keyingi savolga o'tish yoki tugatish
    if (userStats[userId]!["current_index"]! < totalQuestionsPerSession) {
      await sendNextQuestion(ctx, userId, isEdit: true);
    } else {
      int finalScore = userStats[userId]!["session_score"]!;
      await ctx.editMessageText(
        "🏁 *Test yakunlandi!*\n\nSiz 5 tadan *$finalScore* ta savolga to'g'ri javob berdingiz.",
        parseMode: ParseMode.markdown,
      );
    }
  });

  // --- 📊 MENING NATIJAM ---
  bot.hears(RegExp(r"Mening natijam"), (ctx) async {
    final userId = ctx.from?.id ?? 0;
    final stats = userStats[userId] ?? {"correct": 0, "wrong": 0};

    String msg =
        "📊 *Sizning statistikangiz:*\n\n"
        "✅ Jami to'g'ri javoblar: ${stats['correct']}\n"
        "❌ Jami xato javoblar: ${stats['wrong']}\n\n"
        "O'rganishda davom eting! 💪";
    await ctx.reply(msg, parseMode: ParseMode.markdown);
  });

  bot.start();
}

// SAVOL YUBORISH FUNKSIYASI
Future<void> sendNextQuestion(
  Context ctx,
  int userId, {
  bool isEdit = false,
}) async {
  final random = Random();
  final correct = wordsData[random.nextInt(wordsData.length)];

  // Variantlarni aralashtirish
  List<Map<String, String>> shuffled = List.from(wordsData)..shuffle();
  shuffled.removeWhere((w) => w['en'] == correct['en']);

  List<String> options = [
    correct['en']!,
    shuffled[0]['en']!,
    shuffled[1]['en']!,
  ];
  options.shuffle();

  var kb = InlineKeyboardMarkup(
    inlineKeyboard: [
      for (var opt in options)
        [
          InlineKeyboardButton(
            text: opt,
            callbackData: opt == correct['en'] ? "quiz_correct" : "quiz_wrong",
          ),
        ],
    ],
  );

  int qNumber = userStats[userId]!["current_index"]! + 1;
  String txt =
      "❓ *$qNumber / $totalQuestionsPerSession savol*\n\n🇺🇿 '${correct['uz']}' so'zining inglizchasi nima?";

  if (isEdit) {
    await ctx.editMessageText(
      txt,
      replyMarkup: kb,
      parseMode: ParseMode.markdown,
    );
  } else {
    await ctx.reply(txt, replyMarkup: kb, parseMode: ParseMode.markdown);
  }
}
