// services/cognitoService.js
require('dotenv').config();
const axios = require('axios');
const qs = require('qs');

exports.exchangeCodeForToken = async (code) => {
  const {
    COGNITO_CLIENT_ID: CLIENT_ID,
    CLIENT_SECRET,
    REDIRECT_URI,
    TOKEN_ENDPOINT
  } = process.env;

  const basicAuth = Buffer.from(`${CLIENT_ID}:${CLIENT_SECRET}`).toString('base64');

  try {
    const response = await axios.post(
      TOKEN_ENDPOINT,
      qs.stringify({
        grant_type: 'authorization_code',
        code,
        client_id: CLIENT_ID,
        redirect_uri: REDIRECT_URI,
        scope: 'openid profile email', // ✅ 반드시 포함되어야 id_token 발급됨
      }),
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': `Basic ${basicAuth}`, // ✅ 필수
        },
      }
    );

    return response.data;
  } catch (err) {
    console.error('❌ 토큰 교환 실패:', err.response?.data || err.message);
    throw err;
  }
};
