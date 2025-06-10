// controllers/reportController.js
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, GetCommand } = require('@aws-sdk/lib-dynamodb');

// ⚠️ region은 네 프로젝트에 맞게 설정
const REGION = process.env.AWS_REGION || 'ap-northeast-2';
const client = new DynamoDBClient({ region: REGION });
const ddb = DynamoDBDocumentClient.from(client);


exports.getReport = async (req, res) => {
  const { userId } = req.params;

  if (!userId) {
    return res.status(400).json({ message: '❌ userId는 필수입니다.' });
  }

  try {
    const result = await ddb.send(new GetCommand({
      TableName: 'Report',
      Key: { userId }
    }));

    if (!result.Item) {
      return res.status(404).json({ message: '❌ 리포트가 존재하지 않습니다.' });
    }

    res.status(200).json({
      userId,
      totalDeletedCount: result.Item.totalDeletedCount || 0,
      totalMB: result.Item.totalMB || 0,
      totalCarbon: result.Item.totalCarbon || 0,
      totalTrees: result.Item.totalTrees || 0
    });
  } catch (err) {
    console.error('🛑 리포트 조회 실패:', err);
    res.status(500).json({ message: '서버 오류', error: err.message });
  }
};

