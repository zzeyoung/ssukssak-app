const express = require('express');
const router = express.Router();

const {
  classifyPhotoFolder,
  classifyAndSaveAll,
  getClassificationResult,
  getFolderSummary,
  getScreenshotSubfolders,
  getPhotosByFolder
} = require('../controllers/classifyController');

// 🔹 [POST] 단일 사진 분류
//    예: /classify (tags + filename 등 기반으로 폴더명 판단)
router.post('/', classifyPhotoFolder);

// 🔹 [POST] 여러 사진 분류 결과 저장
//    예: /classify/save-all (배치 저장용)
router.post('/save-all', classifyAndSaveAll);

// 🔹 [GET] 분류 결과 전체 조회
//    예: /classify/result?userId=user123
router.get('/result', getClassificationResult);

// 🔹 [GET] 스크린샷 하위 폴더 자동 분류 결과 조회
//    예: /classify/screenshots/user123
router.get('/screenshots/:userId', getScreenshotSubfolders);

// 🔹 [GET] 폴더 요약 (썸네일, 개수, 예상 확보 용량 등)
//    예: /classify/folder-summary/user123
router.get('/folder-summary/:userId', getFolderSummary);

router.get('/folder/:userId/:folderName', getPhotosByFolder);


module.exports = router;
