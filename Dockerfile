
FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart pub get --offline
RUN dart compile exe bin/english_bot.dart -o bin/english_bot

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/english_bot /app/bin/

CMD ["/app/bin/english_bot"]
