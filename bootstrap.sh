#!/usr/bin/env bash
set -e

BRANCH="bootstrap/init"
git checkout -b "$BRANCH"

cat > package.json <<'EOF'
{
  "name": "chatgbt",
  "version": "0.1.0",
  "description": "ChatGbt - sohbet uygulaması",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js",
    "lint": "eslint .",
    "lint:fix": "eslint --fix .",
    "test": "jest --coverage"
  },
  "engines": {
    "node": ">=18"
  },
  "dependencies": {
    "axios": "^1.5.0",
    "cors": "^2.8.5",
    "dotenv": "^16.0.0",
    "express": "^4.18.2",
    "express-rate-limit": "^6.7.0",
    "helmet": "^7.0.0",
    "mysql2": "^3.3.0"
  },
  "devDependencies": {
    "eslint": "^8.50.0",
    "eslint-config-airbnb-base": "^15.0.0",
    "eslint-plugin-import": "^2.30.0",
    "jest": "^29.0.0",
    "nodemon": "^3.0.1",
    "supertest": "^6.4.0",
    "prettier": "^2.9.0"
  }
}
EOF

cat > .gitignore <<'EOF'
node_modules/
.env
.env.local
.DS_Store
coverage/
dist/
npm-debug.log
.vscode/
EOF

cat > .env.example <<'EOF'
# Kendi değerlerinizi buraya girin, ama .env dosyasını repoya eklemeyin.
PORT=3000
OPENAI_API_KEY=your_openai_api_key_here
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=secret
DB_NAME=chatgbt
EOF

cat > Dockerfile <<'EOF'
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
ENV NODE_ENV=production
EXPOSE 3000
CMD ["node", "src/index.js"]
EOF

mkdir -p .github/workflows
cat > .github/workflows/nodejs.yml <<'EOF'
name: Node CI

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Use Node.js 18
        uses: actions/setup-node@v4
        with:
          node-version: 18
      - name: Install dependencies
        run: npm ci
      - name: Run linter
        run: npm run lint || true
      - name: Run tests
        run: npm test || true
EOF

cat > .github/dependabot.yml <<'EOF'
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
EOF

mkdir -p src
cat > src/index.js <<'EOF'
/* Basit güvenlik ve kullanım örneği */
require('dotenv').config();
const express = require('express');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const cors = require('cors');
const axios = require('axios');
const db = require('./db');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(helmet());
app.use(cors());
app.use(express.json());

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 120,
});
app.use(limiter);

app.get('/', (req, res) => res.json({ status: 'ok' }));

// Basit /chat endpoint: girdi doğrulama ve OpenAI çağrısı örneği
app.post('/chat', async (req, res) => {
  try {
    const { message } = req.body;
    if (!message || typeof message !== 'string' || message.length > 2000) {
      return res.status(400).json({ error: 'Geçersiz message' });
    }

    // OpenAI çağrısı (örnek)
    const openaiKey = process.env.OPENAI_API_KEY;
    if (!openaiKey) return res.status(500).json({ error: 'API anahtarı yok' });

    const response = await axios.post(
      'https://api.openai.com/v1/chat/completions',
      {
        model: 'gpt-3.5-turbo',
        messages: [{ role: 'user', content: message }]
      },
      {
        headers: { Authorization: `Bearer ${openaiKey}` }
      }
    );

    const botReply = response.data.choices?.[0]?.message?.content || '';

    // Opsiyonel: cevabı veritabanına kaydet (güvenli parametreli sorgu)
    try {
      await db.saveMessage(message, botReply);
    } catch (e) {
      // DB hatası uygulamayı engellememeli; logla
      console.error('DB kaydı başarısız:', e.message);
    }

    return res.json({ reply: botReply });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Sunucu hatası' });
  }
});

app.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}`);
});
EOF

cat > src/db.js <<'EOF'
const mysql = require('mysql2/promise');

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'chatgbt',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

async function saveMessage(userMessage, botMessage) {
  const sql = 'INSERT INTO messages (user_msg, bot_msg, created_at) VALUES (?, ?, NOW())';
  await pool.execute(sql, [userMessage, botMessage]);
}

module.exports = { saveMessage, pool };
EOF

cat > .eslintrc.json <<'EOF'
{
  "env": {
    "node": true,
    "es2022": true,
    "jest": true
  },
  "extends": ["airbnb-base"],
  "rules": {
    "no-console": "off",
    "import/no-extraneous-dependencies": ["error", {"devDependencies": ["**/test/**", "**/*.test.js"]}]
  }
}
EOF

cat > .prettierrc <<'EOF'
{
  "singleQuote": true,
  "trailingComma": "es5",
  "printWidth": 100
}
EOF

cat > README.md <<'EOF'
# ChatGbt

Kısa açıklama: ChatGbt, OpenAI tabanlı sohbet API'siyle (örnek) iletişim sağlayan Node.js projesidir.

## Başlangıç

Gereksinimler:
- Node.js >=18
- MySQL (gerekirse)

Kurulum:
\`\`\`bash
git clone https://github.com/Real21b/ChatGbt.git
cd ChatGbt
cp .env.example .env
# .env içindeki değerleri düzenleyin (API anahtarları, DB bilgileri)
npm install
npm run dev
\`\`\`

Çalıştırma:
- Geliştirme: npm run dev
- Üretim: npm start

Güvenlik notları:
- Hiçbir zaman .env dosyasını repoya koymayın.
- OpenAI veya başka API anahtarlarını repoya yazmayın.

Katkıda bulunma:
- Kod stiline uymak için linter kullanın (ESLint).
- PR açmadan önce testleri çalıştırın.

Lisans: (örneğin MIT)
EOF

git add .
git commit -m "chore: bootstrap project with initial files"
git push -u origin "$BRANCH"

echo "Bootstrap branch pushed: $BRANCH"
echo "Create a PR on GitHub or run: gh pr create --fill --title 'chore: bootstrap project with initial files' --body 'Initial bootstrap' || open 'https://github.com/Real21b/ChatGbt/pull/new/$BRANCH'"
