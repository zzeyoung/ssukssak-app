// 📁 routes/prompts.js

const express = require('express');
const router = express.Router();
const { getInitialPrompts } = require('../controllers/promptsController');

// 🔹 [GET] /user/prompts/init
// ✅ 앱 최초 실행 시 사용자에게 제시할 프롬프트 태그 리스트 조회
// 프론트는 이 리스트를 기반으로 사용자가 관심 있는 태그를 선택하게 됨
router.get('/init', getInitialPrompts);

module.exports = router;
