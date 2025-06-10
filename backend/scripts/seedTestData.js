// scripts/seedTestData.js
require('dotenv').config();
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, BatchWriteCommand, PutCommand } = require('@aws-sdk/lib-dynamodb');

const REGION = process.env.AWS_REGION || 'ap-northeast-2';
const client = new DynamoDBClient({ region: REGION });
const ddb = DynamoDBDocumentClient.from(client);

const userId = 'testUser';

const trashPhotos = [
  { photoId: 'img_001', tags: ['blurry'], score: 10 },
  { photoId: 'img_002', tags: ['screenshot'], score: 5 },
  { photoId: 'img_003', tags: ['duplicate'], score: 2 },
  { photoId: 'img_004', tags: ['food'], score: 8 },
  { photoId: 'img_005', tags: ['dog', 'blurry'], score: 12 }
];

async function seedTrashData() {
  const items = trashPhotos.map(p => ({
    PutRequest: {
      Item: {
        userId,
        photoId: p.photoId,
        deletedAt: Date.now(),
        source: 'test',
        tags: p.tags,
        score: p.score
      }
    }
  }));

  const command = new BatchWriteCommand({
    RequestItems: {
      Trash: items
    }
  });

  await ddb.send(command);
  console.log('✅ Trash 더미 데이터 삽입 완료');
}

async function seedReportData() {
  const command = new PutCommand({
    TableName: 'Report',
    Item: {
      userId,
      totalMB: 0,
      totalCarbon: 0,
      totalTrees: 0,
      totalDeletedCount: 0
    }
  });

  await ddb.send(command);
  console.log('✅ Report 초기화 완료');
}

(async () => {
  try {
    await seedTrashData();
    await seedReportData();
    console.log('🎉 테스트 데이터 삽입 완료');
  } catch (err) {
    console.error('🛑 삽입 실패:', err);
  }
})();
