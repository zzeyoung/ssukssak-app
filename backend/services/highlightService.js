const { DynamoDBClient, PutItemCommand, QueryCommand } = require('@aws-sdk/client-dynamodb');

// 🔸 AWS 리전 설정 (서울 리전)
const client = new DynamoDBClient({ region: 'ap-northeast-2' });


// 🔹 사용자의 하이라이트 액션 저장 (스와이프 결과 기록)
// - 사용자가 어떤 사진에 대해 어떤 행동(보관, 보류, 삭제 등)을 했는지 기록
// - 테이블: HighlightActions
// - 호출 예: POST /highlight/action
exports.saveActionToHighlight = async (userId, photoId, action) => {
  const command = new PutItemCommand({
    TableName: 'HighlightActions',
    Item: {
      userId: { S: userId },                      // 파티션 키
      photoId: { S: photoId },                    // 정렬 키
      action: { S: action },                      // ex: '보관', '보류', '삭제'
      timestamp: { S: new Date().toISOString() }  // 행동 시간 기록
    }
  });

  await client.send(command); // DynamoDB에 저장 실행
};


// 🔹 사용자의 하이라이트 행동 이력 조회
// - 특정 userId에 대해 어떤 사진에 어떤 행동을 했는지 모두 조회
// - 테이블: HighlightActions
// - 호출 예: GET /highlight/history?userId=xxx
exports.fetchHighlightHistory = async (userId) => {
  const command = new QueryCommand({
    TableName: 'HighlightActions',
    KeyConditionExpression: 'userId = :uid',         // 파티션 키 조건
    ExpressionAttributeValues: {
      ':uid': { S: userId }
    }
  });

  const result = await client.send(command);         // 조회 결과 받아오기

  // 결과 포맷 변환
  return result.Items.map(item => ({
    userId: item.userId.S,
    photoId: item.photoId.S,
    action: item.action.S,
    timestamp: item.timestamp.S
  }));
};
