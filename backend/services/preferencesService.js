const {
  DynamoDBClient,
  PutItemCommand,  // 🔹 항목 저장을 위한 커맨드
  GetItemCommand   // 🔹 단일 항목 조회를 위한 커맨드
} = require('@aws-sdk/client-dynamodb');

// 🔸 AWS DynamoDB 클라이언트 생성 (서울 리전)
const client = new DynamoDBClient({ region: 'ap-northeast-2' });


// ✅ 사용자 프롬프트 태그 저장 함수
// - 사용자가 선택한 관심 태그(promptTags)를 DynamoDB에 저장
// - 테이블: Userpreferences
// - 호출 예: POST /user/preferences
exports.savePreferencesToDynamoDB = async (userId, promptTags) => {
  const command = new PutItemCommand({
    TableName: 'Userpreferences',
    Item: {
      userId: { S: userId },                    // 파티션 키
      promptTags: { SS: promptTags },          // 관심 태그 리스트 (String Set 형식)
      updatedAt: { S: new Date().toISOString() } // 최근 저장 시간 기록
    }
  });

  // 🔸 DynamoDB에 요청 실행
  await client.send(command);
};


// ✅ 사용자 프롬프트 태그 조회 함수
// - 특정 사용자가 저장한 관심 태그를 조회
// - 테이블: Userpreferences
// - 호출 예: GET /user/preferences?userId=xxx
exports.getPreferencesFromDynamoDB = async (userId) => {
  const command = new GetItemCommand({
    TableName: 'Userpreferences',
    Key: { userId: { S: userId } }              // 조회 기준 키
  });

  const result = await client.send(command);   // DynamoDB로부터 결과 받기

  // 🔸 promptTags가 존재하면 반환, 없으면 빈 배열 반환
  return result.Item?.promptTags?.SS || [];
};
