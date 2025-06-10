const {
  saveClassificationResult,
  fetchClassificationResult,
  getFolderFromTags
} = require('../services/classifyService');

// 🔹 [POST] 단일 사진 분류 (AI 태그 + 파일명 기반 폴더 결정만 함)
exports.classifyPhotoFolder = async (req, res) => {
  const { photoId, userId, tags, filename, duplicateGroupId, similarGroupId } = req.body;

  if (!photoId || !userId || !tags) {
    return res.status(400).json({ message: 'Missing required fields' });
  }

  const { folder, sourceApp } = getFolderFromTags({
    tags,
    filename,
    duplicateGroupId,
    similarGroupId
  });

  res.status(200).json({
    photoId,
    folder,
    tags,
    sourceApp
  });
};


// 🔹 [POST] 여러 사진 분류 결과 저장 (한 번에 여러 장 저장)
exports.classifyAndSaveAll = async (req, res) => {
  const { userId, classifiedPhotos } = req.body;

  if (!userId || !classifiedPhotos || typeof classifiedPhotos !== 'object') {
    return res.status(400).json({ message: '잘못된 요청입니다.' });
  }

  try {
    await saveClassificationResult(userId, classifiedPhotos);
    res.status(200).json({ message: '✅ 분류 결과가 저장되었습니다.' });
  } catch (error) {
    console.error('🔥 분류 저장 실패:', error);
    res.status(500).json({ message: '🚨 서버 오류', error });
  }
};

// 🔹 [GET] 분류 결과 전체 조회 (유저 기준)
exports.getClassificationResult = async (req, res) => {
  const { userId } = req.query;

  if (!userId) {
    return res.status(400).json({ message: '❌ userId 쿼리 파라미터가 필요합니다.' });
  }

  try {
    const result = await fetchClassificationResult(userId);
    res.status(200).json({ message: '✅ 분류 결과 조회 성공', data: result });
  } catch (error) {
    console.error('🔥 분류 결과 조회 실패:', error);
    res.status(500).json({ message: '🚨 서버 오류', error });
  }
};

// 🔹 [GET] 스크린샷 세부 분류 조회
exports.getScreenshotSubfolders = async (req, res) => {
  const { userId } = req.params;

  if (!userId) {
    return res.status(400).json({ message: '❌ userId 파라미터가 필요합니다.' });
  }

  try {
    const allPhotos = await fetchClassificationResult(userId);
    const screenshots = allPhotos.filter(photo => photo.folder.includes('스크린샷'));

    const categories = {
      '메신저 캡처': ['kakaotalk', 'line', 'whatsapp', 'messenger'],
      '상품 캡처': ['coupang', 'gmarket', '11st', '쇼핑', 'shop'],
      '기프티콘': ['giftishow', 'happycon', '기프티콘', '선물'],
      '지도 캡처': ['kakaomap', 'navermap', 'tmap', '지도', 'map'],
      '정보 검색': ['chrome', 'safari', 'naver', '뉴스', '검색', '정보'],
      'QR/바코드': ['barcode', 'qr', '코드', '입장권'],
      '인물 캡처': ['camera', 'face', '사람', '셀카', '인물']
    };

    const result = {
      '메신저 캡처': [],
      '상품 캡처': [],
      '기프티콘': [],
      '지도 캡처': [],
      '정보 검색': [],
      'QR/바코드': [],
      '인물 캡처': [],
      '기타': []
    };

    screenshots.forEach(photo => {
      const app = (photo.sourceApp || '').toLowerCase();
      const clipTags = (photo.contentTags || []).map(t => t.toLowerCase());

      let matched = false;

      for (const [folder, keywords] of Object.entries(categories)) {
        if (keywords.some(k => app.includes(k) || clipTags.includes(k))) {
          result[folder].push(photo);
          matched = true;
          break;
        }
      }

      if (!matched) {
        result['기타'].push(photo);
      }
    });

    res.status(200).json({
      message: '✅ 스크린샷 세부 분류 성공',
      data: result
    });

  } catch (error) {
    console.error('🔥 스크린샷 세부 분류 실패:', error);
    res.status(500).json({ message: '🚨 서버 오류', error });
  }
};

// 🔹 [GET] 폴더 요약 API (홈 화면용 카드 요약)
exports.getFolderSummary = async (req, res) => {
  const { userId } = req.params;

  if (!userId) {
    return res.status(400).json({ message: '❌ userId 파라미터가 필요합니다.' });
  }

  try {
    const allPhotos = await fetchClassificationResult(userId);

    const folderMap = {};
    allPhotos.forEach(photo => {
      const folders = photo.folder?.split(',') || ['기타'];
      folders.forEach(folder => {
        if (!folderMap[folder]) folderMap[folder] = [];
        folderMap[folder].push(photo);
      });
    });

    const folders = Object.entries(folderMap).map(([folderName, photos]) => ({
      folderName,
      count: photos.length,
      thumbnail: `https://your-storage-url/${photos[0].photoId}`
    }));

    const folderOrder = ['완전 중복', '유사한 사진', '흐릿한 사진', '삭제 추천', '스크린샷'];

    folders.sort((a, b) => {
      const idxA = folderOrder.indexOf(a.folderName);
      const idxB = folderOrder.indexOf(b.folderName);

      if (idxA === -1 && idxB === -1) return a.folderName.localeCompare(b.folderName);
      if (idxA === -1) return 1;
      if (idxB === -1) return -1;
      return idxA - idxB;
    });

    const totalPhotos = allPhotos.length;
    const deletedCandidates = allPhotos.filter(p => p.folder?.includes('삭제 추천'));
    const savedStorageMB = deletedCandidates.length * 2;
    const savedStorageGB = (savedStorageMB / 1024).toFixed(1) + 'GB';

    res.status(200).json({
      message: '✅ 폴더 요약 조회 성공',
      summary: {
        totalPhotos,
        savedStorage: savedStorageGB
      },
      folders
    });

  } catch (error) {
    console.error('🔥 폴더 요약 조회 실패:', error);
    res.status(500).json({ message: '🚨 서버 오류', error });
  }
};

exports.getPhotosByFolder = async (req, res) => {
  const { userId, folderName } = req.params;

  if (!userId || !folderName) {
    return res.status(400).json({ message: '❌ userId와 folderName 파라미터가 필요합니다.' });
  }

  try {
    const allPhotos = await fetchClassificationResult(userId);
    const matched = allPhotos.filter(photo => photo.folder?.split(',').includes(folderName));

    res.status(200).json({
      message: `✅ 폴더 "${folderName}" 사진 조회 성공`,
      data: matched
    });
  } catch (error) {
    console.error('🔥 폴더 사진 조회 실패:', error);
    res.status(500).json({ message: '🚨 서버 오류', error });
  }
};
