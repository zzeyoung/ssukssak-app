const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const {
  DynamoDBDocumentClient,
  BatchWriteCommand,
  QueryCommand,
} = require('@aws-sdk/lib-dynamodb');

/* 👉 테이블 이름 상수 */
const TABLE_NAME = process.env.DYNAMO_PHOTO_TABLE || 'GalleryPhotos';

const client = new DynamoDBClient({
  region: process.env.AWS_REGION || 'ap-northeast-2',
});
const ddb = DynamoDBDocumentClient.from(client);

/* ─────────────────────────────────────
 *  POST /photos/gallery   (메타데이터 저장)
 * ──────────────────────────────────── */
exports.uploadGalleryMetadata = async (req, res) => {
  const { userId, photos } = req.body;

  // ✅ 기본 유효성 검사
  if (!userId || !Array.isArray(photos)) {
    return res.status(400).json({ message: 'userId 또는 photos 필드가 누락되었습니다.' });
  }

  if (photos.length === 0) {
    return res.status(200).json({ message: '저장할 사진이 없습니다.' });
  }

  // ✅ PutRequest 배열로 변환
  const putItems = photos.map((photo) => ({
    PutRequest: {
      Item: {
        userId, // PK
        photoId: photo.photoId, // SK
        dateTaken: photo.dateTaken || null,
        blur: photo.blur ?? 0, // 흐릿 여부
        screenshot: photo.screenshot ?? 0, // 스크린샷 여부
        latitude: photo.latitude ?? null,
        longitude: photo.longitude ?? null,
        size: photo.size ?? null,
        analysisTags: photo.analysisTags || {},
        screenshotTags: photo.screenshotTags || [],
        imageTags: photo.imageTags || [],
        groupId: photo.groupId || null,
        sourceApp: photo.sourceApp || null,
        uploadedAt: Date.now(),
      },
    },
  }));

  const BATCH_SIZE = 25;
  let totalSaved = 0;

  try {
    for (let i = 0; i < putItems.length; i += BATCH_SIZE) {
      const batch = putItems.slice(i, i + BATCH_SIZE);
      let result = await ddb.send(
        new BatchWriteCommand({ RequestItems: { [TABLE_NAME]: batch } })
      );

      // 🔁 재시도: UnprocessedItems
      let unprocessed = result.UnprocessedItems?.[TABLE_NAME] || [];
      let retries = 0;

      while (unprocessed.length > 0 && retries < 3) {
        await new Promise((r) => setTimeout(r, 300 * (retries + 1))); // 점진적 지연
        const retry = await ddb.send(
          new BatchWriteCommand({ RequestItems: { [TABLE_NAME]: unprocessed } })
        );
        unprocessed = retry.UnprocessedItems?.[TABLE_NAME] || [];
        retries++;
      }

      totalSaved += batch.length;
    }

    return res.status(201).json({
      message: '✅ 사진 메타데이터 저장 완료',
      savedCount: totalSaved,
    });
  } catch (err) {
    console.error('🛑 메타데이터 저장 오류:', err);
    return res.status(500).json({ message: '서버 오류', error: err.message });
  }
};

/* ─────────────────────────────────────
 *  GET /photos/gallery?userId=123
 * ──────────────────────────────────── */
exports.getGalleryMetadata = async (req, res) => {
  const { userId } = req.query;
  if (!userId) {
    return res.status(400).json({ message: 'userId 쿼리 파라미터가 필요합니다.' });
  }

  try {
    let items = [];
    let lastKey;

    do {
      const data = await ddb.send(
        new QueryCommand({
          TableName: TABLE_NAME,
          KeyConditionExpression: 'userId = :uid',
          ExpressionAttributeValues: { ':uid': userId },
          ProjectionExpression: 'photoId', // blur→screenshot 등 실제 컬럼으로
          ExclusiveStartKey: lastKey,
        }),
      );
      items = items.concat(data.Items || []);
      lastKey = data.LastEvaluatedKey;
    } while (lastKey);

    return res.status(200).json({ items });
  } catch (err) {
    console.error('🛑 DynamoDB 조회 오류', err);
    return res.status(500).json({ message: '서버 오류', error: err.message });
  }
};
/* ─────────────────────────────────────
 *  GET /photos/gallery/tags?userId=123
 * ──────────────────────────────────── */


/* ──────────────────────────────────────────
 * GET /photos/candidates?userId=&blur=1&minScore=0.8
 *  → 앨범에 띄울 “정리 후보” 필터링
 * ────────────────────────────────────────── */
/**
 * GET /photos/candidates
 *  - 중복, 유사, 흐릿, 예쁨, 스크린샷, sourceApp 필터링
 *  - 중복/유사는 groupId 접두사로 그룹별 반환, 그 외 photoIds 배열 반환
 */
/**
 * GET /photos/candidates
 *  - duplicate=1 → groupId d* 그룹별 반환
 *  - similar=1   → groupId s* 그룹별 반환
 *  - blurry/minScore/screenshot/sourceApp → 일반 후보 (photoId+dateTaken 배열)
 */
exports.getCleanCandidates = async (req, res) => {
  const { userId, duplicate, similar, blurry, minScore, screenshot, sourceApp } = req.query;
  if (!userId) return res.status(400).json({ message: 'userId 쿼리 필요' });

  // Base query parameters
  const params = {
    TableName: TABLE_NAME,
    KeyConditionExpression: 'userId = :uid',
    ExpressionAttributeValues: { ':uid': userId },
    ProjectionExpression: 'photoId, dateTaken, groupId, analysisTags, screenshot, sourceApp',
  };
  let attributeNames = {};
  const filters = [];

  // duplicate / similar
  if (duplicate) {
    filters.push('begins_with(groupId, :d)');
    params.ExpressionAttributeValues[':d'] = 'd';
  }
  if (similar) {
    filters.push('begins_with(groupId, :s)');
    params.ExpressionAttributeValues[':s'] = 's';
  }
  // blurry
  if (blurry !== undefined) {
    attributeNames['#tags'] = 'analysisTags';
    attributeNames['#bl']   = 'blurry';
    params.ExpressionAttributeValues[':b'] = Number(blurry);
    filters.push('#tags.#bl = :b');
  }
  // ai_score
  if (minScore !== undefined) {
    attributeNames['#tags']  = 'analysisTags';
    attributeNames['#score'] = 'ai_score';
    params.ExpressionAttributeValues[':s'] = Number(minScore);
    filters.push('#tags.#score <= :s');
  }
  // screenshot
  if (screenshot !== undefined) {
    filters.push('screenshot = :ss');
    params.ExpressionAttributeValues[':ss'] = Number(screenshot);
  }
  // sourceApp
  if (sourceApp) {
    filters.push('sourceApp = :app');
    params.ExpressionAttributeValues[':app'] = sourceApp;
  }

  // only set ExpressionAttributeNames when needed
  if (Object.keys(attributeNames).length) {
    params.ExpressionAttributeNames = attributeNames;
  }
  if (filters.length) {
    params.FilterExpression = filters.join(' AND ');
  }

  try {
    let items = [], lastKey;
    do {
      const data = await ddb.send(new QueryCommand({ ...params, ExclusiveStartKey: lastKey }));
      items = items.concat(data.Items || []);
      lastKey = data.LastEvaluatedKey;
    } while (lastKey);

    const duplicateGroups = {};
    const similarGroups   = {};
    const photoItems      = [];

    items.forEach(it => {
      const entry = { photoId: it.photoId, dateTaken: it.dateTaken };
      if (duplicate && it.groupId?.startsWith('d')) {
        (duplicateGroups[it.groupId] = duplicateGroups[it.groupId] || []).push(entry);
      } else if (similar && it.groupId?.startsWith('s')) {
        (similarGroups[it.groupId] = similarGroups[it.groupId] || []).push(entry);
      } else if (!duplicate && !similar) {
        photoItems.push(entry);
      }
    });

    return res.status(200).json({
      duplicateGroups: Object.keys(duplicateGroups).length ? duplicateGroups : undefined,
      similarGroups:   Object.keys(similarGroups).length   ? similarGroups   : undefined,
      photos:          photoItems.length                   ? photoItems      : undefined,
    });
  } catch (err) {
    console.error('후보 조회 오류', err);
    return res.status(500).json({ message: '서버 오류', error: err.message });
  }
};



/* 호출 예시 --------------------------------------------------
# 중복 그룹
GET /photos/candidates?userId=<uid>&duplicate=1

# 유사 그룹
GET /photos/candidates?userId=<uid>&similar=1

# 흐릿 + 예쁨 + 스크린샷 + sourceApp 필터
GET /photos/candidates?userId=<uid>&blurry=1&minScore=0.7&screenshot=1&sourceApp=KakaoTalk
------------------------------------------------------------*/
