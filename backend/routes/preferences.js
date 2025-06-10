const express = require('express');
const router = express.Router();

const {
  saveUserPreferences,   // ✅ 사용자 프롬프트(취향 태그) 저장 컨트롤러
  getUserPreferences     // ✅ 사용자 프롬프트 조회 컨트롤러
} = require('../controllers/preferencesController');

// 🔹 [POST] /user/preferences
// ✅ 사용자가 선택한 초기 프롬프트 태그를 저장 (예: ["음식", "여행"])
router.post('/', saveUserPreferences);

// 🔹 [GET] /user/preferences?userId=user123
// ✅ 특정 사용자의 저장된 프롬프트 태그를 조회
router.get('/', getUserPreferences);

module.exports = router;
