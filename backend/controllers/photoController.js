const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient } = require('@aws-sdk/lib-dynamodb');
const { BatchWriteCommand } = require('@aws-sdk/lib-dynamodb');

const client = new DynamoDBClient({
  region: 'ap-northeast-2' // ✅ 서울 리전 (예시)
});

const ddb = DynamoDBDocumentClient.from(client);

exports.uploadGalleryMetadata = async (req, res) => {
  const { userId, photos } = req.body;

  if (!userId || !Array.isArray(photos)) {
    return res.status(400).json({ message: '❌ userId 또는 photos 필드가 누락되었습니다.' });
  }

  const items = photos.map((photo) => ({
    PutRequest: {
      Item: {
        userId,
        photoId: photo.photoId,
        timestamp: photo.timestamp,
        latitude: photo.latitude,
        longitude: photo.longitude,
        size: photo.size,
        analysisTags: photo.analysisTags,
        screenshotTags: photo.screenshotTags,
        imageTags: photo.imageTags,
        groupId: photo.groupId || null,
        sourceApp: photo.sourceApp || null,
        uploadedAt: Date.now(),
      }
    }
  }));

  try {
    const batches = [];
    const BATCH_SIZE = 25;
    for (let i = 0; i < items.length; i += BATCH_SIZE) {
      const batch = items.slice(i, i + BATCH_SIZE);
      batches.push(
        ddb.send(new BatchWriteCommand({
          RequestItems: {
            GalleryPhotos: batch
          }
        }))
      );
    }

    await Promise.all(batches);

    res.status(200).json({ message: '사진 메타데이터 저장 완료', savedCount: photos.length });
  } catch (err) {
    console.error('🛑 메타데이터 저장 오류:', err);
    res.status(500).json({ message: '서버 오류로 저장에 실패했습니다.' });
  }
};
