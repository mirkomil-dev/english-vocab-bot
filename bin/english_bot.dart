import 'dart:io';
import 'dart:math';
import 'package:televerse/telegram.dart';
import 'package:televerse/televerse.dart';
import 'package:http/http.dart' as http;
import 'data.dart';

// Statistikani saqlash uchun
Map<int, Map<String, int>> userStats = {};
const int totalQuestionsPerSession = 5;

void main() async {
  // 1. RENDER VA CRON-JOB UCHUN SERVER (UYG'OTISH TIZIMI)
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);

  server.listen((HttpRequest req) {
    // Cron-job.org so'rov yuborganida bizga logda ko'rinadi
    print("Ping qabul qilindi: ${DateTime.now()} - Bot uyg'oq!");

    req.response
      ..statusCode = HttpStatus.ok
      ..write('Bot is live and awake!')
      ..close();
  });

  print('Server $port-portda ishlamoqda...');

  // 2. BOT TOKENNI OLISH
  final String botToken =
      Platform.environment['BOT_TOKEN'] ?? 'TOKEN_NI_RENDERDA_YAZING';
  Bot bot = Bot(botToken);

  // ASOSIY TUGMALAR
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
      "Salom Mirkomil! 🇬🇧 Bot uyg'oq va xizmatingizda.",
      replyMarkup: mainKeyboard,
    );
  });

  // --- AUDIO TALAFUZ QISMI ---
  bot.callbackQuery(RegExp(r"audio_.*"), (ctx) async {
    try {
      String word = ctx.callbackQuery!.data!.replaceFirst('audio_', '');
      String url =
          "https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=en&q=${Uri.encodeComponent(word)}";

      var response = await http.get(
        Uri.parse(url),
        headers: {"User-Agent": "Mozilla/5.0"},
      );
      if (response.statusCode == 200) {
        await ctx.replyWithVoice(
          InputFile.fromBytes(response.bodyBytes, name: "$word.mp3"),
        );
      }
      await ctx.answerCallbackQuery();
    } catch (e) {
      print("Audio xatosi: $e");
      await ctx.answerCallbackQuery(text: "Xatolik yuz berdi ❌");
    }
  });

  // --- YANGI SO'Z BERISH ---
  bot.hears(RegExp(r"Yangi so'z"), (ctx) async {
    final word = wordsData[Random().nextInt(wordsData.length)];
    String msg =
        "🇬🇧 *English:* ${word['en']}\n🇺🇿 *Uzbek:* ${word['uz']}\n\n📝 *Example:* ${word['example']}";
    var kb = InlineKeyboardMarkup(
      inlineKeyboard: [
        [
          InlineKeyboardButton(
            text: "🔊 Eshitish",
            callbackData: "audio_${word['en']}",
          ),
        ],
      ],
    );
    await ctx.reply(msg, replyMarkup: kb, parseMode: ParseMode.markdown);
  });

  // --- O'ZIMNI SINASH (TEST) ---
  bot.hears(RegExp(r"O'zimni sinash"), (ctx) async {
    final userId = ctx.from?.id ?? 0;
    userStats[userId] = {
      "correct": 0,
      "wrong": 0,
      "current_index": 0,
      "score": 0,
    };
    await sendNextQuestion(ctx, userId);
  });

  bot.callbackQuery(RegExp(r"quiz_.*"), (ctx) async {
    final userId = ctx.from?.id ?? 0;
    if (userStats[userId] == null) return;

    if (ctx.callbackQuery?.data == "quiz_correct") {
      userStats[userId]!["score"] = userStats[userId]!["score"]! + 1;
      userStats[userId]!["correct"] = userStats[userId]!["correct"]! + 1;
    } else {
      userStats[userId]!["wrong"] = userStats[userId]!["wrong"]! + 1;
    }

    userStats[userId]!["current_index"] =
        userStats[userId]!["current_index"]! + 1;

    if (userStats[userId]!["current_index"]! < totalQuestionsPerSession) {
      await sendNextQuestion(ctx, userId, isEdit: true);
    } else {
      await ctx.editMessageText(
        "🏁 Tugadi! Ball: ${userStats[userId]!["score"]} / $totalQuestionsPerSession",
      );
    }
    await ctx.answerCallbackQuery();
  });

  // --- STATISTIKA ---
  bot.hears(RegExp(r"Mening natijam"), (ctx) async {
    final stats = userStats[ctx.from?.id] ?? {"correct": 0, "wrong": 0};
    await ctx.reply(
      "📊 Jami:\n✅ To'g'ri: ${stats["correct"]}\n❌ Xato: ${stats["wrong"]}",
    );
  });

  bot.start();
}

// SAVOL YUBORISH FUNKSIYASI
Future<void> sendNextQuestion(
  Context ctx,
  int userId, {
  bool isEdit = false,
}) async {
  final correct = wordsData[Random().nextInt(wordsData.length)];
  List<String> options = [
    correct['en']!,
    wordsData[Random().nextInt(wordsData.length)]['en']!,
    wordsData[Random().nextInt(wordsData.length)]['en']!,
  ]..shuffle();

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

  String text = "❓ '${correct['uz']}' inglizcha nima?";
  if (isEdit)
    await ctx.editMessageText(text, replyMarkup: kb);
  else
    await ctx.reply(text, replyMarkup: kb);
}
