FROM ghcr.io/cirruslabs/flutter:3.38.9 AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./

RUN flutter pub get

COPY . .

RUN flutter build web --release --no-source-maps

FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
