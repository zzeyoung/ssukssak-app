const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');

const { signup, logout } = require('../controllers/authController');
const { verifyToken } = require('../middlewares/authMiddleware');
const { exchangeCodeForToken } = require('../services/cognitoService');
const { createUser } = require('../services/userService'); // 유저 생성 유틸

/**
 * @swagger
 * /auth/signup:
 *   post:
 *     summary: 회원가입
 *     description: 이메일과 비밀번호로 회원가입을 진행합니다.
 *     tags:
 *       - Auth
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *             properties:
 *               email:
 *                 type: string
 *               password:
 *                 type: string
 *     responses:
 *       201:
 *         description: 회원가입 성공
 *       400:
 *         description: 요청 오류
 *       500:
 *         description: 서버 오류
 */
router.post('/signup', signup);

/**
 * @swagger
 * /auth/me:
 *   get:
 *     summary: 액세스 토큰으로 사용자 정보 조회
 *     description: Authorization 헤더에 Bearer 액세스 토큰을 담아 요청하면, 해당 사용자의 정보를 반환합니다.
 *     tags:
 *       - Auth
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 토큰 인증 성공
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: 토큰 인증 성공!
 *                 user:
 *                   type: object
 *                   example:
 *                     sub: "29ae1458-b021-706f-45de-75279d5cdda1"
 *                     email: "user@example.com"
 *       401:
 *         description: 인증 실패 (토큰 누락 또는 유효하지 않음)
 */
router.get('/me', verifyToken, (req, res) => {
  const { sub, email, name } = req.user;
  res.json({
    userId: sub,     // ⭐ 여기를 추가
    email,
    name,
  });
});

/**
 * @swagger
 * /auth/callback:
 *   get:
 *     summary: Google OAuth 콜백
 *     description: Google 로그인 후 리디렉션된 콜백을 처리합니다.
 *     tags:
 *       - Auth
 *     parameters:
 *       - name: code
 *         in: query
 *         required: true
 *         description: 구글 OAuth 인가 코드
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: 로그인 성공 및 사용자 정보 반환
 *       400:
 *         description: 잘못된 요청
 *       500:
 *         description: 서버 오류
 */
router.get('/callback', async (req, res) => {
  const { code } = req.query;

  if (!code) {
    return res.status(400).json({ message: '❌ code 파라미터가 없습니다.' });
  }

  try {
    // 1. 코드 → 토큰 교환
    const tokenData = await exchangeCodeForToken(code);

    // 2. id_token 디코딩
    const decoded = jwt.decode(tokenData.id_token);

    // 3. 사용자 정보 저장 (없는 경우 생성)
    await createUser({
      userId: decoded.sub,
      email: decoded.email,
      nickname: decoded.name || `User-${decoded.sub.slice(0, 6)}`,
      picture: decoded.picture || null,
      provider: 'google',
    });

    // 4. 결과 반환 (또는 프론트 리디렉션 가능)
    res.status(200).json({
      message: '✅ OAuth 로그인 성공',
      access_token: tokenData.access_token,
      refresh_token: tokenData.refresh_token,
      expires_in: tokenData.expires_in,
      user: {
        sub: decoded.sub,
        email: decoded.email,
        name: decoded.name,
        picture: decoded.picture,
      },
    });
  } catch (err) {
    console.error('🛑 OAuth 콜백 처리 오류:', err.response?.data || err.message);
    res.status(500).json({ message: '서버 오류', detail: err.message });
  }
});

router.post('/logout', logout);

module.exports = router;
