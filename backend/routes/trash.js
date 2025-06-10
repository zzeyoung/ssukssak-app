// routes/trash.js
const express = require('express');
const router = express.Router();
const { addToTrash, getTrash, restorePhotos } = require('../controllers/trashController');
const { deletePhotos } = require('../controllers/trashController');


router.post('/', addToTrash);
router.get('/:userId', getTrash);
router.delete('/restore', restorePhotos); // ✅ 추가
router.delete('/permanent', deletePhotos);

module.exports = router;
//swagger
/**
 * @swagger
 * /trash:
 *   post:
 *     summary: 휴지통에 사진 추가
 *     description: 사용자가 삭제한 사진을 휴지통에 저장합니다.
 *     tags:
 *       - Trash
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - userId
 *               - photoId
 *               - source
 *             properties:
 *               userId:
 *                 type: string
 *               photoId:
 *                 type: string
 *               source:
 *                 type: string
 *               tags:
 *                 type: array
 *                 items:
 *                   type: string
 *               score:
 *                 type: number
 *     responses:
 *       200:
 *         description: 휴지통에 저장 성공
 *       400:
 *         description: 요청 오류 (필수 파라미터 누락 등)
 */
/**
 * @swagger
 * /trash/{userId}:
 *   get:
 *     summary: 휴지통에서 사진 조회
 *     description: 특정 사용자의 휴지통에 저장된 사진들을 조회합니다.
 *     tags:
 *       - Trash
 *     parameters:
 *       - in: path
 *         name: userId
 *         required: true
 *         description: 사용자 ID
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: 휴지통 사진 목록 반환
 *       400:
 *         description: 요청 오류 (userId 누락 등)
 */