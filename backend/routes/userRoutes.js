// /backend/routes/userRoutes.js

const express = require('express');
const { createUser, getUser } = require('../services/userService'); // 여기서 오류 많이 남
const router = express.Router();

router.post('/', async (req, res) => {
    try {
      console.log('📥 [POST /users] 받은 요청:', req.body); // 🔍 저장 전 로그
  
      await createUser({
        ...req.body,
        
      });
  
      res.status(201).json({ message: '✅ 유저 저장 완료' });
    } catch (err) {
      console.error('❌ [POST /users] 저장 실패:', err); // 🔥 에러 로그
      res.status(500).json({ error: err.message });
    }
  });
  

router.get('/:userId', async (req, res) => {
  try {
    const user = await getUser(req.params.userId);
    if (!user) return res.status(404).json({ error: '❌ 사용자 없음' });
    res.json(user);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
