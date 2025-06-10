const { 
  saveActionToHighlight, 
  fetchHighlightHistory 
} = require('../services/highlightService');

const { 
  getPreferencesFromDynamoDB 
} = require('../services/preferencesService');

const { 
  fetchClassificationResult 
} = require('../services/classifyService');

const { 
  promptMap 
} = require('../services/promptMapService'); // matchesUserPrompt 제거

// 🔹 [POST] /highlight/action
exports.saveHighlightAction = async (req, res) => {
  const { userId, photoId, action } = req.body;
  const validActions = ['archived', 'deferred', 'deleted'];

  if (!userId || !photoId || !validActions.includes(action)) {
    return res.status(400).json({ message: '❌ 잘못된 요청입니다. userId, photoId, action을 확인하세요.' });
  }

  try {
    await saveActionToHighlight(userId, photoId, action);
    return res.status(200).json({ message: `✅ '${action}' 액션이 저장되었습니다.` });
  } catch (error) {
    console.error('🔥 하이라이트 액션 저장 실패:', error);
    return res.status(500).json({ message: '🚨 서버 에러가 발생했습니다.', error });
  }
};

// 🔹 [GET] /highlight/history
exports.getHighlightHistory = async (req, res) => {
  const { userId } = req.query;

  if (!userId) {
    return res.status(400).json({ message: '❌ userId 쿼리 파라미터가 필요합니다.' });
  }

  try {
    const history = await fetchHighlightHistory(userId);
    return res.status(200).json({ message: '✅ 하이라이트 이력 조회 성공', data: history });
  } catch (error) {
    console.error('🔥 하이라이트 이력 조회 실패:', error);
    return res.status(500).json({ message: '🚨 서버 에러가 발생했습니다.', error });
  }
};

// 🔹 [GET] /highlight/folders/:userId
exports.getHighlightFolders = async (req, res) => {
  const { userId } = req.params;

  if (!userId) {
    return res.status(400).json({ message: '❌ userId 파라미터가 필요합니다.' });
  }

  try {
    const preferences = await getPreferencesFromDynamoDB(userId); // ex) ["여행", "음식"]
    const allPhotos = await fetchClassificationResult(userId);

    const sixMonthsAgo = new Date();
    sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);

    const oldScreenshots = allPhotos.filter(photo => {
      const isScreenshot = photo.tags?.screenshot === 1;
      const timestamp = new Date(photo.timestamp);
      return isScreenshot && timestamp < sixMonthsAgo;
    });

    const folderList = [];

    if (oldScreenshots.length > 0) {
      folderList.push({
        folder: '6개월 지난 스크린샷',
        photos: oldScreenshots.map(p => p.photoId)
      });
    }

    const sortedFolders = [
      ...preferences,
      ...Object.keys(promptMap).filter(p => !preferences.includes(p))
    ];

    sortedFolders.forEach(prompt => {
      const photos = allPhotos.filter(photo =>
        (photo.contentTags || []).some(
          tag => tag.trim().toLowerCase() === prompt.trim().toLowerCase()
        )
      );

      if (photos.length > 0) {
        folderList.push({
          folder: prompt,
          photos: photos.map(p => p.photoId)
        });
      }
    });

    return res.status(200).json({
      message: '✅ 하이라이트 폴더 정렬 + 사진 분류 성공',
      data: folderList
    });

  } catch (error) {
    console.error('🔥 하이라이트 폴더 정렬 실패:', error);
    return res.status(500).json({ message: '🚨 서버 에러가 발생했습니다.', error });
  }
};

// 🔹 [GET] /highlight/folders/:userId/photos/:folderName
exports.getPhotosByFolder = async (req, res) => {
  const { userId, folderName } = req.params;

  if (!userId || !folderName) {
    return res.status(400).json({ message: '❌ userId와 folderName이 필요합니다.' });
  }

  try {
    const allPhotos = await fetchClassificationResult(userId);
    const history = await fetchHighlightHistory(userId);
    const actedPhotoIds = new Set(history.map(item => item.photoId));

    let filteredPhotos = [];

    if (folderName === '6개월 지난 스크린샷') {
      const sixMonthsAgo = new Date();
      sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);

      filteredPhotos = allPhotos.filter(photo => {
        const isScreenshot = photo.tags?.screenshot === 1;
        const timestamp = new Date(photo.timestamp);
        return isScreenshot && timestamp < sixMonthsAgo && !actedPhotoIds.has(photo.photoId);
      });

    } else {
      filteredPhotos = allPhotos.filter(photo =>
        (photo.contentTags || []).some(
          tag => tag.trim().toLowerCase() === folderName.trim().toLowerCase()
        ) && !actedPhotoIds.has(photo.photoId)
      );
    }

    return res.status(200).json({
      message: `✅ '${folderName}' 폴더의 사진 조회 성공`,
      data: filteredPhotos
    });

  } catch (error) {
    console.error('🔥 폴더별 사진 조회 실패:', error);
    return res.status(500).json({ message: '🚨 서버 에러가 발생했습니다.', error });
  }
};
