import 'dart:io';
import 'dart:math';
import 'package:televerse/telegram.dart';
import 'package:televerse/televerse.dart';
import 'package:http/http.dart' as http; // Yangi va oson HTTP paketi
import 'data.dart';

Map<int, Map<String, int>> userStats = {};
const int totalQuestionsPerSession = 5;

void main() async {
  // 1. RENDER PORT FIX
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  server.listen((HttpRequest request) {
    request.response
      ..write('Bot is running!')
      ..close();
  });

  // 2. BOT SOZLAMALARI
  final String botToken =
      Platform.environment['BOT_TOKEN'] ?? 'TOKEN_NI_RENDERDA_SOZLANG';
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
      "Salom, ${ctx.from?.firstName}! 🇬🇧 Boshlaymizmi?",
      replyMarkup: keyboard,
    );
  });

  // --- AUDIO YUKLASH (YANGI VA ISHONCHLI USUL) ---
  bot.callbackQuery(RegExp(r"audio_.*"), (ctx) async {
    try {
      String word = ctx.callbackQuery!.data!.replaceFirst('audio_', '');
      String encodedWord = Uri.encodeComponent(word);
      String audioUrl =
          "https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=en&q=$encodedWord";

      // 'http' paketi orqali audioni osongina yuklaymiz
      final response = await http.get(
        Uri.parse(audioUrl),
        headers: {"User-Agent": "Mozilla/5.0"},
      );

      if (response.statusCode == 200) {
        await ctx.replyWithVoice(
          InputFile.fromBytes(response.bodyBytes, name: "$word.mp3"),
        );
        await ctx.answerCallbackQuery(text: "Audio yuborildi 🎧");
      } else {
        await ctx.answerCallbackQuery(text: "Ovoz topilmadi ❌");
      }
    } catch (e) {
      await ctx.answerCallbackQuery(text: "Xatolik yuz berdi.");
    }
  });

  // --- SAVOL-JAVOB VA TEST QISMI ---
  bot.hears(RegExp(r"Yangi so'z"), (ctx) async {
    final random = Random();
    final word = wordsData[random.nextInt(wordsData.length)];
    String msg =
        "🇬🇧 *English:* ${word['en']}\n🇺🇿 *O'zbekcha:* ${word['uz']}\n\n📝 *Example:* ${word['example']}";
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

  // Test funksiyasi (avvalgi mantiq bo'yicha)
  bot.hears(RegExp(r"O'zimni sinash"), (ctx) async {
    final userId = ctx.from?.id ?? 0;
    userStats[userId] = {
      "correct": 0,
      "wrong": 0,
      "current_index": 0,
      "session_score": 0,
    };
    await sendNextQuestion(ctx, userId);
  });

  // Test callback query handler va statistikani shu yerda davom ettirishingiz mumkin...
  // (Yuqoridagi kodni to'liq qilib yozgan edik, asosiysi HttpClient xatosi shu yerda hal bo'ldi)

  bot.start();
}

// Keyingi savolni yuborish funksiyasi (xuddi avvalgidek)
Future<void> sendNextQuestion(
  Context ctx,
  int userId, {
  bool isEdit = false,
}) async {
  // ... (Avvalgi yozgan sendNextQuestion kodingizni shu yerga qo'ysangiz bo'ladi)
}
