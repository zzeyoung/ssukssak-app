// controllers/trashController.js
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { GetCommand } = require('@aws-sdk/lib-dynamodb');
const { DynamoDBDocumentClient, PutCommand, QueryCommand } = require('@aws-sdk/lib-dynamodb');
const { BatchWriteCommand } = require('@aws-sdk/lib-dynamodb');

// AWS DynamoDB 클라이언트 설정
// AWS_REGION 환경 변수를 사용하거나 기본값으로 'ap-northeast-2' (서울 리전) 사용

const client = new DynamoDBClient({ region: process.env.AWS_REGION || 'ap-northeast-2' });
const ddb = DynamoDBDocumentClient.from(client);

exports.addToTrash = async (req, res) => {
  const { userId, photoId, source, tags = [], score = 0 } = req.body;

  if (!userId || !photoId ) {
    return res.status(400).json({ message: '❌ userId, photoId는 필수입니다.' });
  }

  const item = {
    userId,
    photoId,
    deletedAt: Date.now(),
    source,
    tags,
    score,
  };

  try {
    await ddb.send(new PutCommand({
      TableName: 'Trash',
      Item: item,
    }));

    res.status(200).json({ message: '🗑️ 휴지통에 저장 완료', item });
  } catch (err) {
    console.error('🛑 DynamoDB 저장 오류:', err);
    res.status(500).json({ message: '서버 오류', error: err.message });
  }
};

exports.getTrash = async (req, res) => {
    const { userId } = req.params;
  
    if (!userId) {
      return res.status(400).json({ message: '❌ userId는 필수입니다.' });
    }
  
    try {
      const command = new QueryCommand({
        TableName: 'Trash',
        KeyConditionExpression: 'userId = :uid',
        ExpressionAttributeValues: {
          ':uid': userId,
        },
        ScanIndexForward: false,
      });
  
      const result = await ddb.send(command);
  
      // ✅ result.Items가 배열이니까 길이로 체크해야 함
      if (!result.Items || result.Items.length === 0) {
        return res.status(200).json({ message: '휴지통이 비어 있습니다.', items: [] });
      }
  
      res.status(200).json({ items: result.Items });
    } catch (err) {
      console.error('📛 휴지통 조회 실패:', err);
      res.status(500).json({ message: '서버 오류', error: err.message });
    }
  };
// Swagger 문서화
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

exports.restorePhotos = async (req, res) => {
    const { userId, photoIds } = req.body;
  
    if (!userId || !Array.isArray(photoIds) || photoIds.length === 0) {
      return res.status(400).json({ message: '❌ userId와 photoIds 배열이 필요합니다.' });
    }
  
    try {
      const chunkSize = 25;
      for (let i = 0; i < photoIds.length; i += chunkSize) {
        const chunk = photoIds.slice(i, i + chunkSize);
        const deleteRequests = chunk.map(photoId => ({
          DeleteRequest: {
            Key: { userId, photoId }
          }
        }));
  
        const command = new BatchWriteCommand({
          RequestItems: {
            Trash: deleteRequests
          }
        });
  
        const result = await ddb.send(command);
  
        // ✅ 재시도 필요한 항목이 있으면 로그에 출력
        if (result.UnprocessedItems && Object.keys(result.UnprocessedItems).length > 0) {
          console.warn('⚠️ 처리되지 않은 항목 존재:', result.UnprocessedItems);
        }
      }
  
      res.status(200).json({ message: '✅ 전체 복구 완료', restored: photoIds });
  
    } catch (err) {
      console.error('🛑 복구 실패:', err);
      res.status(500).json({ message: '서버 오류', error: err.message });
    }
  };
  
// Swagger 문서화
/**
 * @swagger
 * /trash/restore:
 *   post:
 *     summary: 휴지통에서 사진 복구
 *     description: 사용자가 선택한 사진들을 휴지통에서 복구합니다.
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
 *               - photoIds
 *             properties:
 *               userId:
 *                 type: string
 *               photoIds:
 *                 type: array
 *                 items:
 *                   type: string
 *     responses:
 *       200:
 *         description: 복구 성공
 *       400:
 *         description: 요청 오류 (필수 파라미터 누락 등)
 */

// controllers/trashController.js

exports.deletePhotos = async (req, res) => {
  const { userId, photos } = req.body;

  if (!userId || !Array.isArray(photos) || photos.length === 0) {
    return res.status(400).json({ message: '❌ userId와 photos 배열이 필요합니다.' });
  }

  try {
    const idsToDelete = photos.map(p => p.photoId);
    const sizeMap = Object.fromEntries(photos.map(p => [p.photoId, p.size]));

    // 삭제 chunk 처리
    const chunkSize = 25;
    for (let i = 0; i < idsToDelete.length; i += chunkSize) {
      const chunk = idsToDelete.slice(i, i + chunkSize);
      const deleteRequests = chunk.map(photoId => ({
        DeleteRequest: {
          Key: { userId, photoId }
        }
      }));

      await ddb.send(new BatchWriteCommand({
        RequestItems: { Trash: deleteRequests }
      }));
    }

    const totalBytes = photos.reduce((acc, p) => acc + (p.size || 0), 0);
    const savedMB = +(totalBytes / (1024 * 1024)).toFixed(2);
    const carbonPerMB = 2.12 / 1024; // 0.00207 kg CO2 per MB
    const savedCarbon = +(savedMB * carbonPerMB).toFixed(2); // kg CO2
    
    // 나무 환산: 1g CO2 = 0.00036그루
    const savedCarbonGrams = savedCarbon * 1000;
    const treePerGram = 0.36 / 1000;
    const savedTrees = +(savedCarbonGrams * treePerGram).toFixed(4);
    
    // 누적 리포트 업데이트
    await ddb.send(new UpdateCommand({
        TableName: 'Report',
        Key: { userId },
        UpdateExpression: `
          ADD totalMB :mb, totalCarbon :carbon, totalTrees :trees, totalDeletedCount :n
        `,
        ExpressionAttributeValues: {
          ':mb': savedMB,
          ':carbon': savedCarbon,
          ':trees': savedTrees,
          ':n': idsToDelete.length
        }
      }));
      

    res.status(200).json({
      message: '🗑️ 완전 삭제 완료',
      deletedCount: idsToDelete.length,
      deleted: idsToDelete,
      saved: {
        mb: savedMB,
        carbon: savedCarbon,
        trees: savedTrees,
        n: idsToDelete.length
      }
    });

  } catch (err) {
    console.error('🛑 완전 삭제 실패:', err);
    res.status(500).json({ message: '서버 오류', error: err.message });
  }
};
// controllers/trashController.js
const { UpdateCommand } = require('@aws-sdk/lib-dynamodb');
  
// Swagger 문서화
/**
 * @swagger
 * /trash/delete:
 *   post:
 *     summary: 휴지통에서 사진 완전 삭제
 *     description: 사용자가 선택한 사진들을 휴지통에서 완전히 삭제합니다.
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
 *               - photoIds
 *             properties:
 *               userId:
 *                 type: string
 *               photoIds:
 *                 type: array
 *                 items:
 *                   type: string
 *     responses:
 *       200:
 *         description: 완전 삭제 성공
 *       400:
 *         description: 요청 오류 (필수 파라미터 누락 등)
 */  
