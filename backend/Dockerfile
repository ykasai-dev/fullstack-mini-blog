# Node.js 22 の小さなイメージ（Alpine Linux）を使う
FROM node:22-alpine
WORKDIR /app

# 先に、依存パッケージのインストールに必要なファイルだけをコピーする
# （ソースコードだけを変えたときは、次の npm ci の結果を使い回せるので、ビルドが速くなる）
# prisma.config.ts と prisma/ は、npm ci の postinstall（prisma generate）が使う
COPY package.json package-lock.json prisma.config.ts ./
COPY prisma ./prisma
# イメージの npm は 10 なので、手元と同じ 11 に上げてから npm ci を実行する
# （npm 11 は、package.json の allowScripts で許可した Prisma のスクリプトだけを実行する。→ 3-2-4）
RUN npm install -g npm@11 && npm ci

# ソースコードをコピーして、TypeScript を JavaScript（dist/）にビルドする
COPY . .
RUN npm run build

EXPOSE 3001
# 開発用のモード（start:dev）ではなく、ビルドした JavaScript を node で直接実行する
CMD ["node", "dist/main.js"]
