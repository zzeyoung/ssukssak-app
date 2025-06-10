const express = require('express');
const router = express.Router();
const { signup } = require('../controllers/authController');
const { verifyToken } = require('../middlewares/authMiddleware');
const { logout } = require('../controllers/authController');

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
  res.json({
    message: '토큰 인증 성공!',
    user: req.user,
  });
});

// 🔁 구글 로그인 등 OAuth 리디렉션 처리 (필요 없다면 삭제 가능)
router.get('/callback', (req, res) => {
  res.send('OAuth 콜백 처리 라우트 (미구현)');
});

// routes/auth.js
router.post('/logout', logout);


module.exports = router;
