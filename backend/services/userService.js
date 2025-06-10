// /backend/services/userService.js

const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand, GetCommand } = require('@aws-sdk/lib-dynamodb');

const client = new DynamoDBClient({ region: 'us-east-1' });
const ddb = DynamoDBDocumentClient.from(client);

// ✅ 사용자 저장
const createUser = async (user) => {
    const region = await client.config.region();
console.log('📡 리전 확인 (실제 값):', region);

    console.log('💾 [createUser] 저장할 내용:', user); // 🔍 저장 직전 확인
  await ddb.send(new PutCommand({
    TableName: 'users',
    Item: {
        userID: user.userId,
        email: user.email,
        nickname: user.nickname,
        
      }
  }));
};

// ✅ 사용자 조회
const getUser = async (userId) => {
  const result = await ddb.send(new GetCommand({
    TableName: 'users',
    Key: { userID: userId }, // ← 여기도 대문자 D
  }));
  
  return result.Item;
};

// ✅ 정확하게 export 해줘야 함!
module.exports = {
  createUser,
  getUser,
};
