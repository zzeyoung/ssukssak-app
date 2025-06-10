const express = require('express');
const { uploadGalleryMetadata } = require('../controllers/photoController');
const router = express.Router();

router.post('/metadata', uploadGalleryMetadata);

module.exports = router;
// swagger
/**
 * @swagger
 * /photo/gallery:
 *   post:
 *     summary: 갤러리 메타데이터 업로드
 *     description: 사용자가 갤러리 사진의 메타데이터를 업로드합니다.
 *     tags:
 *       - Photo
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - userId
 *               - photos
 *             properties:
 *               userId:
 *                 type: string
 *                 description: 사용자 ID
 *               photos:
 *                 type: array
 *                 items:
 *                   type: object
 *                   properties:
 *                     photoId:
 *                       type: string
 *                       description: 사진 ID
 *                     tags:
 *                       type: array
 *                       items:
 *                         type: string
 *                       description: 사진 태그들
 *                     score:
 *                       type: number
 *                       description: 사진 점수 (0-100)
 *     responses:
 *       200:
 *         description: 갤러리 메타데이터 업로드 성공
 */