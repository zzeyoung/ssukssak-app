// uploadGalleryMetadata.js
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient } = require('@aws-sdk/lib-dynamodb');
const { BatchWriteCommand } = require('@aws-sdk/lib-dynamodb');

const client = new DynamoDBClient({ region: 'ap-northeast-2' });
const ddb = DynamoDBDocumentClient.from(client);

exports.uploadGalleryMetadata = async (req, res) => {
  const { userId, photos } = req.body;
  if (!userId || !Array.isArray(photos)) {
    return res.status(400).json({ message: 'userId 또는 photos 필드가 누락되었습니다.' });
  }

  const items = photos.map((photo) => ({
    PutRequest: {
      Item: {
        userId,                               // PK
        photoId: photo.photoId,               // SK
        dateTaken: photo.dateTaken || null,   // 📅 촬영 날짜
        screenshot: photo.screenshot ?? 0,     // 📱 스크린샷 여부 (1/0)
        latitude: photo.latitude ?? null,
        longitude: photo.longitude ?? null,
        size: photo.size ?? null,
        analysisTags: photo.analysisTags || {},
        screenshotTags: photo.screenshotTags || [],
        imageTags: photo.imageTags || [],
        groupId: photo.groupId || null,
        sourceApp: photo.sourceApp || null,
        uploadedAt: Date.now(),
      }
    }
  }));

  try {
    const BATCH_SIZE = 25;
    for (let i = 0; i < items.length; i += BATCH_SIZE) {
      await ddb.send(new BatchWriteCommand({
        RequestItems: { GalleryPhotos: items.slice(i, i + BATCH_SIZE) }
      }));
    }
    res.status(200).json({ message: '사진 메타데이터 저장 완료', savedCount: photos.length });
  } catch (err) {
    console.error('메타데이터 저장 오류:', err);
    res.status(500).json({ message: '서버 오류로 저장에 실패했습니다.' });
  }
};
