// routes/report.js
const express = require('express');
const router = express.Router();
const { getReport } = require('../controllers/reportController');

router.get('/:userId', getReport);

module.exports = router;
// swagger
/**
 * @swagger
 * /report/{userId}:
 *   get:
 *     summary: 사용자 리포트 조회
 *     description: 특정 사용자의 리포트를 조회합니다.
 *     tags:
 *       - Report
 *     parameters:
 *       - in: path
 *         name: userId
 *         required: true
 *         schema:
 *           type: string
 *         description: 사용자 ID
 *     responses:
 *       200:
 *         description: 리포트 조회 성공
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 userId:
 *                   type: string
 *                 totalDeletedCount:
 *                   type: integer
 *                 totalMB:
 *                   type: number
 *                 totalCarbon:
 *                   type: number
 *                 totalTrees:
 *                   type: number
 *       400:
 *         description: 잘못된 요청 (userId 누락 등)
 */