FROM node:22-alpine
WORKDIR /app

# 先に依存パッケージを入れる（ソースコードだけを変えたときに、この結果を使い回せる）
COPY package.json package-lock.json ./
RUN npm ci

COPY . .

# ビルドのときに受け取る値（compose の build.args から渡す）
# ARG の値は、次の RUN の中では環境変数として読めるので、npm run build が埋め込む
ARG NEXT_PUBLIC_API_URL
ARG NEXT_PUBLIC_APP_URL
ARG NEXT_PUBLIC_COGNITO_DOMAIN
ARG NEXT_PUBLIC_COGNITO_CLIENT_ID
RUN npm run build

EXPOSE 3000
# 本番用のサーバー（next start）で起動する
CMD ["npm", "run", "start"]
