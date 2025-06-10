// controllers/authController.js
const { signUpWithCognito } = require('../services/cognitoService');

exports.signup = async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ message: '이메일과 비밀번호는 필수입니다.' });
  }

  try {
    const result = await signUpWithCognito(email, password);
    return res.status(201).json({ message: '회원가입 성공!', data: result });
  } catch (err) {
    console.error('회원가입 실패:', err);
    return res.status(500).json({ message: '회원가입 실패', error: err.message });
  }
};

exports.logout = async (req, res) => {
    // 실제로는 클라이언트에서 토큰만 삭제하면 됩니다
    res.status(200).json({ message: '🧼 로그아웃 성공! 토큰 삭제 필요' });
  };