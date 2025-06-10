const express = require('express');
const router = express.Router();
const {
  saveHighlightAction,
  getHighlightHistory,
  getHighlightFolders,
  getPhotosByFolder // ✅ 폴더별 사진 불러오기
} = require('../controllers/highlightController');

// 🔹 사용자 스와이프 기록 저장
router.post('/action', saveHighlightAction);

// 🔹 사용자 스와이프 이력 조회
router.get('/history', getHighlightHistory);

// 🔹 사용자 맞춤 폴더 정렬 및 분류된 사진 목록 반환
router.get('/folders/:userId', getHighlightFolders);

// 🔹 폴더별 사진 불러오기 (스와이프 이력 반영 필터링)
router.get('/folders/:userId/photos/:folderName', getPhotosByFolder);

module.exports = router;
