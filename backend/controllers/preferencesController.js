const {
  savePreferencesToDynamoDB,
  getPreferencesFromDynamoDB // ✅ GET용 서비스 함수 import 추가
} = require('../services/preferencesService');

// ✅ POST 요청 – 초기 프롬프트 저장
exports.saveUserPreferences = async (req, res) => {
  const { userId, promptTags } = req.body;

  if (!userId || !Array.isArray(promptTags)) {
    return res.status(400).json({ message: 'Invalid input' });
  }

  try {
    await savePreferencesToDynamoDB(userId, promptTags);
    res.status(200).json({ message: 'Preferences saved' });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error });
  }
};

// ✅ GET 요청 – 프롬프트 조회
exports.getUserPreferences = async (req, res) => {
  const { userId } = req.query;

  if (!userId) {
    return res.status(400).json({ message: '❌ userId 쿼리가 필요합니다.' });
  }

  try {
    const promptTags = await getPreferencesFromDynamoDB(userId);
    res.status(200).json({ userId, promptTags });
  } catch (error) {
    res.status(500).json({ message: '🚨 Server error', error });
  }
};
