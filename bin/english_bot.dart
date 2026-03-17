import 'dart:math';
import 'package:televerse/telegram.dart';
import 'package:televerse/televerse.dart';
import 'data.dart'; // Sening so'zlar bazang

// Xotira (kompyuter adashmasligi uchun inglizcha kalit so'zlar ishlatamiz)
Map<int, Map<String, int>> userStats = {};

void main() {
  // Tokeningni qo'yishni unutma!
  final String botToken = '8516935048:AAHWmncHUnaJYyCyIJ9x0Xs5-zzt6s_Ztqg';

  Bot bot = Bot(botToken);

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

  bot.command('start', (ctx) async {
    await ctx.reply(
      "Salom! Men ingliz tili so'z boyligini oshiruvchi botman.\nQaysi bo'limni tanlaysan?",
      replyMarkup: keyboard,
    );
  });

  bot.hears(RegExp(r"Yangi so'z"), (ctx) async {
    try {
      final random = Random();
      final word = wordsData[random.nextInt(wordsData.length)];
      String message =
          "🇬🇧 Inglizcha: ${word['en']}\n🇺🇿 O'zbekcha: ${word['uz']}\n📝 Misol: ${word['example']}";
      String audioUrl =
          "https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=en&q=${word['en']}";

      var inlineKeyboard = InlineKeyboardMarkup(
        inlineKeyboard: [
          [InlineKeyboardButton(text: "🔊 Talaffuzni eshitish", url: audioUrl)],
        ],
      );
      await ctx.reply(message, replyMarkup: inlineKeyboard);
    } catch (e) {
      print("Yangi so'z qismida xatolik: $e");
    }
  });

  bot.hears(RegExp(r"O'zimni sinash"), (ctx) async {
    try {
      final random = Random();
      final correctWord = wordsData[random.nextInt(wordsData.length)];

      List<Map<String, String>> shuffledWords = List.from(wordsData)..shuffle();
      shuffledWords.removeWhere((w) => w['en'] == correctWord['en']);

      List<String> options = [
        correctWord['en']!,
        shuffledWords[0]['en']!,
        shuffledWords[1]['en']!,
        shuffledWords[2]['en']!,
      ];
      options.shuffle();

      List<List<InlineKeyboardButton>> quizButtons = [];
      for (String option in options) {
        String callbackValue = (option == correctWord['en'])
            ? "correct"
            : "wrong";
        quizButtons.add([
          InlineKeyboardButton(text: option, callbackData: callbackValue),
        ]);
      }

      await ctx.reply(
        "🤔 🇺🇿 '${correctWord['uz']}' so'zining inglizchasi qaysi?",
        replyMarkup: InlineKeyboardMarkup(inlineKeyboard: quizButtons),
      );
    } catch (e) {
      print("Test qismida xatolik: $e");
    }
  });

  // JAVOBLARNI HISOBLASH (Qayta ishlangan xavfsiz qism)
  bot.callbackQuery(RegExp(r"correct|wrong"), (ctx) async {
    try {
      final answer = ctx.callbackQuery?.data;
      final userId = ctx.from?.id ?? 0;

      if (!userStats.containsKey(userId)) {
        userStats[userId] = {"correct": 0, "wrong": 0};
      }

      if (answer == "correct") {
        userStats[userId]!["correct"] =
            (userStats[userId]!["correct"] ?? 0) + 1;
        await ctx.answerCallbackQuery(
          text: "✅ Barakalla! To'g'ri topdingiz!",
          showAlert: true,
        );
      } else {
        userStats[userId]!["wrong"] = (userStats[userId]!["wrong"] ?? 0) + 1;
        await ctx.answerCallbackQuery(
          text: "❌ Noto'g'ri javob. Boshqasini sinab ko'ring.",
          showAlert: true,
        );
      }
    } catch (e) {
      print("Javobni saqlashda xatolik: $e");
    }
  });

  // STATISTIKANI KO'RSATISH
  bot.hears(RegExp(r"Mening natijam"), (ctx) async {
    try {
      final userId = ctx.from?.id ?? 0;
      final stats = userStats[userId] ?? {"correct": 0, "wrong": 0};

      String msg =
          "📊 Sening kunlik natijalaring:\n\n"
          "✅ To'g'ri javoblar: ${stats["correct"]} ta\n"
          "❌ Xato javoblar: ${stats["wrong"]} ta\n\n"
          "O'rganishda davom etamiz! 💪";
      await ctx.reply(msg);
    } catch (e) {
      print("Natijani ko'rsatishda xatolik: $e");
    }
  });

  bot.start();
  print("Bot muvaffaqiyatli ishga tushdi, xatolar himoyalangan...");
}
