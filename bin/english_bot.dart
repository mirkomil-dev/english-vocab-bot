import 'dart:io';
import 'dart:math';
import 'package:televerse/telegram.dart';
import 'package:televerse/televerse.dart';
import 'data.dart'; // Sening so'zlar bazang (en, uz, example kalitlari bilan)

// Foydalanuvchi ma'lumotlarini saqlash
Map<int, Map<String, int>> userStats = {};
const int totalQuestionsPerSession = 5; // Har bir test 5 ta savoldan iborat

void main() async {
  // 1. RENDER PORT XATOLIGI UCHUN TUZATMA
  // Render "Web Service" bo'lgani uchun portni eshitib turishi shart
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  server.listen((HttpRequest request) {
    request.response
      ..write('Bot is running!')
      ..close();
  });
  print('Server $port-portda ishlamoqda...');

  // 2. BOT TOKENNI OLISH
  final String botToken =
      Platform.environment['BOT_TOKEN'] ?? 'TOKENNI_RENDERDA_SOZLANG';
  Bot bot = Bot(botToken);

  // Asosiy menyu tugmalari
  var keyboard = ReplyKeyboardMarkup(
    keyboard: [
      [
        KeyboardButton(text: "📚 Yangi so'z"),
        KeyboardButton(text: "🧠 O'zimni sinash"),
      ],
      [KeyboardButton(text: "📊 Mening natijam")],
    ],
    resizeKeyboard: true,
  );

  // --- START BUYRUG'I ---
  bot.command('start', (ctx) async {
    await ctx.reply(
      "Salom, ${ctx.from?.firstName}! 🇬🇧\nIngliz tili so'zlarini o'rganishga tayyormisiz?\n\nPastdagi menyudan bo'limni tanlang:",
      replyMarkup: keyboard,
    );
  });

  // --- YANGI SO'Z VA AUDIO FUNKSIYASI ---
  bot.hears(RegExp(r"Yangi so'z"), (ctx) async {
    try {
      final random = Random();
      final word = wordsData[random.nextInt(wordsData.length)];

      String message =
          "🇬🇧 *English:* ${word['en']}\n"
          "🇺🇿 *O'zbekcha:* ${word['uz']}\n\n"
          "📝 *Example:* ${word['example']}";

      var inlineKeyboard = InlineKeyboardMarkup(
        inlineKeyboard: [
          [
            InlineKeyboardButton(
              text: "🔊 Talaffuzni eshitish",
              callbackData: "audio_${word['en']}",
            ),
          ],
        ],
      );

      await ctx.reply(
        message,
        replyMarkup: inlineKeyboard,
        parseMode: ParseMode.markdown,
      );
    } catch (e) {
      print("Xatolik: $e");
    }
  });
  // Audio callback query (Yangilangan versiya)
  bot.callbackQuery(RegExp(r"audio_.*"), (ctx) async {
    try {
      // audio_ dan keyin kelgan hamma narsani olamiz (substring ishlatish xavfsizroq)
      String word = ctx.callbackQuery!.data!.replaceFirst('audio_', '');

      // So'zni URL uchun xavfsiz shaklga keltiramiz (bo'shliqlar bo'lsa %20 qiladi)
      String encodedWord = Uri.encodeComponent(word);
      String audioUrl =
          "https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=en&q=$encodedWord";

      // Telegram-ga audioni yuboramiz
      await ctx.replyWithVoice(InputFile.fromUrl(audioUrl));

      await ctx.answerCallbackQuery(text: "Audio yuborildi 🎧");
    } catch (e) {
      print("AUDIO XATOLIGI: $e"); // Render Logs-da ko'rinadi
      await ctx.answerCallbackQuery(text: "Audio yuklab bo'lmadi ❌");
      await ctx.reply(
        "Kechirasiz, ushbu so'zning talaffuzini yuklashda xatolik yuz berdi. 😔",
      );
    }
  });

  // --- TEST TIZIMI FUNKSIYALARI ---

  // Savol yuborish uchun yordamchi funksiya
  Future<void> sendNextQuestion(
    Context ctx,
    int userId, {
    bool isEdit = false,
  }) async {
    final random = Random();
    final correctWord = wordsData[random.nextInt(wordsData.length)];

    List<Map<String, String>> shuffledWords = List.from(wordsData)..shuffle();
    shuffledWords.removeWhere((w) => w['en'] == correctWord['en']);

    List<String> options = [
      correctWord['en']!,
      shuffledWords[0]['en']!,
      shuffledWords[1]['en']!,
    ];
    options.shuffle();

    List<List<InlineKeyboardButton>> quizButtons = [];
    for (String option in options) {
      quizButtons.add([
        InlineKeyboardButton(
          text: option,
          callbackData: (option == correctWord['en'])
              ? "quiz_correct"
              : "quiz_wrong",
        ),
      ]);
    }

    int currentQ = userStats[userId]!['current_index']! + 1;
    String text =
        "❓ *$currentQ / $totalQuestionsPerSession savol*\n\n"
        "🇺🇿 '${correctWord['uz']}' so'zining inglizchasi qaysi?";

    if (isEdit) {
      await ctx.editMessageText(
        text,
        replyMarkup: InlineKeyboardMarkup(inlineKeyboard: quizButtons),
        parseMode: ParseMode.markdown,
      );
    } else {
      await ctx.reply(
        text,
        replyMarkup: InlineKeyboardMarkup(inlineKeyboard: quizButtons),
        parseMode: ParseMode.markdown,
      );
    }
  }

  // Testni boshlash
  bot.hears(RegExp(r"O'zimni sinash"), (ctx) async {
    final userId = ctx.from?.id ?? 0;
    userStats[userId] ??= {"correct": 0, "wrong": 0};
    userStats[userId]!["current_index"] = 0;
    userStats[userId]!["session_score"] = 0;

    await sendNextQuestion(ctx, userId);
  });

  // Test javoblarini qayta ishlash
  bot.callbackQuery(RegExp(r"quiz_correct|quiz_wrong"), (ctx) async {
    final userId = ctx.from?.id ?? 0;
    final answer = ctx.callbackQuery?.data;

    if (userStats[userId] == null) return;

    if (answer == "quiz_correct") {
      userStats[userId]!["session_score"] =
          (userStats[userId]!["session_score"] ?? 0) + 1;
      userStats[userId]!["correct"] = (userStats[userId]!["correct"] ?? 0) + 1;
      await ctx.answerCallbackQuery(text: "✅ To'g'ri!");
    } else {
      userStats[userId]!["wrong"] = (userStats[userId]!["wrong"] ?? 0) + 1;
      await ctx.answerCallbackQuery(text: "❌ Noto'g'ri!");
    }

    userStats[userId]!["current_index"] =
        (userStats[userId]!["current_index"] ?? 0) + 1;

    if (userStats[userId]!["current_index"]! < totalQuestionsPerSession) {
      await sendNextQuestion(ctx, userId, isEdit: true);
    } else {
      int score = userStats[userId]!["session_score"]!;
      await ctx.editMessageText(
        "🏁 *Test yakunlandi!*\n\nNatijangiz: $score / $totalQuestionsPerSession\n\nO'rganishda davom eting! ✨",
        parseMode: ParseMode.markdown,
      );
    }
  });

  // --- NATIJALAR ---
  bot.hears(RegExp(r"Mening natijam"), (ctx) async {
    final userId = ctx.from?.id ?? 0;
    final stats = userStats[userId] ?? {"correct": 0, "wrong": 0};

    String msg =
        "📊 *Statistikangiz:*\n\n"
        "✅ To'g'ri javoblar: ${stats["correct"]} ta\n"
        "❌ Xato javoblar: ${stats["wrong"]} ta";
    await ctx.reply(msg, parseMode: ParseMode.markdown);
  });

  bot.start();
}
