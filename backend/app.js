// /backend/app.js

// 🌱 환경변수 로딩
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '/.env') }); // 최상위 .env 사용

// 📦 기본 모듈
const express = require('express');
const axios = require('axios');
const qs = require('qs');
const jwt = require('jsonwebtoken');

// 🔧 서비스 & 설정
const { createUser } = require('./services/userService');

// 📘 Swagger
const swaggerUi = require('swagger-ui-express');
const YAML = require('yamljs');
const swaggerDocument = YAML.load(path.join(__dirname, '../docs/swagger.yaml'));

// ✅ 환경 변수 확인 로그
console.log('✅ ENV 확인:', process.env.NAVER_CLIENT_ID, process.env.AWS_ACCESS_KEY_ID);

// 🔐 Cognito 설정값
const CLIENT_ID = process.env.COGNITO_CLIENT_ID;
const CLIENT_SECRET = process.env.CLIENT_SECRET;
const REDIRECT_URI = 'http://localhost:3000/callback';
const TOKEN_URL = 'https://ap-southeast-2cnp2bd9aj.auth.ap-southeast-2.amazoncognito.com/oauth2/token';

const app = express();
app.use(express.json());

// ✅ 기본 상태 확인 라우터
app.get('/', (req, res) => {
  res.send('<h2>✅ 서버 실행 중 - /callback으로 리디렉션될 예정</h2>');
});

// ✅ Cognito Callback 처리 라우터
app.get('/callback', async (req, res) => {
  const code = req.query.code;
  if (!code) return res.status(400).send('❌ code가 없습니다.');

  const basicAuth = Buffer.from(`${CLIENT_ID}:${CLIENT_SECRET}`).toString('base64');

  try {
    const response = await axios.post(TOKEN_URL, qs.stringify({
      grant_type: 'authorization_code',
      code,
      client_id: CLIENT_ID,
      redirect_uri: REDIRECT_URI,
    }), {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': `Basic ${basicAuth}`
      }
    });

    const { access_token, id_token, refresh_token, expires_in } = response.data;
    const decoded = jwt.decode(id_token);

    await createUser({
      userId: decoded.sub,
      email: decoded.email,
      nickname: decoded.name || '익명',
    });

    res.send(`
      <h2>🎉 로그인 성공 & 사용자 DB 저장 완료!</h2>
      <p><strong>access_token:</strong> ${access_token}</p>
      <p><strong>id_token:</strong> ${id_token}</p>
      <p><strong>refresh_token:</strong> ${refresh_token}</p>
      <p><strong>expires_in:</strong> ${expires_in}초</p>
    `);
  } catch (err) {
    console.error('❌ 토큰 요청 실패:', err.response?.data || err.message);
    res.status(500).send(`
      <h2>❌ 토큰 요청 실패</h2>
      <pre>${JSON.stringify(err.response?.data || err.message, null, 2)}</pre>
    `);
  }
});

// ✅ 라우터 등록
app.use('/auth', require('./routes/auth'));
app.use('/users', require('./routes/userRoutes'));
app.use('/trash', require('./routes/trash'));
app.use('/report', require('./routes/report'));
app.use('/photos', require('./routes/photoRoutes'));

// ✅ 개인화 관련 라우터
app.use('/user/preferences', require('./routes/preferences'));
app.use('/user/prompts', require('./routes/prompts'));
app.use('/classify', require('./routes/classify'));
app.use('/highlight', require('./routes/highlight'));

// ✅ Swagger 문서
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocument));

// ✅ 서버 시작
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Server running on http://localhost:${PORT}`);
});
